# wslhost.exe/wsl.exe relay threads busy-loop at ~100% of a core when their
# interop endpoint dies shortly after launch (observed on WSL 2.7.10 and
# 2.7.11: six or more spinners pinned ~4.5 cores for days). No healthy relay
# thread sustains >50% CPU duty over its lifetime, hence the duty + 10-minute
# CPU floor signature below.
$ErrorActionPreference = 'SilentlyContinue'

Add-Type -Namespace K32 -Name Thread -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr OpenThread(uint access, bool inherit, uint id);
[DllImport("kernel32.dll")] public static extern uint SuspendThread(IntPtr handle);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
'@

$log = Join-Path $env:TEMP 'wslhost-watchdog.log'
$status = Join-Path $env:TEMP 'wslhost-watchdog.status'
$now = Get-Date
$processCount = 0
$threadCount = 0
$suspendedCount = 0

foreach ($proc in (Get-Process -Name wslhost,wsl -ErrorAction SilentlyContinue)) {
    $processCount++
    foreach ($thread in $proc.Threads) {
        $threadCount++
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
        $suspendedCount++
        "{0:yyyy-MM-dd HH:mm:ss} suspended pid={1} tid={2} cpu={3:n0}s duty={4:p0}" -f $now, $proc.Id, $thread.Id, $cpu, ($cpu / $life) |
            Add-Content -Path $log
    }
}

# Keep a bounded heartbeat separate from the append-only action log, so a
# successful task with zero matches is distinguishable from a task that did
# not run without growing a log every five minutes.
"{0:yyyy-MM-dd HH:mm:ss} processes={1} threads={2} suspended={3}" -f $now, $processCount, $threadCount, $suspendedCount |
    Set-Content -Path $status
