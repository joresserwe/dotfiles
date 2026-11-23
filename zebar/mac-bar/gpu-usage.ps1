$ErrorActionPreference = 'Stop'
$category = [Diagnostics.PerformanceCounterCategory]::new('GPU Engine')
$previous = $category.ReadCategory()['Utilization Percentage']
$stdin = [Console]::OpenStandardInput()
$request = [byte[]]::new(1)

while ($previous.Count -gt 0) {
    # A crashed widget can leave Zebar holding the write end of its stdin pipe.
    $read = $stdin.ReadAsync($request, 0, 1)
    if (!$read.Wait(10000) -or $read.Result -eq 0) { break }
    Start-Sleep -Seconds 1
    $current = $category.ReadCategory()['Utilization Percentage']
    $engines = @{}
    foreach ($instance in $current.Values) {
        $name = $instance.InstanceName
        if ($name -notmatch '^pid_\d+_(luid_.+?_phys_\d+_eng_\d+)_' -or !$previous.Contains($name)) {
            continue
        }
        $usage = [Diagnostics.CounterSample]::Calculate($previous[$name].Sample, $instance.Sample)
        $engines[$Matches[1]] += $usage
    }
    if (!$engines.Count) { break }

    $busiest = ($engines.Values | Measure-Object -Maximum).Maximum
    [Console]::WriteLine([int][Math]::Min(100, $busiest))
    $previous = $current
}
