$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-Equal {
	param(
		$Actual,
		$Expected,
		[string]$Message
	)
	if ($Actual -ne $Expected) {
		throw "Assert-Equal failed: $Message. Expected=[$Expected] Actual=[$Actual]"
	}
}

function Assert-True {
	param(
		[bool]$Condition,
		[string]$Message
	)
	if (-not $Condition) {
		throw "Assert-True failed: $Message"
	}
}

function Invoke-BenchmarkScript {
	param(
		[string[]]$Arguments,
		[int]$ExpectedExitCode
	)

	& $powershellExe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
	$actualExitCode = [int]$LASTEXITCODE
	Assert-Equal $actualExitCode $ExpectedExitCode "benchmark script should return the acceptance exit code"
}

function Read-NonEmptyLines {
	param([string]$Path)
	return @(Get-Content -LiteralPath $Path | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "scripts\run_v18_rule_benchmarks.ps1"
$powershellExe = Join-Path $PSHOME "powershell.exe"
if (-not (Test-Path -LiteralPath $powershellExe -PathType Leaf)) {
	$powershellExe = (Get-Process -Id $PID).Path
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("ptcg_v18_benchmark_test_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$mockGodot = Join-Path $testRoot "mock_godot.exe"
$mockPython = Join-Path $testRoot "mock_python.exe"
$godotLog = Join-Path $testRoot "godot_calls.log"
$pythonLog = Join-Path $testRoot "python_calls.log"

$mockGodotSource = @'
using System;
using System.IO;

public static class MockGodot
{
    public static int Main(string[] args)
    {
        File.AppendAllText(Environment.GetEnvironmentVariable("MOCK_GODOT_CALLS"), string.Join(" ", args) + Environment.NewLine);
        string output = "";
        string deck = "";
        foreach (string arg in args)
        {
            if (arg.StartsWith("--json-output=")) output = arg.Substring("--json-output=".Length);
            if (arg.StartsWith("--deck-id=")) deck = arg.Substring("--deck-id=".Length);
        }
        string failDeck = Environment.GetEnvironmentVariable("MOCK_GODOT_FAIL_DECK") ?? "";
        if (failDeck.Length > 0 && deck == failDeck) return 9;
        if (output.Length == 0) return 8;
        File.WriteAllText(output, "{}");
        return 0;
    }
}
'@
$mockPythonSource = @'
using System;
using System.IO;

public static class MockPython
{
    public static int Main(string[] args)
    {
        File.AppendAllText(Environment.GetEnvironmentVariable("MOCK_PYTHON_CALLS"), string.Join(" ", args) + Environment.NewLine);
        return int.Parse(Environment.GetEnvironmentVariable("MOCK_ACCEPTANCE_EXIT") ?? "0");
    }
}
'@
Add-Type -TypeDefinition $mockGodotSource -Language CSharp -OutputAssembly $mockGodot -OutputType ConsoleApplication
Add-Type -TypeDefinition $mockPythonSource -Language CSharp -OutputAssembly $mockPython -OutputType ConsoleApplication

$env:MOCK_GODOT_CALLS = $godotLog
$env:MOCK_PYTHON_CALLS = $pythonLog
$env:MOCK_GODOT_FAIL_DECK = ""
$env:MOCK_ACCEPTANCE_EXIT = "0"

try {
	$defaultOutput = Join-Path $testRoot "default"
	Invoke-BenchmarkScript -ExpectedExitCode 0 -Arguments @(
		"-Iteration", "2",
		"-SeedBase", "21000",
		"-OutputDir", $defaultOutput,
		"-GodotExe", $mockGodot,
		"-PythonExe", $mockPython
	)

	$defaultCalls = @(Read-NonEmptyLines -Path $godotLog)
	Assert-Equal $defaultCalls.Count 48 "default run should schedule 24 decks in two modes"
	Assert-True ($defaultCalls[0] -like "*--deck-id=18000230*") "default run should start with the first catalog deck"
	Assert-True ($defaultCalls[47] -like "*--deck-id=800033475*") "default run should end with the last catalog deck"
	Assert-True ($defaultCalls[0] -like "*--anchor-id=575720*") "runner should use the Miraidon anchor"
	Assert-True ($defaultCalls[0] -like "*--games=100*") "runner should use 100 games"
	Assert-True ($defaultCalls[0] -like "*--max-steps=200*") "runner should cap games at 200 steps"
	Assert-True ($defaultCalls[0] -like "*--deck-decision-mode=rules_only*") "tracked deck should use rules_only"
	Assert-True ($defaultCalls[0] -like "*--anchor-decision-mode=rules_only*") "anchor deck should use rules_only"
	Assert-True ($defaultCalls[0] -notlike "*--deck-strong-fixed-opening*") "normal mode should not fix the opening"
	Assert-True ($defaultCalls[1] -like "*--deck-strong-fixed-opening*") "strong mode should fix only the tracked opening"
	Assert-True (Test-Path -LiteralPath (Join-Path $defaultOutput "v18_18000230_normal_r02_s21000_n100.json")) "result names should include deck, mode, round, seed, and game count"

	$pythonCalls = @(Read-NonEmptyLines -Path $pythonLog)
	Assert-Equal $pythonCalls.Count 1 "acceptance should run once after the batch"
	Assert-True ($pythonCalls[0] -like "*v18_rule_acceptance.py*") "batch should invoke the acceptance tool"
	Assert-True ($pythonCalls[0] -like "*--deck-ids 18000230,18000625*") "acceptance should receive the exact default deck set"

	Set-Content -LiteralPath $godotLog -Value "" -Encoding ASCII
	Set-Content -LiteralPath $pythonLog -Value "" -Encoding ASCII
	$resumeOutput = Join-Path $testRoot "resume"
	New-Item -ItemType Directory -Path $resumeOutput | Out-Null
	$existingPath = Join-Path $resumeOutput "v18_101_normal_r03_s22000_n100.json"
	Set-Content -LiteralPath $existingPath -Value "existing" -Encoding ASCII

	$commonArguments = @(
		"-deck-ids", "101,202",
		"-Iteration", "3",
		"-seed-base", "22000",
		"-output-dir", $resumeOutput,
		"-GodotExe", $mockGodot,
		"-PythonExe", $mockPython
	)
	Invoke-BenchmarkScript -ExpectedExitCode 0 -Arguments ($commonArguments + @("-only-missing"))
	$resumeCalls = @(Read-NonEmptyLines -Path $godotLog)
	Assert-Equal $resumeCalls.Count 3 "only-missing mode should preserve an existing result"
	Assert-Equal (Get-Content -LiteralPath $existingPath -Raw).Trim() "existing" "only-missing mode must not overwrite an existing result"

	Set-Content -LiteralPath $godotLog -Value "" -Encoding ASCII
	Invoke-BenchmarkScript -ExpectedExitCode 0 -Arguments ($commonArguments + @("-Force"))
	$forceCalls = @(Read-NonEmptyLines -Path $godotLog)
	Assert-Equal $forceCalls.Count 4 "force mode should rerun every deck-mode result"
	Assert-Equal (Get-Content -LiteralPath $existingPath -Raw).Trim() "{}" "force mode should replace an existing result"

	Set-Content -LiteralPath $godotLog -Value "" -Encoding ASCII
	Set-Content -LiteralPath $pythonLog -Value "" -Encoding ASCII
	$env:MOCK_GODOT_FAIL_DECK = "202"
	$env:MOCK_ACCEPTANCE_EXIT = "7"
	$failureOutput = Join-Path $testRoot "failure"
	Invoke-BenchmarkScript -ExpectedExitCode 7 -Arguments @(
		"-DeckIds", "101,202,303",
		"-Iteration", "4",
		"-SeedBase", "23000",
		"-OutputDir", $failureOutput,
		"-GodotExe", $mockGodot,
		"-PythonExe", $mockPython
	)

	$failureCalls = @(Read-NonEmptyLines -Path $godotLog)
	Assert-Equal $failureCalls.Count 6 "a failed benchmark should not stop later results"
	Assert-True ($failureCalls[5] -like "*--deck-id=303*") "the batch should continue through the final deck"
	$failurePythonCalls = @(Read-NonEmptyLines -Path $pythonLog)
	Assert-Equal $failurePythonCalls.Count 1 "acceptance should still run after benchmark failures"

	$statusFile = Get-ChildItem -LiteralPath $failureOutput -Filter "*.jsonl" | Select-Object -First 1
	Assert-True ($null -ne $statusFile) "batch should write a run status JSONL file"
	$statusEvents = @(Get-Content -LiteralPath $statusFile.FullName | ForEach-Object { $_ | ConvertFrom-Json })
	$failedEvents = @($statusEvents | Where-Object { $_.event -eq "benchmark_result" -and $_.status -eq "failed_process" })
	Assert-Equal $failedEvents.Count 2 "both failed modes should be recorded"
	Assert-Equal $statusEvents[-1].event "acceptance_finished" "status log should end with acceptance"
	Assert-Equal $statusEvents[-1].exit_code 7 "status log should retain the acceptance exit code"

	Write-Output "run_v18_rule_benchmarks tests passed"
} finally {
	Remove-Item Env:MOCK_GODOT_CALLS -ErrorAction SilentlyContinue
	Remove-Item Env:MOCK_PYTHON_CALLS -ErrorAction SilentlyContinue
	Remove-Item Env:MOCK_GODOT_FAIL_DECK -ErrorAction SilentlyContinue
	Remove-Item Env:MOCK_ACCEPTANCE_EXIT -ErrorAction SilentlyContinue
	$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
	$resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
	if ($resolvedTestRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
		Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
	}
}
