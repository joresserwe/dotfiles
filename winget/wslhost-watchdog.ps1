# wslhost.exe relay threads busy-loop at ~100% of a core when their interop
# endpoint dies shortly after launch (WSL 2.7.10, observed 2026-07-22..24:
# six spinners pinned ~4.5 cores for days). No healthy wslhost thread
# sustains >50% CPU duty over its lifetime, hence the duty + 10-minute CPU
# floor signature below.
$ErrorActionPreference = 'SilentlyContinue'

Add-Type -Namespace K32 -Name Thread -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr OpenThread(uint access, bool inherit, uint id);
[DllImport("kernel32.dll")] public static extern uint SuspendThread(IntPtr handle);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
'@

$log = Join-Path $env:TEMP 'wslhost-watchdog.log'
$now = Get-Date

foreach ($proc in (Get-Process wslhost)) {
    foreach ($thread in $proc.Threads) {
        # WaitReason throws unless ThreadState is Wait.
        if ($thread.ThreadState -eq 'Wait' -and $thread.WaitReason -eq 'Suspended') { continue }
        $cpu = $thread.TotalProcessorTime.TotalSeconds
        if ($cpu -lt 600) { continue }
        $life = ($now - $thread.StartTime).TotalSeconds
        if ($life -le 0 -or ($cpu / $life) -lt 0.5) { continue }
        # 2 = THREAD_SUSPEND_RESUME
        $handle = [K32.Thread]::OpenThread(2, $false, [uint32]$thread.Id)
        if ($handle -eq [IntPtr]::Zero) { continue }
        [void][K32.Thread]::SuspendThread($handle)
        [void][K32.Thread]::CloseHandle($handle)
        "{0:yyyy-MM-dd HH:mm:ss} suspended pid={1} tid={2} cpu={3:n0}s duty={4:p0}" -f $now, $proc.Id, $thread.Id, $cpu, ($cpu / $life) |
            Add-Content -Path $log
    }
}
