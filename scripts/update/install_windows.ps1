param([Parameter(Mandatory = $true)][string]$PlanPath)
$ErrorActionPreference = 'Stop'
$sessionPath = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($PlanPath))
$lockStream = $null
$newProcess = $null
$journal = @()
$mutating = $false

function Write-Marker([string]$Name, [string]$Text = '') {
    [IO.File]::WriteAllText((Join-Path $sessionPath $Name), $Text, [Text.UTF8Encoding]::new($false))
}
function Assert-NoLink([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked install paths are not supported.' }
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}
function Child-Path([string]$Root, [string]$Relative) {
    $prefix = [IO.Path]::GetFullPath($Root).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    $candidate = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Path escaped its owner directory.' }
    return $candidate
}
function Save-Journal {
    Write-Marker 'journal.json' (ConvertTo-Json -Depth 6 -InputObject @($journal))
}
function Restore-Files {
    for ($i = $journal.Count - 1; $i -ge 0; $i--) {
        $item = $journal[$i]
        Assert-NoLink $item.target
        if ($item.existed) {
            Copy-Item -LiteralPath $item.backup -Destination $item.target -Force
        } elseif (Test-Path -LiteralPath $item.target -PathType Leaf) {
            Remove-Item -LiteralPath $item.target -Force
        }
    }
}

try {
    Assert-NoLink $sessionPath
    $plan = Get-Content -LiteralPath $PlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($plan.schema -ne 1 -or $plan.token -notmatch '^[0-9a-f]{32}$' -or $plan.sha256 -notmatch '^[0-9a-f]{64}$') { throw 'Invalid plan.' }
    if ([IO.Path]::GetFullPath($plan.session) -ne $sessionPath) { throw 'Session mismatch.' }
    $targetExe = [IO.Path]::GetFullPath($plan.executable)
    $targetRoot = [IO.Path]::GetDirectoryName($targetExe)
    if ($targetRoot -eq [IO.Path]::GetPathRoot($targetRoot)) { throw 'Install in a dedicated folder before updating.' }
    Assert-NoLink $targetExe
    Assert-NoLink $plan.package
    $lockStream = [IO.File]::Open((Join-Path $targetRoot '.ptcg-update.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    $oldProcess = Get-Process -Id $plan.pid -ErrorAction Stop
    if ([IO.Path]::GetFullPath($oldProcess.Path) -ne $targetExe) { throw 'The running game no longer matches this plan.' }
    $oldStart = $oldProcess.StartTime
    $packageItem = Get-Item -LiteralPath $plan.package
    if ($packageItem.Length -ne $plan.size -or (Get-FileHash -LiteralPath $plan.package -Algorithm SHA256).Hash -ne $plan.sha256) { throw 'Package integrity check failed.' }
    $stageRoot = Join-Path $sessionPath 'stage'
    $backupRoot = Join-Path $sessionPath 'backup'
    New-Item -ItemType Directory -Path $stageRoot,$backupRoot | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($plan.package)
    $files = @()
    $seen = @{}
    $expandedBytes = 0L
    try {
        if ($archive.Entries.Count -gt 20000) { throw 'Too many archive entries.' }
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName
            if ($name.Contains('\') -or $name.StartsWith('/') -or $name -match '[\x00-\x1f\x7f:*?"<>|%]') { throw 'Invalid archive path.' }
            $trimmed = $name.TrimEnd('/')
            foreach ($component in $trimmed.Split('/')) {
                if (-not $component -or $component -in @('.','..') -or $component -match '[. ]$' -or $component -match '^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(\.|$)') { throw 'Unsafe archive component.' }
            }
            if ($seen.ContainsKey($trimmed)) { throw 'Duplicate archive path.' }
            $seen[$trimmed] = $true
            $mode = ($entry.ExternalAttributes -shr 16) -band 0xf000
            if ($mode -ne 0 -and $mode -ne 0x8000 -and $mode -ne 0x4000) { throw 'Special archive entries are not allowed.' }
            $expandedBytes += $entry.Length
            if ($expandedBytes -gt 4GB -or $entry.Length -gt 2GB) { throw 'Archive exceeds resource limit.' }
            $stage = Child-Path $stageRoot $trimmed
            if ($name.EndsWith('/')) {
                New-Item -ItemType Directory -Force -Path $stage | Out-Null
                continue
            }
            $relative = if ($name -eq $plan.entry) { [IO.Path]::GetFileName($targetExe) } else { $name }
            if ($relative -eq '.ptcg-update.lock' -or ($name -ne $plan.entry -and $relative -eq [IO.Path]::GetFileName($targetExe))) { throw 'Archive conflicts with the running application.' }
            $target = Child-Path $targetRoot $relative
            Assert-NoLink $target
            New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($stage)) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $stage, $false)
            $files += [pscustomobject]@{ stage = $stage; target = $target; relative = $relative }
        }
    } finally { $archive.Dispose() }
    if (-not $seen.ContainsKey($plan.entry) -or $plan.entry -match '[/\\]' -or -not $plan.entry.EndsWith('.exe')) { throw 'Application entry is missing.' }
    # Probe directory permissions before asking the old game to close.
    $probe = Join-Path $targetRoot ('.ptcg-write-' + $plan.token)
    [IO.File]::WriteAllText($probe, '')
    Remove-Item -LiteralPath $probe
    Write-Marker 'prepared'
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    while ($true) {
        $current = Get-Process -Id $plan.pid -ErrorAction SilentlyContinue
        if (-not $current -or $current.StartTime -ne $oldStart) { break }
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Game did not close; update cancelled.' }
        Start-Sleep -Milliseconds 200
    }
    foreach ($item in $files) {
        $backup = Child-Path $backupRoot $item.relative
        $exists = Test-Path -LiteralPath $item.target -PathType Leaf
        if ($exists) {
            New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($backup)) | Out-Null
            Copy-Item -LiteralPath $item.target -Destination $backup
        }
        $journal += [pscustomobject]@{ target = $item.target; backup = $backup; existed = $exists }
    }
    Save-Journal
    $mutating = $true
    foreach ($item in $files) {
        Assert-NoLink $item.target
        New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($item.target)) | Out-Null
        Copy-Item -LiteralPath $item.stage -Destination $item.target -Force
    }
    # Visible game window is the requested interactive restart; helper stays hidden.
    $newProcess = Start-Process -FilePath $targetExe -ArgumentList @('--', ('--ptcg-update-token=' + $plan.token)) -WorkingDirectory $targetRoot -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    while (-not (Test-Path -LiteralPath (Join-Path $sessionPath 'healthy'))) {
        if ($newProcess.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'Updated game did not reach its home screen.' }
        Start-Sleep -Milliseconds 250
        $newProcess.Refresh()
    }
    if ((Get-Content -LiteralPath (Join-Path $sessionPath 'healthy') -Raw) -ne $plan.version) { throw 'Unexpected installed version.' }
    Write-Marker 'success' $plan.version
    $mutating = $false
} catch {
    if ($mutating) {
        try {
            if ($newProcess -and -not $newProcess.HasExited) { $newProcess.Kill(); $newProcess.WaitForExit(10000) | Out-Null }
            Restore-Files
            Write-Marker 'rolled_back'
            Start-Process -FilePath $targetExe -ArgumentList @('--', ('--ptcg-update-rollback=' + $plan.token)) -WorkingDirectory $targetRoot | Out-Null
        } catch { Write-Marker 'rollback_failed.txt' 'Use the reinstall entry; retained backups and journal are in this directory.' }
    }
    Write-Marker 'failed.txt' $_.Exception.Message
    exit 1
} finally {
    if ($lockStream) { $lockStream.Dispose() }
}
