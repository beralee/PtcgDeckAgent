param(
    [string]$GodotExe = 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe',
    [string]$OutputRoot = ''
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $OutputRoot) { $OutputRoot = Join-Path $repo ('.tmp/windows-update-export-' + [Guid]::NewGuid().ToString('N')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if (-not $OutputRoot.StartsWith((Join-Path $repo '.tmp') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Tests must remain in the repository temporary directory.' }
New-Item -ItemType Directory -Path $OutputRoot | Out-Null
$project = Join-Path $OutputRoot 'project'
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-Fixture([string]$Relative, [string]$Text) {
    $destination = Join-Path $project $Relative
    New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($destination)) | Out-Null
    [IO.File]::WriteAllText($destination, $Text, $utf8)
}
foreach ($source in @('scripts/update/AppUpdater.gd', 'scripts/update/AppUpdateInstaller.gd', 'scripts/update/AppUpdateManifest.gd', 'scripts/update/AppUpdateDialog.gd', 'scripts/update/AppUpdateProgress.gd', 'scripts/update/install_windows.ps1', 'scripts/ui/HudTheme.gd')) {
    $destination = Join-Path $project $source
    New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($destination)) | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo $source) -Destination $destination
}
Write-Fixture 'project.godot' @'
config_version=5
[application]
config/name="PtcgWindowsUpdateEntryLab"
run/main_scene="res://scenes/main_menu/MainMenu.tscn"
[autoload]
AppUpdater="*res://scripts/update/AppUpdater.gd"
[display]
window/size/viewport_width=400
window/size/viewport_height=300
[rendering]
renderer/rendering_method="gl_compatibility"
'@
Write-Fixture 'export_presets.cfg' @'
[preset.0]
name="Windows Lab"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="scripts/update/*.ps1"
exclude_filter=""
export_path=""
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2
[preset.0.options]
binary_format/embed_pck=true
binary_format/architecture="x86_64"
debug/export_console_wrapper=0
application/modify_resources=false
'@
Write-Fixture 'scenes/main_menu/MainMenu.tscn' @'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://Home.gd" id="1"]
[node name="MainMenu" type="Control"]
script = ExtResource("1")
'@
Write-Fixture 'Home.gd' @'
extends Control

func _ready() -> void:
    if DisplayServer.get_name() != "headless":
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
    call_deferred("_exercise")

func _record(name: String, value: Dictionary) -> void:
    var file := FileAccess.open("user://" + name + ".json", FileAccess.WRITE)
    file.store_string(JSON.stringify(value))
    file.close()

func _exercise() -> void:
    var updater := get_node("/root/AppUpdater")
    if preload("res://scripts/app/AppVersion.gd").current_version() == "99.0.1":
        updater.confirm_healthy_startup()
        var receipt := "normal_boot" if OS.get_cmdline_user_args().is_empty() else "restarted"
        _record(receipt, {"pid": OS.get_process_id(), "version": "99.0.1", "state": updater.snapshot().state, "pending": FileAccess.file_exists(updater.STATE_PATH), "empty_info": updater.snapshot().info.is_empty()})
        return
    while updater.snapshot().state == "verifying":
        await get_tree().process_frame
    if updater.snapshot().state != "ready" or not updater.snapshot().install_reason.is_empty():
        _record("test_failed", updater.snapshot())
        get_tree().quit(1)
        return
    # Headless launch still exercises real buttons, state machine, helper,
    # self-exit, EXE replacement, relaunch and home health receipt.
    if OS.get_environment("PTCG_WINDOWS_UPDATE_ENTRY_CASE") == "dialog":
        updater.show_progress_dialog()
        updater._open_dialogs[0].get_ref()._primary.pressed.emit()
    else:
        var button := Button.new()
        button.name = "UpdateButton"
        add_child(button)
        button.pressed.connect(updater.activate_update_entry)
        button.pressed.emit()
    _record("clicked", {"state": updater.snapshot().state, "after_verify": updater._after_verify, "pid": OS.get_process_id()})
'@

foreach ($build in @(@{name='old';version='99.0.0'}, @{name='new';version='99.0.1'})) {
    Write-Fixture 'scripts/app/AppVersion.gd' (('extends RefCounted', ('const VERSION := "' + $build.version + '"'), 'static func current_version() -> String: return VERSION', 'static func current_display_version() -> String: return VERSION', 'static func current_build_number() -> int: return 1') -join "`n")
    $destination = Join-Path $OutputRoot ($build.name + '.exe')
    $log = Join-Path $OutputRoot ($build.name + '-export.log')
    & $GodotExe --headless --path $project --export-release 'Windows Lab' $destination --quit *> $log
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) { throw "Export failed: $log" }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$savedAppData = $env:APPDATA
$savedCase = $env:PTCG_WINDOWS_UPDATE_ENTRY_CASE
$results = @()
try {
    foreach ($case in @('home', 'dialog')) {
        # Exercise spaces and non-ASCII in both user data and the install path.
        $caseRoot = Join-Path $OutputRoot ($case + ' ' + [char]0x6E38 + [char]0x620F)
        $appdata = Join-Path $caseRoot 'user data'
        $userRoot = Join-Path $appdata 'Godot/app_userdata/PtcgWindowsUpdateEntryLab'
        $updates = Join-Path $userRoot 'app_updates'
        $install = Join-Path $caseRoot 'game install'
        New-Item -ItemType Directory -Force -Path $updates,$install | Out-Null
        $exe = Join-Path $install 'Game.exe'
        Copy-Item -LiteralPath (Join-Path $OutputRoot 'old.exe') -Destination $exe
        [IO.File]::WriteAllText((Join-Path $userRoot 'my-deck.json'), 'player-data', $utf8)
        $zip = Join-Path $updates 'package.zip'
        $archive = [IO.Compression.ZipFile]::Open($zip, 'Create')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $OutputRoot 'new.exe'), 'Game.exe') | Out-Null
        $archive.Dispose()
        $hash = (Get-FileHash -LiteralPath $zip).Hash.ToLowerInvariant()
        $size = (Get-Item -LiteralPath $zip).Length
        Move-Item -LiteralPath $zip -Destination (Join-Path $updates ($hash + '.zip'))
        $pending = @{latest_version='99.0.1'; artifact=@{arch='x86_64';format='windows_zip';entry='Game.exe';url='https://ptcg.skillserver.cn/dist/updates/test.zip';size=$size;sha256=$hash}}
        [IO.File]::WriteAllText((Join-Path $updates 'pending.json'), ($pending | ConvertTo-Json -Depth 5), $utf8)
        $env:APPDATA = $appdata
        $env:PTCG_WINDOWS_UPDATE_ENTRY_CASE = $case
        $game = $null
        try {
            $game = Start-Process -FilePath $exe -ArgumentList '--headless' -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $caseRoot 'stdout.log') -RedirectStandardError (Join-Path $caseRoot 'stderr.log')
            # Retain the native handle before self-exit so Windows PowerShell 5
            # can still read the exit code after the helper replaces the EXE.
            $gameHandle = $game.Handle
            $deadline = [DateTime]::UtcNow.AddSeconds(60)
            do {
                $sessions = @(Get-ChildItem -LiteralPath $updates -Directory)
                $failure = @($sessions | ForEach-Object { Join-Path $_.FullName 'failed.txt' } | Where-Object { Test-Path -LiteralPath $_ })
                if ($failure.Count) { throw ([IO.File]::ReadAllText($failure[0])) }
                if (Test-Path -LiteralPath (Join-Path $userRoot 'test_failed.json')) { throw 'Exported game could not start installation.' }
                $success = @($sessions | ForEach-Object { Join-Path $_.FullName 'success' } | Where-Object { Test-Path -LiteralPath $_ })
                if ($success.Count) { break }
                if ([DateTime]::UtcNow -gt $deadline) { throw "Exported update timed out: $caseRoot" }
                Start-Sleep -Milliseconds 200
            } while ($true)
            $clicked = Get-Content -LiteralPath (Join-Path $userRoot 'clicked.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $restarted = Get-Content -LiteralPath (Join-Path $userRoot 'restarted.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($clicked.state -ne 'verifying' -or $clicked.after_verify -ne 'install') { throw 'First click did not authorize verified installation.' }
            if (-not $game.WaitForExit(5000) -or $game.ExitCode -ne 0 -or $restarted.pid -eq $game.Id -or $restarted.state -ne 'updated') { throw "Restart check failed: old=$($game.Id), exited=$($game.HasExited), exit=$($game.ExitCode), new=$($restarted.pid), state=$($restarted.state), handle=$gameHandle" }
            if ((Get-FileHash -LiteralPath $exe).Hash -ne (Get-FileHash -LiteralPath (Join-Path $OutputRoot 'new.exe')).Hash) { throw 'Installed EXE bytes mismatch.' }
            if ([IO.File]::ReadAllText((Join-Path $userRoot 'my-deck.json')) -ne 'player-data') { throw 'Player data changed.' }
            if ((Get-Item -LiteralPath (Join-Path $caseRoot 'stderr.log')).Length) { throw 'Exported source game emitted errors.' }
            if ($restarted.pending -or -not $restarted.empty_info) { throw 'Successful installation retained stale pending state.' }
            # A second, ordinary launch must also remain idle without an update token.
            Get-Process -Name Game -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe } | Stop-Process -Force
            $reopen = Start-Process -FilePath $exe -ArgumentList '--headless' -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $caseRoot 'reopen-stdout.log') -RedirectStandardError (Join-Path $caseRoot 'reopen-stderr.log')
            $reopenHandle = $reopen.Handle
            $deadline = [DateTime]::UtcNow.AddSeconds(20)
            $normalReceipt = Join-Path $userRoot 'normal_boot.json'
            while (-not (Test-Path -LiteralPath $normalReceipt)) {
                if ($reopen.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw "Ordinary reopen failed: $caseRoot, handle=$reopenHandle" }
                Start-Sleep -Milliseconds 100
                $reopen.Refresh()
            }
            $normal = Get-Content -LiteralPath $normalReceipt -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($normal.state -ne 'idle' -or $normal.pending -or -not $normal.empty_info) { throw 'Ordinary reopen resurrected the completed update.' }
            if ((Get-Item -LiteralPath (Join-Path $caseRoot 'reopen-stderr.log')).Length) { throw 'Ordinary reopen emitted errors.' }
            $results += @{case=$case;passed=$true;old_pid=$game.Id;new_pid=$restarted.pid;version=$restarted.version;player_data_preserved=$true;normal_reopen_state=$normal.state;pending_cleared=$true}
            Write-Output "PASS exported $case -> replacement / restart / health / ordinary reopen stays idle"
        } finally {
            # Exact test-owned paths only; never stop an actual player/editor process.
            foreach ($session in @(Get-ChildItem -LiteralPath $updates -Directory)) {
                [IO.File]::WriteAllText((Join-Path $session.FullName 'cancelled'), '', $utf8)
            }
            Get-Process -Name Game -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe } | Stop-Process -Force
        }
    }
} finally {
    $env:APPDATA = $savedAppData
    $env:PTCG_WINDOWS_UPDATE_ENTRY_CASE = $savedCase
}
[IO.File]::WriteAllText((Join-Path $OutputRoot 'results.json'), (ConvertTo-Json -Depth 5 -InputObject $results), $utf8)
Write-Output "Evidence: $OutputRoot"
