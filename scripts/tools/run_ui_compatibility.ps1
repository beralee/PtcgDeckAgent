param(
    [string]$GodotPath = 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe',
    [switch]$IncludeWeb
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$artifact = Join-Path $repo '.tmp/ui_compatibility'
New-Item -ItemType Directory -Force -Path $artifact | Out-Null
$suites = @(
    'tests/ui/test_strategy_hub_input_compatibility.gd',
    'tests/test_deck_importer.gd',
    'tests/ptcgdap/godot/test_strategy_hub_scene.gd',
    'tests/ptcgdap/godot/test_strategy_hub_ladder_presentation.gd',
    'tests/ptcgdap/godot/test_author_strategy_battle_setup.gd',
    'tests/test_non_battle_portrait_layout.gd',
    'tests/test_non_battle_web_input_v2.gd',
    'tests/test_web_input_adapter.gd',
    'tests/test_web_ui_e2e_bridge.gd'
)
$results = @()
foreach ($suite in $suites) {
    $log = Join-Path $artifact (([IO.Path]::GetFileNameWithoutExtension($suite)) + '.log')
    & $GodotPath --headless --path $repo --script tests/FocusedSuiteRunner.gd -- "--suite-script=res://$suite" *> $log
    $code = $LASTEXITCODE
    $summary = Select-String -LiteralPath $log -Pattern '^Total: (\d+) \| Failed: (\d+)' | Select-Object -Last 1
    $passed = $code -eq 0 -and $null -ne $summary -and $summary.Matches[0].Groups[2].Value -eq '0'
    $results += [ordered]@{ suite = $suite; passed = $passed; exit_code = $code; summary = [string]$summary.Line; log = $log }
    Write-Output "$suite : $passed $($summary.Line)"
}
if ($IncludeWeb) {
    try {
        & node --test (Join-Path $repo 'tests/web_e2e/deck-import-gateway.test.mjs')
        $results += [ordered]@{ suite = 'deck_import_gateway'; passed = ($LASTEXITCODE -eq 0) }
        & (Join-Path $PSScriptRoot 'run_web_ui_e2e.ps1') -GodotPath $GodotPath -TestFilter 'Safari deck import|strategy hub settings|AI ladder shows|navigates main menu and settings|iOS Web AI key'
        $results += [ordered]@{ suite = 'browser_e2e'; passed = ($LASTEXITCODE -eq 0) }
    } catch {
        $results += [ordered]@{ suite = 'browser_e2e'; passed = $false; error = $_.Exception.Message }
    }
}
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $artifact 'report.json') -Encoding utf8
if ($results.Where({ -not $_.passed }).Count -gt 0) { exit 1 }
