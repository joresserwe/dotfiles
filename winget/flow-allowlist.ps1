$script:FlowSettingsAllowedFields = @(
    'AlwaysPreview', 'AlwaysStartEn', 'AnimationSpeed', 'AutoCompleteHotkey',
    'AutoCompleteHotkey2', 'AutoDialogJump', 'AutoRestartAfterChanging',
    'AutoUpdatePlugins', 'AutoUpdates', 'BackdropType', 'ColorScheme',
    'CustomAnimationLength',
    'CycleHistoryDownHotkey', 'CycleHistoryUpHotkey', 'DateFormat',
    'DialogJumpFileResultBehaviour', 'DialogJumpHotkey',
    'DialogJumpResultBehaviour', 'DialogJumpWindowPosition',
    'DontPromptUpdateMsg', 'DoublePinyinSchema', 'EnableDialogJump',
    'EnableUpdateLog', 'HideNotifyIcon', 'HideOnStartup', 'HideWhenDeactivated',
    'Hotkey', 'IgnoreHotkeysOnFullscreen', 'ItemHeightSize', 'KeepMaxResults',
    'Language', 'LastQueryMode', 'LeaveCmdOpen', 'LogLevel',
    'MaxHistoryResultsToShowForHomePage', 'MaxResultsToShow',
    'OpenContextMenuHotkey', 'OpenHistoryHotkey', 'OpenResultModifiers',
    'PlaceholderText', 'PreviewHotkey', 'QueryBoxFont', 'QueryBoxFontSize',
    'QueryBoxFontStretch', 'QueryBoxFontStyle', 'QueryBoxFontWeight',
    'QuerySearchPrecision', 'ResultFont', 'ResultFontStretch',
    'ResultFontStyle', 'ResultFontWeight', 'ResultItemFontSize',
    'ResultSubFont', 'ResultSubFontStretch', 'ResultSubFontStyle',
    'ResultSubFontWeight', 'ResultSubItemFontSize', 'SearchDelayTime',
    'SearchQueryResultsWithDelay', 'SearchWindowAlign', 'SearchWindowScreen',
    'SelectNextItemHotkey', 'SelectNextItemHotkey2', 'SelectNextPageHotkey',
    'SelectPrevItemHotkey', 'SelectPrevItemHotkey2', 'SelectPrevPageHotkey',
    'SettingWindowFont', 'SettingWindowHotkey', 'ShouldUsePinyin',
    'ShowAtTopmost', 'ShowBadges', 'ShowBadgesGlobalOnly',
    'ShowDialogJumpWindow', 'ShowHistoryResultsForHomePage', 'ShowHomePage',
    'ShowOpenResultHotkey', 'ShowPlaceholder', 'ShowTaskbarWhenInvoked',
    'ShowUnknownSourceWarning', 'SoundVolume', 'StartFlowLauncherOnSystemStartup',
    'Theme', 'TimeFormat', 'UseAnimation', 'UseClock', 'UseDate',
    'UseDoublePinyin', 'UseDropShadowEffect', 'UseGlyphIcons',
    'UseLogonTaskForStartup', 'UseSound', 'WindowHeightSize', 'WindowSize'
)

$script:FlowPluginAllowedFields = @{
    'Flow.Launcher.Plugin.AudioDeviceSelector' = @(
        'DisplayDeviceDescription', 'DisplayDeviceName', 'DisplayFriendlyName'
    )
    'Flow.Launcher.Plugin.BrowserBookmark' = @(
        'EnableFavicons', 'LoadChromeBookmark', 'LoadEdgeBookmark',
        'LoadFirefoxBookmark', 'OpenInNewBrowserWindow'
    )
    'Flow.Launcher.Plugin.Calculator' = @(
        'DecimalSeparator', 'MaxDecimalPlaces', 'ShowErrorMessage',
        'UseThousandsSeparator'
    )
    'Flow.Launcher.Plugin.Explorer' = @(
        'BoostHomeFolderScore', 'ContentSearchEngine',
        'DefaultOpenFolderInFileManager', 'DisplayMoreInformationInToolTip',
        'EnableEverythingContentSearch', 'EverythingEnableRunCount',
        'EverythingEnabled', 'EverythingSearchFullPath', 'ExcludedFileTypes',
        'FileContentSearchActionKeyword', 'FileContentSearchKeywordEnabled',
        'FileSearchActionKeyword', 'FileSearchKeywordEnabled',
        'FolderSearchActionKeyword', 'FolderSearchKeywordEnabled',
        'IndexSearchActionKeyword', 'IndexSearchEngine',
        'IndexSearchKeywordEnabled', 'MaxResult', 'PathEnumerationEngine',
        'PathSearchActionKeyword', 'PathSearchKeywordEnabled',
        'PreviewPanelDateFormat', 'PreviewPanelTimeFormat',
        'QuickAccessActionKeyword', 'QuickAccessKeywordEnabled',
        'SearchActionKeyword', 'SearchActionKeywordEnabled',
        'ShowCreatedDateInPreviewPanel', 'ShowFileAgeInPreviewPanel',
        'ShowFileSizeInPreviewPanel', 'ShowInlinedWindowsContextMenu',
        'ShowModifiedDateInPreviewPanel', 'SortOption',
        'UseLocationAsWorkingDir', 'WarnWindowsSearchServiceOff',
        'WindowsContextMenuExcludedItems', 'WindowsContextMenuIncludedItems'
    )
    'Flow.Launcher.Plugin.PluginsManager' = @(
        'AutoRestartAfterChanging', 'WarnFromUnknownSource'
    )
    'Flow.Launcher.Plugin.ProcessKiller' = @(
        'PutVisibleWindowProcessesTop', 'ShowWindowTitle'
    )
    'Flow.Launcher.Plugin.Program' = @(
        'BuiltinProtocolsStatus', 'BuiltinSuffixesStatus', 'CustomProtocols',
        'CustomSuffixes', 'EnableDescription', 'EnablePathSource',
        'EnableRegistrySource', 'EnableStartMenuSource', 'EnableUWP',
        'HideAppsPath', 'HideDuplicatedWindowsApp', 'HideUninstallers',
        'UseCustomProtocols', 'UseCustomSuffixes'
    )
    'Flow.Launcher.Plugin.Shell' = @(
        'CloseShellAfterPress', 'LeaveShellOpen', 'ReplaceWinR',
        'RunAsAdministrator', 'Shell', 'ShowOnlyMostUsedCMDs',
        'ShowOnlyMostUsedCMDsNumber', 'UseWindowsTerminal'
    )
    'Flow.Launcher.Plugin.Sys' = @('Commands', 'SkipPowerActionConfirmation')
    'Flow.Launcher.Plugin.Url' = @(
        'AlwaysOpenWithHttps', 'OpenInNewBrowserWindow', 'OpenInPrivateMode',
        'PrivateModeArgument'
    )
    'Flow.Launcher.Plugin.WebSearch' = @(
        'EnableSuggestion', 'MaxSuggestions', 'SearchSources', 'Suggestion'
    )
    'VolumeFlow' = @()
}

$script:FlowApprovedPluginIds = @{
    '0ECADE17459B49F587BF81DC3A125110' = $true
    'CEA0FDFC6D3B4085823D60DC76F28855' = $true
    '572be03c74c642baae319fc283e561a8' = $true
    '6A122269676E40EB86EB543B945932B9' = $true
    '9f8f9b14-2518-4907-b211-35ab6290dee7' = $true
    'b64d0a79-329a-48b0-b53f-d658318a1bf6' = $true
    '791FC278BA414111B8D1886DFE447410' = $true
    'D409510CD0D2481F853690A07E6DC426' = $true
    'CEA08895D2544B019B2E9C5009600DF4' = $true
    '0308FD86DE0A4DEE8D62B9B535370992' = $true
    '565B73353DBF4806919830B9202EE3BF' = $true
    '5043CETYU6A748679OPA02D27D99677A' = $true
    'F03364BE-101B-4988-B555-528B961E6A86' = $true
    '0F43C966617C4817B1BEC29DCC8E5A69' = $true
    '88EEE8BB-E5F5-43B1-8FA7-6F3BE228111A' = $true
}

$script:FlowPluginSettingsAllowedFields = @(
    'ActionKeywords', 'Priority', 'SearchDelayTime', 'Disabled', 'HomeDisabled'
)

$script:FlowApprovedWebSearchSources = [ordered]@{
    'Google' = [ordered]@{
        ActionKeyword = '*'; Icon = 'google.png'; Url = 'https://www.google.com/search?q={q}'
    }
    'Google Maps' = [ordered]@{
        ActionKeyword = 'maps'; Icon = 'google_maps.png'; Url = 'https://maps.google.com/maps?q={q}'
    }
    'Google Translate' = [ordered]@{
        ActionKeyword = 'translate'; Icon = 'google_translate.png'; Url = 'https://translate.google.com/#auto|en|{q}'
    }
    'GitHub' = [ordered]@{
        ActionKeyword = 'github'; Icon = 'github.png'; Url = 'https://github.com/search?q={q}'
    }
    'Gmail' = [ordered]@{
        ActionKeyword = 'gmail'; Icon = 'gmail.png'; Url = 'https://mail.google.com/mail/ca/u/0/#apps/{q}'
    }
    'Google Drive' = [ordered]@{
        ActionKeyword = 'drive'; Icon = 'google_drive.png'; Url = 'https://drive.google.com/?hl=en&tab=bo#search/{q}'
    }
    'Google Images' = [ordered]@{
        ActionKeyword = 'image'; Icon = 'google.png'; Url = 'https://www.google.com/search?q={q}&tbm=isch'
    }
    'YouTube' = [ordered]@{
        ActionKeyword = 'youtube'; Icon = 'youtube.png'; Url = 'https://www.youtube.com/results?search_query={q}'
    }
}
$script:FlowWebSearchSourceFields = @(
    'Title', 'ActionKeyword', 'Icon', 'CustomIcon', 'Url', 'IsPrivateMode', 'Enabled'
)

function Copy-FlowAllowedProperties {
    param(
        [AllowNull()][object]$Source,
        [string[]]$AllowedFields
    )

    $result = [ordered]@{}
    if ($null -ne $Source) {
        foreach ($field in $AllowedFields) {
            $property = $Source.PSObject.Properties[$field]
            if ($null -ne $property) { $result[$field] = $property.Value }
        }
    }
    [pscustomobject]$result
}

function Get-FlowSettingsSnapshotObject {
    param([AllowNull()][object]$Source)

    $result = [ordered]@{}
    foreach ($field in $script:FlowSettingsAllowedFields) {
        $property = if ($null -ne $Source) { $Source.PSObject.Properties[$field] } else { $null }
        if ($null -ne $property) { $result[$field] = $property.Value }
    }

    $sourcePlugins = if ($null -ne $Source -and $null -ne $Source.PluginSettings) {
        $Source.PluginSettings.PSObject.Properties['Plugins']
    } else { $null }
    if ($null -ne $sourcePlugins -and $null -ne $sourcePlugins.Value) {
        $plugins = [ordered]@{}
        foreach ($plugin in $sourcePlugins.Value.PSObject.Properties) {
            if (-not $script:FlowApprovedPluginIds.ContainsKey($plugin.Name)) { continue }
            $safe = Copy-FlowAllowedProperties $plugin.Value $script:FlowPluginSettingsAllowedFields
            if ($safe.PSObject.Properties.Count -gt 0) { $plugins[$plugin.Name] = $safe }
        }
        $result['PluginSettings'] = [pscustomobject]@{
            Plugins = [pscustomobject]$plugins
        }
    }
    [pscustomobject]$result
}

function Get-FlowPluginSnapshotObject {
    param(
        [AllowNull()][object]$Source,
        [Parameter(Mandatory)][string]$PluginName
    )

    if (-not $script:FlowPluginAllowedFields.ContainsKey($PluginName)) { return $null }
    $result = Copy-FlowAllowedProperties $Source $script:FlowPluginAllowedFields[$PluginName]
    if ($PluginName -eq 'Flow.Launcher.Plugin.WebSearch' -and
        $null -ne $result.PSObject.Properties['SearchSources']) {
        $sources = @()
        foreach ($source in @($result.SearchSources)) {
            $title = $source.PSObject.Properties['Title']
            $url = $source.PSObject.Properties['Url']
            if ($null -eq $title -or $null -eq $url -or
                -not $script:FlowApprovedWebSearchSources.Contains($title.Value)) { continue }
            $approved = $script:FlowApprovedWebSearchSources[$title.Value]
            if ($url.Value -ne $approved.Url) { continue }
            $sources += [pscustomobject][ordered]@{
                Title = $title.Value
                ActionKeyword = $approved.ActionKeyword
                Icon = $approved.Icon
                CustomIcon = $false
                Url = $approved.Url
                IsPrivateMode = [bool]$source.IsPrivateMode
                Enabled = [bool]$source.Enabled
            }
        }
        $result | Add-Member -NotePropertyName SearchSources -NotePropertyValue $sources -Force
    }
    if ($PluginName -eq 'Flow.Launcher.Plugin.Sys' -and
        $null -ne $result.PSObject.Properties['Commands']) {
        $commands = @()
        foreach ($command in @($result.Commands)) {
            $key = $command.PSObject.Properties['Key']
            $keyword = $command.PSObject.Properties['Keyword']
            if ($null -ne $key -and $null -ne $keyword -and
                $key.Value -is [string] -and $keyword.Value -is [string]) {
                $commands += [pscustomobject][ordered]@{
                    Key = $key.Value
                    Keyword = $keyword.Value
                }
            }
        }
        $result | Add-Member -NotePropertyName Commands -NotePropertyValue $commands -Force
    }
    $result
}

function Set-FlowAllowedProperties {
    param(
        [Parameter(Mandatory)][object]$Target,
        [AllowNull()][object]$Source,
        [string[]]$AllowedFields
    )

    if ($null -eq $Source) { return }
    foreach ($field in $AllowedFields) {
        $property = $Source.PSObject.Properties[$field]
        if ($null -ne $property) {
            $Target | Add-Member -NotePropertyName $field -NotePropertyValue $property.Value -Force
        }
    }
}

function Set-FlowPluginSnapshotProperties {
    param(
        [Parameter(Mandatory)][object]$Target,
        [AllowNull()][object]$Source,
        [Parameter(Mandatory)][string]$PluginName
    )

    $safe = Get-FlowPluginSnapshotObject $Source $PluginName
    if ($null -eq $safe) { return }
    $fields = $script:FlowPluginAllowedFields[$PluginName] | Where-Object { $_ -ne 'SearchSources' }
    Set-FlowAllowedProperties $Target $safe $fields

    if ($PluginName -ne 'Flow.Launcher.Plugin.WebSearch' -or
        $null -eq $safe.PSObject.Properties['SearchSources']) { return }
    $liveProperty = $Target.PSObject.Properties['SearchSources']
    [object[]]$sources = @(
        if ($null -ne $liveProperty -and $null -ne $liveProperty.Value) {
            @($liveProperty.Value)
        }
    )
    foreach ($source in @($safe.SearchSources)) {
        $match = $null
        foreach ($liveSource in $sources) {
            if ($liveSource.Title -eq $source.Title -and $liveSource.Url -eq $source.Url) {
                $match = $liveSource
                break
            }
        }
        if ($null -eq $match) {
            $sources += $source
        } else {
            Set-FlowAllowedProperties $match $source $script:FlowWebSearchSourceFields
        }
    }
    $Target | Add-Member -NotePropertyName SearchSources -NotePropertyValue $sources -Force
}

function Set-FlowSettingsFromSnapshot {
    param(
        [Parameter(Mandatory)][object]$Live,
        [AllowNull()][object]$Snapshot
    )

    $safe = Get-FlowSettingsSnapshotObject $Snapshot
    Set-FlowAllowedProperties $Live $safe $script:FlowSettingsAllowedFields

    $snapshotPlugins = if ($null -ne $safe.PluginSettings) {
        $safe.PluginSettings.PSObject.Properties['Plugins']
    } else { $null }
    $livePlugins = if ($null -ne $Live.PluginSettings) {
        $Live.PluginSettings.PSObject.Properties['Plugins']
    } else { $null }
    if ($null -eq $snapshotPlugins -or $null -eq $livePlugins -or $null -eq $livePlugins.Value) { return $Live }

    foreach ($plugin in $snapshotPlugins.Value.PSObject.Properties) {
        if (-not $script:FlowApprovedPluginIds.ContainsKey($plugin.Name)) { continue }
        $livePlugin = $livePlugins.Value.PSObject.Properties[$plugin.Name]
        if ($null -ne $livePlugin) {
            Set-FlowAllowedProperties $livePlugin.Value $plugin.Value $script:FlowPluginSettingsAllowedFields
        }
    }
    $Live
}
