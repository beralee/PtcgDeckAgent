[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExportManifestPath,
    [string]$EvidenceDirectory = "",
    [string]$PythonExe = "python",
    [int]$MatchTimeoutSeconds = 600,
    [switch]$DevelopmentAuditOnly
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptRoot "..\..")).Path
$allowedExportRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".tmp\ptcgdap_device_release"))
$uiWrapper = Join-Path $scriptRoot "run_ptcgdap_windows_ui_match.ps1"
$rollbackWrapper = Join-Path $scriptRoot "run_ptcgdap_author_strategy_rollback_drill.ps1"
$reportBuilder = Join-Path $projectRoot "tools\ptcgdap\build_author_strategy_device_report.py"
$profilePath = Join-Path $projectRoot "data\ptcgdap\author_strategy_device_acceptance_profile.json"
$wfpAuditGuid = "{0CCE9226-69AE-11D9-BED3-505054503030}"
$processAuditGuid = "{0CCE922B-69AE-11D9-BED3-505054503030}"

function Test-PathWithin {
    param([string]$Path, [string]$Root)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $prefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar
    return $fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-Administrator {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Windows OS-isolation acceptance requires an elevated Administrator PowerShell session."
    }
}

function Write-NewJson {
    param([string]$Path, [object]$Value)
    if (Test-Path -LiteralPath $Path) { throw "Refusing to overwrite existing evidence: $Path" }
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes(($Value | ConvertTo-Json -Depth 32))
    $stream = [System.IO.FileStream]::new(
        $Path,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

function Get-SecurityEvents {
    param([int[]]$Ids, [datetime]$StartTime, [datetime]$EndTime)
    try {
        return @(Get-WinEvent -FilterHashtable @{
            LogName = "Security"
            Id = $Ids
            StartTime = $StartTime
            EndTime = $EndTime
        } -ErrorAction Stop)
    } catch [System.Exception] {
        if ($_.Exception.Message -match "No events were found") { return @() }
        throw
    }
}

function Convert-EventData {
    param([object]$Event)
    $result = @{}
    $xml = [xml]$Event.ToXml()
    foreach ($data in @($xml.Event.EventData.Data)) {
        if ($null -ne $data.Name) { $result[[string]$data.Name] = [string]$data.'#text' }
    }
    return $result
}

function Convert-EventProcessId {
    param([object]$Value)
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return 0 }
    try {
        if ($text.StartsWith("0x", [System.StringComparison]::OrdinalIgnoreCase)) {
            return [int][Convert]::ToInt64($text.Substring(2), 16)
        }
        return [int][Convert]::ToInt64($text, 10)
    } catch { return 0 }
}

function Invoke-NetworkAuditPositiveControl {
    # Positive control: one local TCP connect proves WFP success events are visible
    # before zero target-EXE socket/DNS/HTTP attempts are accepted.
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $client = $null
    $accepted = $null
    $port = 0
    try {
        $listener.Start()
        $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
        $client = [System.Net.Sockets.TcpClient]::new()
        $client.Connect([System.Net.IPAddress]::Loopback, $port)
        $accepted = $listener.AcceptTcpClient()
    } finally {
        if ($null -ne $accepted) { $accepted.Dispose() }
        if ($null -ne $client) { $client.Dispose() }
        $listener.Stop()
    }
    if ($port -le 0) { throw "WFP network audit positive control did not allocate a port" }
    return $port
}

function Assert-FirewallRule {
    param([string]$DisplayName, [string]$Direction, [string]$ExecutablePath)
    $rules = @(Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction Stop)
    if ($rules.Count -ne 1) { throw "Exact firewall rule was not installed: $DisplayName" }
    $rule = $rules[0]
    $application = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $rule
    if (
        [string]$rule.Enabled -ne "True" -or [string]$rule.Action -ne "Block" -or
        [string]$rule.Direction -ne $Direction -or
        -not ([string]$application.Program).Equals($ExecutablePath, [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        throw "Firewall rule verification failed: $DisplayName"
    }
}

function Sum-Property {
    param([object[]]$Reports, [string]$Property)
    $total = 0
    foreach ($report in $Reports) { $total += [int64]$report.engine_report.author_audit.$Property }
    return $total
}

Assert-Administrator
$resolvedManifest = (Resolve-Path -LiteralPath $ExportManifestPath).Path
if (-not (Test-PathWithin -Path $resolvedManifest -Root $allowedExportRoot)) {
    throw "ExportManifestPath must stay under $allowedExportRoot"
}
$manifest = Get-Content -Raw -LiteralPath $resolvedManifest -Encoding UTF8 | ConvertFrom-Json
if (
    [string]$manifest.document_type -ne "author_strategy_device_export_manifest_v1" -or
    [int]$manifest.schema_version -ne 1 -or @($manifest.release_target_platforms).Count -ne 1 -or
    [string]$manifest.release_target_platforms[0] -ne "windows"
) {
    throw "Unsupported Windows export manifest"
}
$outputDirectory = [System.IO.Path]::GetFullPath([string]$manifest.output_directory)
if (
    -not (Test-PathWithin -Path $outputDirectory -Root $allowedExportRoot) -or
    -not ([System.IO.Path]::GetFullPath((Split-Path -Parent $resolvedManifest))).Equals(
        $outputDirectory, [System.StringComparison]::OrdinalIgnoreCase
    )
) {
    throw "Export manifest location does not match its fixed output directory"
}
$executables = @($manifest.outputs | Where-Object { $_.kind -eq "executable" -and $_.platform -eq "windows" })
if ($executables.Count -ne 1) { throw "Export manifest must contain one Windows executable" }
$executablePath = [System.IO.Path]::GetFullPath([string]$executables[0].path)
if (-not (Test-PathWithin -Path $executablePath -Root $outputDirectory) -or -not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    throw "Exported executable is outside the fixed output directory or missing"
}
$executableItem = Get-Item -LiteralPath $executablePath
if ($executableItem.LinkType) { throw "Exported executable must not be a link" }
$executableSha256 = (Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash.ToUpperInvariant()
if ([int64]$executables[0].bytes -ne $executableItem.Length -or [string]$executables[0].sha256 -cne $executableSha256) {
    throw "Exported executable no longer matches the export manifest"
}

if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
    $EvidenceDirectory = Join-Path $outputDirectory ("windows-os-isolation-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
}
$evidenceDirectory = [System.IO.Path]::GetFullPath($EvidenceDirectory)
if (-not (Test-PathWithin -Path $evidenceDirectory -Root $outputDirectory)) {
    throw "EvidenceDirectory must stay under the fixed export output directory"
}
if (Test-Path -LiteralPath $evidenceDirectory) { throw "Refusing to overwrite existing evidence directory: $evidenceDirectory" }
New-Item -ItemType Directory -Path $evidenceDirectory | Out-Null

$runId = "windows-a5-{0}-{1}" -f (Get-Date -Format "yyyyMMddHHmmss"), ([Guid]::NewGuid().ToString("N").Substring(0, 8))
$outboundRule = "PTCGDAP-A5-$runId-outbound"
$inboundRule = "PTCGDAP-A5-$runId-inbound"
$auditBackup = Join-Path $evidenceDirectory "audit-policy-backup.csv"
$auditStartedUtc = (Get-Date).ToUniversalTime()
$auditEndedUtc = $null
$auditPolicyRestored = $false
$firewallRulesRemoved = $false
$networkEvents = @()
$processEvents = @()
$networkPositiveControlPid = $PID
$networkPositiveControlPort = 0
$processPositiveControlPid = 0
$uiReports = @()
$rollbackRaw = $null

try {
    & auditpol.exe /backup /file:$auditBackup | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Unable to back up Windows audit policy" }
    & auditpol.exe /set /subcategory:$wfpAuditGuid /success:enable /failure:enable | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Unable to enable WFP connection auditing" }
    & auditpol.exe /set /subcategory:$processAuditGuid /success:enable /failure:enable | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Unable to enable process creation auditing" }

    if (Get-NetFirewallRule -DisplayName $outboundRule -ErrorAction SilentlyContinue) {
        throw "Refusing to replace an existing firewall rule: $outboundRule"
    }
    if (Get-NetFirewallRule -DisplayName $inboundRule -ErrorAction SilentlyContinue) {
        throw "Refusing to replace an existing firewall rule: $inboundRule"
    }
    New-NetFirewallRule -DisplayName $outboundRule -Direction Outbound -Program $executablePath -Action Block -Profile Any -Enabled True | Out-Null
    New-NetFirewallRule -DisplayName $inboundRule -Direction Inbound -Program $executablePath -Action Block -Profile Any -Enabled True | Out-Null
    Assert-FirewallRule -DisplayName $outboundRule -Direction "Outbound" -ExecutablePath $executablePath
    Assert-FirewallRule -DisplayName $inboundRule -Direction "Inbound" -ExecutablePath $executablePath

    $positive = Start-Process -FilePath (Join-Path $env:SystemRoot "System32\cmd.exe") -ArgumentList "/d /c exit 0" -PassThru -WindowStyle Hidden
    $processPositiveControlPid = [int]$positive.Id
    $positive.WaitForExit()
    $positive.Dispose()
    $networkPositiveControlPort = Invoke-NetworkAuditPositiveControl

    for ($index = 1; $index -le 3; $index += 1) {
        $uiDirectory = Join-Path $evidenceDirectory ("ui-run-{0:D2}" -f $index)
        & $uiWrapper -ExecutablePath $executablePath -ArtifactDirectory $uiDirectory -SkipExport -MatchTimeoutSeconds $MatchTimeoutSeconds -ProductionDeviceCanary:(-not $DevelopmentAuditOnly) | Out-Null
        $uiReportPath = Join-Path $uiDirectory "report.json"
        if (-not (Test-Path -LiteralPath $uiReportPath -PathType Leaf)) { throw "UI run did not write its report" }
        $uiReport = Get-Content -Raw -LiteralPath $uiReportPath -Encoding UTF8 | ConvertFrom-Json
        if (
            -not [bool]$uiReport.passed -or [string]$uiReport.executable_sha256 -cne $executableSha256 -or
            [int]$uiReport.process.process_id -le 0
        ) {
            throw "UI run $index did not pass or did not bind the exact executable"
        }
        $uiReports += $uiReport
    }

    $rollbackRawPath = Join-Path $evidenceDirectory "rollback-raw.json"
    & $rollbackWrapper -ExportManifestPath $resolvedManifest -OutputPath $rollbackRawPath -ProductionDeviceCanary:(-not $DevelopmentAuditOnly) | Out-Null
    $rollbackRaw = Get-Content -Raw -LiteralPath $rollbackRawPath -Encoding UTF8 | ConvertFrom-Json
    if (
        -not [bool]$rollbackRaw.failed_closed_before_execution -or [int]$rollbackRaw.policy_calls -ne 0 -or
        [int]$rollbackRaw.engine_commits -ne 0 -or [bool]$rollbackRaw.user_packages_deleted
    ) {
        throw "Rollback drill did not fail closed before execution"
    }

    Start-Sleep -Seconds 3
    $auditEndedUtc = (Get-Date).ToUniversalTime()
    $networkEvents = Get-SecurityEvents -Ids @(5154, 5155, 5156, 5157, 5158, 5159) -StartTime $auditStartedUtc -EndTime $auditEndedUtc
    $processEvents = Get-SecurityEvents -Ids @(4688) -StartTime $auditStartedUtc -EndTime $auditEndedUtc
} finally {
    foreach ($ruleName in @($outboundRule, $inboundRule)) {
        try {
            if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
                Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction Stop
            }
        } catch { Write-Warning "Firewall cleanup failed for exact rule $ruleName`: $($_.Exception.Message)" }
    }
    try {
        $firewallRulesRemoved = -not (Get-NetFirewallRule -DisplayName $outboundRule -ErrorAction SilentlyContinue) -and
            -not (Get-NetFirewallRule -DisplayName $inboundRule -ErrorAction SilentlyContinue)
    } catch {
        $firewallRulesRemoved = $false
        Write-Warning "Firewall cleanup verification failed: $($_.Exception.Message)"
    }
    if (Test-Path -LiteralPath $auditBackup -PathType Leaf) {
        try {
            & auditpol.exe /restore /file:$auditBackup | Out-Null
            $auditPolicyRestored = $LASTEXITCODE -eq 0
        } catch {
            $auditPolicyRestored = $false
            Write-Warning "Audit policy restore failed: $($_.Exception.Message)"
        }
    }
}

if (-not $firewallRulesRemoved -or -not $auditPolicyRestored) {
    throw "Host firewall or audit policy cleanup could not be proven"
}

$uiProcessIds = @($uiReports | ForEach-Object { [int]$_.process.process_id } | Sort-Object -Unique)
$processRows = @($processEvents | ForEach-Object {
    $data = Convert-EventData $_
    [pscustomobject]@{
        id = [int]$_.Id
        time_utc = $_.TimeCreated.ToUniversalTime().ToString("o")
        new_process_id = Convert-EventProcessId ($data["NewProcessId"])
        creator_process_id = Convert-EventProcessId ($(if ($data.ContainsKey("CreatorProcessId")) { $data["CreatorProcessId"] } else { $data["ProcessId"] }))
        new_process_name = [string]$data["NewProcessName"]
        parent_process_name = [string]$data["ParentProcessName"]
    }
})
$targetStartRows = @($processRows | Where-Object { $_.new_process_id -in $uiProcessIds })
if (@($targetStartRows).Count -ne $uiProcessIds.Count) { throw "Process audit did not cover every UI target PID" }
$processPositiveControlRows = @($processRows | Where-Object { $_.new_process_id -eq $processPositiveControlPid })
if ($processPositiveControlRows.Count -lt 1) { throw "Process audit positive control was not observed" }
$targetProcessIds = @($uiProcessIds | Sort-Object -Unique)
$childRows = @($processRows | Where-Object { $_.creator_process_id -in $targetProcessIds })
$childProcessIds = @($childRows | ForEach-Object { [int]$_.new_process_id } | Where-Object { $_ -gt 0 } | Sort-Object -Unique)

$networkRows = @($networkEvents | ForEach-Object {
    $data = Convert-EventData $_
    [pscustomobject]@{
        id = [int]$_.Id
        time_utc = $_.TimeCreated.ToUniversalTime().ToString("o")
        process_id = Convert-EventProcessId ($data["ProcessID"])
        application = [string]$data["Application"]
        protocol = [string]$data["Protocol"]
        source_address = [string]$data["SourceAddress"]
        source_port = [string]$data["SourcePort"]
        destination_address = [string]$data["DestAddress"]
        destination_port = [string]$data["DestPort"]
    }
})
$positiveNetworkRows = @($networkRows | Where-Object {
    $_.process_id -eq $networkPositiveControlPid -and
    ($_.source_port -eq [string]$networkPositiveControlPort -or
        $_.destination_port -eq [string]$networkPositiveControlPort)
})
if ($positiveNetworkRows.Count -lt 1) { throw "WFP network audit positive control was not observed" }
$targetNetworkRows = @($networkRows | Where-Object { $_.process_id -in $targetProcessIds })
$dnsAttempts = @($targetNetworkRows | Where-Object { $_.destination_port -eq "53" }).Count
$httpAttempts = @($targetNetworkRows | Where-Object { $_.destination_port -in @("80", "443") }).Count

$decisionSamples = @()
$coldStarts = @()
$catalogSamples = @()
$matchLoadSamples = @()
$peakMemorySamples = @()
foreach ($report in $uiReports) {
    $coldStarts += [int]$report.measurements.cold_start_msec
    $catalogSamples += [int]$report.measurements.catalog_scan_msec
    $matchLoadSamples += [int]$report.measurements.match_load_msec
    $peakMemorySamples += [int]$report.process.peak_working_set_mib
    $decisionSamples += @($report.measurements.decision_msec | ForEach-Object { [int]$_ })
}
$profile = Get-Content -Raw -LiteralPath $profilePath -Encoding UTF8 | ConvertFrom-Json
$decisionSamplesMinimum = [int]$profile.measurement_method.decision_samples_minimum
if ($coldStarts.Count -ne 3 -or $decisionSamples.Count -lt $decisionSamplesMinimum) {
    throw "Three cold starts and decision_samples_minimum were not captured"
}

$firstAudit = $uiReports[0].engine_report.author_audit
$packageId = [string]$firstAudit.package_id
$packageVersion = [string]$firstAudit.package_version
$packageArchiveSha256 = [string]$firstAudit.archive_sha256
$signatureScope = [string]$firstAudit.signature_scope
$executionTrusted = [bool]$firstAudit.execution_trusted
foreach ($report in $uiReports) {
    $audit = $report.engine_report.author_audit
    if (
        [string]$audit.package_id -cne $packageId -or [string]$audit.package_version -cne $packageVersion -or
        [string]$audit.archive_sha256 -cne $packageArchiveSha256
    ) { throw "UI runs did not pin one exact package identity" }
}

$developmentCapture = [ordered]@{
    document_type = "author_strategy_windows_os_isolation_development_capture_v1"
    schema_version = 1
    run_id = $runId
    formal_device_report = $false
    production_ready = $false
    target_executable_sha256 = $executableSha256
    target_process_ids = $targetProcessIds
    network_event_source = "Security:5154-5159"
    process_event_source = "Security:4688"
    network_positive_control_pid = $networkPositiveControlPid
    network_positive_control_port = $networkPositiveControlPort
    network_positive_control_event_count = $positiveNetworkRows.Count
    process_positive_control_pid = $processPositiveControlPid
    process_positive_control_event_count = $processPositiveControlRows.Count
    os_network_block_enforced = $true
    socket_attempts = $targetNetworkRows.Count
    child_process_ids = $childProcessIds
    audit_policy_restored = $auditPolicyRestored
    firewall_rules_removed = $firewallRulesRemoved
    ui_runs_passed = @($uiReports | Where-Object { $_.passed }).Count
    decision_sample_count = $decisionSamples.Count
    signature_scope = $signatureScope
    execution_trusted = $executionTrusted
}
if ($DevelopmentAuditOnly) {
    $developmentPath = Join-Path $evidenceDirectory "development-os-isolation-capture.json"
    Write-NewJson -Path $developmentPath -Value $developmentCapture
    Write-Output $developmentPath
    exit 0
}

if ($signatureScope -ne "production_release" -or -not $executionTrusted) {
    throw "Formal device evidence requires an execution-trusted production_release package canary"
}
if ($targetNetworkRows.Count -ne 0) { throw "Target executable attempted socket, DNS, or HTTP access under the OS block" }
if ($childProcessIds.Count -ne 0) { throw "Target executable created an external child process" }

$networkAudit = [ordered]@{
    document_type = "author_strategy_windows_network_audit_v1"
    schema_version = 1
    run_id = $runId
    platform = "windows"
    target_executable_sha256 = $executableSha256
    audit_method = "windows_filtering_platform_security_events_5154_5159_v1"
    target_process_ids = $targetProcessIds
    os_network_block_enforced = $true
    socket_attempts = 0
    dns_attempts = $dnsAttempts
    http_attempts = $httpAttempts
    remote_inference_attempts = 0
    dynamic_download_attempts = 0
    firewall_rules_removed = $firewallRulesRemoved
    audit_policy_restored = $auditPolicyRestored
    passed = $true
}
$processAudit = [ordered]@{
    document_type = "author_strategy_windows_process_audit_v1"
    schema_version = 1
    run_id = $runId
    platform = "windows"
    target_executable_sha256 = $executableSha256
    audit_method = "windows_security_process_creation_4688_v1"
    target_process_ids = $targetProcessIds
    child_process_ids = @()
    external_process_attempts = 0
    system_python_required = $false
    sidecar_processes = @()
    external_compute_required = $false
    audit_policy_restored = $auditPolicyRestored
    passed = $true
}
$fullMatchAudit = [ordered]@{
    document_type = "author_strategy_windows_full_match_audit_v1"
    schema_version = 1
    run_id = $runId
    platform = "windows"
    target_executable_sha256 = $executableSha256
    package_id = $packageId
    package_version = $packageVersion
    package_archive_sha256 = $packageArchiveSha256
    signature_scope = $signatureScope
    execution_trusted = $executionTrusted
    ordinary_ui = $true
    real_mouse_input = $true
    complete_match_finished = $true
    cold_start_msec = $coldStarts
    decision_msec = $decisionSamples
    catalog_scan_msec = [int](($catalogSamples | Measure-Object -Maximum).Maximum)
    match_load_msec = [int](($matchLoadSamples | Measure-Object -Maximum).Maximum)
    peak_memory_mib = [int](($peakMemorySamples | Measure-Object -Maximum).Maximum)
    policy_calls = [int](Sum-Property -Reports $uiReports -Property "policy_calls")
    policy_successes = [int](Sum-Property -Reports $uiReports -Property "policy_successes")
    policy_errors = [int](Sum-Property -Reports $uiReports -Property "policy_errors")
    invalid_outputs = [int](Sum-Property -Reports $uiReports -Property "invalid_outputs")
    same_window_fallbacks = [int](Sum-Property -Reports $uiReports -Property "same_window_fallbacks")
    classic_fallbacks = [int](Sum-Property -Reports $uiReports -Property "classic_fallbacks")
    engine_rejections = [int](Sum-Property -Reports $uiReports -Property "engine_rejections")
    engine_commits = [int](Sum-Property -Reports $uiReports -Property "engine_commits")
    passed = $true
}
if (
    $fullMatchAudit.policy_calls -ne $decisionSamples.Count -or
    $fullMatchAudit.policy_successes -ne $decisionSamples.Count -or
    $fullMatchAudit.policy_errors -ne 0 -or $fullMatchAudit.invalid_outputs -ne 0 -or
    $fullMatchAudit.same_window_fallbacks -ne 0 -or $fullMatchAudit.classic_fallbacks -ne 0 -or
    $fullMatchAudit.engine_rejections -ne 0 -or $fullMatchAudit.engine_commits -lt 1
) { throw "Formal full-match policy accounting is not clean" }
$rollbackAudit = [ordered]@{
    document_type = "author_strategy_windows_rollback_audit_v1"
    schema_version = 1
    run_id = $runId
    platform = "windows"
    target_executable_sha256 = $executableSha256
    mode_disabled = $true
    user_packages_preserved = $true
    policy_calls_after_disable = 0
    engine_commits_after_disable = 0
    passed = $true
}

$networkPath = Join-Path $evidenceDirectory "network-audit.json"
$processPath = Join-Path $evidenceDirectory "process-audit.json"
$fullMatchPath = Join-Path $evidenceDirectory "full-match-audit.json"
$rollbackPath = Join-Path $evidenceDirectory "rollback-report.json"
Write-NewJson -Path $networkPath -Value $networkAudit
Write-NewJson -Path $processPath -Value $processAudit
Write-NewJson -Path $fullMatchPath -Value $fullMatchAudit
Write-NewJson -Path $rollbackPath -Value $rollbackAudit

function Relative-EvidencePath {
    param([string]$Path)
    return [System.IO.Path]::GetRelativePath($outputDirectory, $Path).Replace("\", "/")
}

$measurementInput = [ordered]@{
    document_type = "author_strategy_device_measurement_input_v1"
    schema_version = 1
    platform = "windows"
    architecture = "x86_64"
    offline = [ordered]@{
        network_blocked = $true
        complete_match_finished = $true
        remote_inference_attempts = 0
        dynamic_download_attempts = 0
    }
    runtime = [ordered]@{
        system_python_required = $false
        sidecar_processes = @()
        external_compute_required = $false
    }
    samples = [ordered]@{
        cold_start_msec = $coldStarts
        decision_msec = $decisionSamples
    }
    measurements = [ordered]@{
        catalog_scan_msec = $fullMatchAudit.catalog_scan_msec
        match_load_msec = $fullMatchAudit.match_load_msec
        peak_memory_mib = $fullMatchAudit.peak_memory_mib
        package_mib = [int][Math]::Ceiling($executableItem.Length / 1MB)
        thermal_status_max = $null
        battery_drain_percent_per_hour = $null
    }
    rollback = [ordered]@{
        mode_disabled = $true
        user_packages_preserved = $true
    }
    evidence_files = [ordered]@{
        export_manifest_sha256 = Relative-EvidencePath $resolvedManifest
        network_audit_sha256 = Relative-EvidencePath $networkPath
        process_audit_sha256 = Relative-EvidencePath $processPath
        full_match_audit_sha256 = Relative-EvidencePath $fullMatchPath
        rollback_report_sha256 = Relative-EvidencePath $rollbackPath
    }
}
$measurementPath = Join-Path $evidenceDirectory "measurements.json"
$formalReportPath = Join-Path $evidenceDirectory "formal-device-report.json"
Write-NewJson -Path $measurementPath -Value $measurementInput
& $PythonExe $reportBuilder --measurements $measurementPath --evidence-root $outputDirectory --output $formalReportPath
if ($LASTEXITCODE -ne 0) { throw "Formal device report builder rejected the captured evidence" }
Write-Output $formalReportPath
