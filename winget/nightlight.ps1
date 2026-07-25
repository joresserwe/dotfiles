param([ValidateSet('Toggle', 'On', 'Off')][string]$Action = 'Toggle')

$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default$windows.data.bluelightreduction.bluelightreductionstate\windows.data.bluelightreduction.bluelightreductionstate'
if (-not (Test-Path -LiteralPath $key)) { exit 1 }

$data = (Get-ItemProperty -LiteralPath $key -Name Data -ErrorAction SilentlyContinue).Data
if ($null -eq $data -or $data.Length -lt 41) { exit 1 }

# Byte 18 is the on/off flag. The enabled blob carries two extra bytes at 23-24,
# so the tail that follows byte 21 starts at 25 when on and at 23 when off.
$enabled = $data[18] -eq 0x15
if ($enabled -and $data.Length -lt 43) { exit 1 }

switch ($Action) {
    'On'    { $target = $true }
    'Off'   { $target = $false }
    default { $target = -not $enabled }
}
if ($target -eq $enabled) { exit 0 }

if ($target) {
    $new = New-Object byte[] 43
    [Array]::Copy($data, 0, $new, 0, 22)
    [Array]::Copy($data, 23, $new, 25, 18)
    $new[18] = 0x15
    $new[23] = 0x10
} else {
    $new = New-Object byte[] 41
    [Array]::Copy($data, 0, $new, 0, 22)
    [Array]::Copy($data, 25, $new, 23, 18)
    $new[18] = 0x13
}

# The blob is ignored unless its timestamp region (bytes 10-14) also advances.
for ($i = 10; $i -lt 15; $i++) {
    if ($new[$i] -ne 0xFF) { $new[$i] = [byte]($new[$i] + 1); break }
}

Set-ItemProperty -LiteralPath $key -Name Data -Value $new
