# Cloud/RDP-style copies carry no CF_HDROP, only FileGroupDescriptorW +
# FileContents streams, so those are materialized into %TEMP% and reported
# as "VIRT<TAB><tempdir>" followed by the extracted paths.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms

$drop = [System.Windows.Forms.Clipboard]::GetFileDropList()
if ($drop -and $drop.Count -gt 0) {
    $drop | ForEach-Object { $_ }
    exit 0
}

$do = [System.Windows.Forms.Clipboard]::GetDataObject()
if (-not $do -or -not $do.GetDataPresent('FileGroupDescriptorW')) {
    exit 0
}

Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Collections.Generic;

public static class VirtualClip {
    [DllImport("ole32.dll")]
    private static extern int OleGetClipboard(out System.Runtime.InteropServices.ComTypes.IDataObject obj);
    [DllImport("ole32.dll")]
    private static extern void ReleaseStgMedium(ref STGMEDIUM medium);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern ushort RegisterClipboardFormatW(string name);
    [DllImport("kernel32.dll")]
    private static extern IntPtr GlobalLock(IntPtr handle);
    [DllImport("kernel32.dll")]
    private static extern bool GlobalUnlock(IntPtr handle);
    [DllImport("kernel32.dll")]
    private static extern UIntPtr GlobalSize(IntPtr handle);

    // FILEDESCRIPTORW: cFileName (WCHAR[260]) at offset 72, dwFileAttributes at 36,
    // struct size 592 (shell CFSTR_FILEDESCRIPTORW layout)
    private const int FdSize = 592;
    private const int FdNameOffset = 72;
    private const int FdAttrOffset = 36;
    private const int AttrDirectory = 0x10;

    public static string[] Extract(string destDir) {
        System.Runtime.InteropServices.ComTypes.IDataObject obj;
        if (OleGetClipboard(out obj) != 0) return new string[0];

        var fmtDesc = new FORMATETC {
            cfFormat = unchecked((short)RegisterClipboardFormatW("FileGroupDescriptorW")),
            dwAspect = DVASPECT.DVASPECT_CONTENT, lindex = -1, tymed = TYMED.TYMED_HGLOBAL,
        };
        STGMEDIUM medDesc;
        obj.GetData(ref fmtDesc, out medDesc);

        int count;
        var names = new List<string>();
        var isDir = new List<bool>();
        IntPtr p = GlobalLock(medDesc.unionmember);
        try {
            count = Marshal.ReadInt32(p);
            for (int i = 0; i < count; i++) {
                long fd = p.ToInt64() + 4 + (long)i * FdSize;
                names.Add(Marshal.PtrToStringUni(new IntPtr(fd + FdNameOffset)));
                isDir.Add((Marshal.ReadInt32(new IntPtr(fd + FdAttrOffset)) & AttrDirectory) != 0);
            }
        } finally {
            GlobalUnlock(medDesc.unionmember);
            ReleaseStgMedium(ref medDesc);
        }

        short cfContents = unchecked((short)RegisterClipboardFormatW("FileContents"));
        var created = new List<string>();
        Directory.CreateDirectory(destDir);
        for (int i = 0; i < count; i++) {
            string dest = Path.Combine(destDir, names[i]);
            if (isDir[i]) {
                Directory.CreateDirectory(dest);
                continue;
            }
            Directory.CreateDirectory(Path.GetDirectoryName(dest));
            var fmt = new FORMATETC {
                cfFormat = cfContents, dwAspect = DVASPECT.DVASPECT_CONTENT,
                lindex = i, tymed = TYMED.TYMED_ISTREAM | TYMED.TYMED_HGLOBAL,
            };
            STGMEDIUM med;
            try { obj.GetData(ref fmt, out med); } catch { continue; }
            try {
                if (med.tymed == TYMED.TYMED_ISTREAM) {
                    var stream = (IStream)Marshal.GetObjectForIUnknown(med.unionmember);
                    WriteStream(stream, dest);
                    Marshal.ReleaseComObject(stream);
                } else if (med.tymed == TYMED.TYMED_HGLOBAL) {
                    WriteHGlobal(med.unionmember, dest);
                } else {
                    continue;
                }
                created.Add(dest);
            } finally {
                ReleaseStgMedium(ref med);
            }
        }
        return created.ToArray();
    }

    private static void WriteStream(IStream stream, string dest) {
        var buf = new byte[81920];
        IntPtr pRead = Marshal.AllocHGlobal(8);
        try {
            using (var f = File.Create(dest)) {
                while (true) {
                    stream.Read(buf, buf.Length, pRead);
                    int read = Marshal.ReadInt32(pRead);
                    if (read <= 0) break;
                    f.Write(buf, 0, read);
                }
            }
        } finally {
            Marshal.FreeHGlobal(pRead);
        }
    }

    private static void WriteHGlobal(IntPtr handle, string dest) {
        IntPtr src = GlobalLock(handle);
        try {
            var data = new byte[(long)GlobalSize(handle)];
            Marshal.Copy(src, data, 0, data.Length);
            File.WriteAllBytes(dest, data);
        } finally {
            GlobalUnlock(handle);
        }
    }
}
'@

$dest = Join-Path $env:TEMP ("win-paste-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
$created = [VirtualClip]::Extract($dest)
if (-not $created -or $created.Length -eq 0) {
    exit 0
}
"VIRT`t$dest"
$created | ForEach-Object { $_ }
