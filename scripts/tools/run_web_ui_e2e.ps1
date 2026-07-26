param(
    [string]$GodotPath = "D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe",
    [switch]$SkipExport,
    [switch]$SkipBrowserInstall,
    [string]$Project = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$e2eDir = Join-Path $repoRoot "tests\web_e2e"
$exportDir = Join-Path $repoRoot ".tmp\web_ui_e2e"
$exportFile = Join-Path $exportDir "PtcgDeckAgent.html"

if (-not $SkipExport) {
    New-Item -ItemType Directory -Force -Path $exportDir | Out-Null
    & $GodotPath --headless --path $repoRoot --export-debug "Web UI E2E" $exportFile
    if ($LASTEXITCODE -ne 0) { throw "Godot Web UI E2E export failed with exit code $LASTEXITCODE" }
    Copy-Item -LiteralPath (Join-Path $repoRoot "web\userptcg_bridge.html") -Destination (Join-Path $exportDir "userptcg_bridge.html") -Force
    $latest = [ordered]@{
        schema_version = 1
        version = "0.5.1"
        display_version = "v0.5.1"
        build_number = 51
        channel = "e2e"
        release_path = "/"
        entry = "/PtcgDeckAgent.html"
        generated_at = (Get-Date).ToUniversalTime().ToString("o")
    } | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText((Join-Path $exportDir "latest-web.json"), $latest, [System.Text.UTF8Encoding]::new($false))
    & (Join-Path $PSScriptRoot "check_web_export_budget.ps1") -ExportDirectory $exportDir -ReportPath (Join-Path $repoRoot ".tmp\web_ui_e2e_artifacts\resource-budget.json")
}

Push-Location $e2eDir
try {
    if (-not (Test-Path (Join-Path $e2eDir "node_modules\.bin\playwright.cmd"))) {
        npm install --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw "npm install failed with exit code $LASTEXITCODE" }
    }
    if (-not $SkipBrowserInstall) {
        npx playwright install chromium webkit
        if ($LASTEXITCODE -ne 0) { throw "Playwright browser install failed with exit code $LASTEXITCODE" }
    }
    $playwright = Join-Path $e2eDir "node_modules\.bin\playwright.cmd"
    if ($Project -ne "") {
        & $playwright test "--project=$Project"
    }
    else {
        & $playwright test
    }
    if ($LASTEXITCODE -ne 0) { throw "Web UI E2E failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}
