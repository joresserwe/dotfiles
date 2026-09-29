using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class WslVhd
{
    [StructLayout(LayoutKind.Sequential)]
    struct VirtualStorageType
    {
        public uint DeviceId;
        public Guid VendorId;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct CompactParameters
    {
        public int Version;
        public uint Reserved;
    }

    const uint AccessGetInfo = 0x00080000;
    const uint AccessMetaops = 0x00200000;
    const int CompactNoZeroScan = 0x1;

    [DllImport("virtdisk.dll", CharSet = CharSet.Unicode)]
    static extern int OpenVirtualDisk(ref VirtualStorageType type, string path, uint accessMask, int flags, IntPtr parameters, out IntPtr handle);

    [DllImport("virtdisk.dll")]
    static extern int CompactVirtualDisk(IntPtr handle, int flags, ref CompactParameters parameters, IntPtr overlapped);

    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr handle);

    public static void Compact(string path)
    {
        var type = new VirtualStorageType();
        IntPtr handle;
        int rc = OpenVirtualDisk(ref type, path, AccessGetInfo | AccessMetaops, 0, IntPtr.Zero, out handle);
        if (rc != 0) throw new Win32Exception(rc);
        try
        {
            var parameters = new CompactParameters { Version = 1 };
            rc = CompactVirtualDisk(handle, CompactNoZeroScan, ref parameters, IntPtr.Zero);
            if (rc != 0) throw new Win32Exception(rc);
        }
        finally
        {
            CloseHandle(handle);
        }
    }
}
