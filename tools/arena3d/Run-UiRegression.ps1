[CmdletBinding()]
param(
    [string]$GameExe,
    [string]$Godot = 'D:\ai\godot\Godot_v4.6.1-stable_win64.exe',
    [string[]]$Cases,
    [ValidateSet('grove')][string[]]$Themes = @('grove'),
    [ValidateSet('gl_compatibility','forward_plus')][string]$Renderer = 'gl_compatibility',
    [int]$Repeat = 1,
    [string]$Output
)
$ErrorActionPreference = 'Stop'
$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
$pythonExe = if ($null -ne $pythonCommand) { $pythonCommand.Source } else { 'C:\Python313\python.exe' }
$runnerArguments = @((Join-Path $PSScriptRoot 'run_ui_regression.py'), '--godot', $Godot, '--renderer', $Renderer, '--repeat', "$Repeat", '--themes') + $Themes
if ($GameExe) { $runnerArguments += @('--exe', $GameExe) }
if ($Cases) { $runnerArguments += @('--cases') + $Cases }
if ($Output) { $runnerArguments += @('--output', $Output) }
& $pythonExe @runnerArguments
exit $LASTEXITCODE
