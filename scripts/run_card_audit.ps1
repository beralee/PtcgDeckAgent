param(
    [string]$GodotDir = "D:\ai\godot",
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$Scene = "res://tests/FocusedSuiteRunner.gd",
    [string]$SuiteScript = "res://tests/test_card_catalog_audit.gd",
    [string]$UserDataRoot = $env:APPDATA
)

$ErrorActionPreference = "Stop"

function Resolve-GodotConsoleExe {
    param([string]$BaseDir)

    $preferred = Join-Path $BaseDir "Godot_v4.6.1-stable_win64_console.exe"
    if (Test-Path $preferred) {
        return (Resolve-Path $preferred).Path
    }

    $candidate = Get-ChildItem -Path $BaseDir -Filter "*console*.exe" -File |
        Sort-Object Name |
        Select-Object -First 1
    if ($null -ne $candidate) {
        return $candidate.FullName
    }

    throw "Godot console executable not found under '$BaseDir'."
}

function Copy-AuditArtifactIfNewer {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        return
    }

    try {
        $destinationRoot = Split-Path -Parent $DestinationPath
        New-Item -ItemType Directory -Force -Path $destinationRoot -ErrorAction Stop | Out-Null

        $sourceItem = Get-Item -LiteralPath $SourcePath
        $shouldCopy = -not (Test-Path -LiteralPath $DestinationPath)
        if (-not $shouldCopy) {
            $destinationItem = Get-Item -LiteralPath $DestinationPath
            $shouldCopy = $sourceItem.LastWriteTime -gt $destinationItem.LastWriteTime
        }

        if ($shouldCopy) {
            Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop
            Write-Host "Updated ${Label}:" $DestinationPath
        }
    } catch {
        Write-Warning "Could not update $Label at '$DestinationPath': $($_.Exception.Message)"
    }
}

$godotExe = Resolve-GodotConsoleExe -BaseDir $GodotDir
$projectRootPath = (Resolve-Path $ProjectRoot).Path
$userDataRootPath = (Resolve-Path $UserDataRoot).Path
$reportPath = Join-Path $userDataRootPath "Godot\app_userdata\PtcgDeckAgent\logs\card_audit_latest.txt"
$statusMatrixPath = Join-Path $userDataRootPath "Godot\app_userdata\PtcgDeckAgent\logs\card_status_matrix_latest.txt"
$logRoot = Join-Path $projectRootPath ".godot_test_user\logs"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$logFile = Join-Path $logRoot ("card-audit-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

Write-Host "Godot:" $godotExe
Write-Host "Project:" $projectRootPath
Write-Host "Entry:" $Scene
Write-Host "Godot user data root:" $userDataRootPath
Write-Host "Godot log:" $logFile

$previousAppData = $env:APPDATA
try {
    $env:APPDATA = $userDataRootPath
    if ([System.IO.Path]::GetExtension($Scene).ToLowerInvariant() -eq ".gd") {
        if ([string]::IsNullOrWhiteSpace($SuiteScript)) {
            & $godotExe --headless --log-file $logFile --path $projectRootPath -s $Scene
        } else {
            & $godotExe --headless --log-file $logFile --path $projectRootPath -s $Scene -- "--suite-script=$SuiteScript"
        }
    } else {
        if ([string]::IsNullOrWhiteSpace($SuiteScript)) {
            & $godotExe --headless --log-file $logFile --path $projectRootPath $Scene
        } else {
            & $godotExe --headless --log-file $logFile --path $projectRootPath $Scene -- "--suite-script=$SuiteScript"
        }
    }
} finally {
    $env:APPDATA = $previousAppData
}
$exitCode = $LASTEXITCODE

$generatedLogRoot = Join-Path $projectRootPath ".godot_test_user\appdata\Godot\app_userdata\PtcgDeckAgent\logs"
$generatedReportPath = Join-Path $generatedLogRoot "card_audit_latest.txt"
$generatedStatusMatrixPath = Join-Path $generatedLogRoot "card_status_matrix_latest.txt"
Copy-AuditArtifactIfNewer -SourcePath $generatedReportPath -DestinationPath $reportPath -Label "card audit report"
Copy-AuditArtifactIfNewer -SourcePath $generatedStatusMatrixPath -DestinationPath $statusMatrixPath -Label "card status matrix"

Write-Host "Exit code:" $exitCode
if (Test-Path $reportPath) {
    Write-Host "Card audit report:" $reportPath
}
if (Test-Path $statusMatrixPath) {
    Write-Host "Card status matrix:" $statusMatrixPath
}

exit $exitCode
