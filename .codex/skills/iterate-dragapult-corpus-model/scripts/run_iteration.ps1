[CmdletBinding()]
param(
    [ValidateSet("audit", "train", "build", "test", "benchmark", "all")]
    [string]$Stage = "audit",
    [string]$Root = "D:\ai\code\ptcgabc",
    [string]$Corpus = "D:\ai\code\ptcgabc\artifacts\training_data\dragapult_10000_v1",
    [string]$TrainingRun = "artifacts\training_runs\dragapult_corpus_graph_v0_3_0",
    [string]$CandidateDir = "agents\dragapult_corpus_graph_v0_3_1_candidate",
    [string]$CandidateId = "dragapult-corpus-graph-v0.3.1",
    [string]$Config = "league\configs\dragapult-corpus-v031-vs-v121a.json",
    [string]$FeedbackRunId = "dragapult_corpus_model_iteration",
    [int]$GamesPerSeat = 10,
    [int]$Workers = 12
)

$ErrorActionPreference = "Stop"
$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$python311 = Join-Path $resolvedRoot ".venv311\Scripts\python.exe"
$python = if (Test-Path -LiteralPath $python311) { $python311 } else { "python" }
$trainingPath = Join-Path $resolvedRoot $TrainingRun
$candidatePath = Join-Path $resolvedRoot $CandidateDir
$configPath = Join-Path $resolvedRoot $Config

function Invoke-Audit {
    & $python (Join-Path $resolvedRoot "tools\audit_dragapult_training_corpus.py") `
        --dataset-dir $Corpus
    if ($LASTEXITCODE -ne 0) { throw "Corpus audit failed." }
}

function Invoke-Train {
    & $python (Join-Path $resolvedRoot "tools\train_dragapult_corpus_graph_model.py") `
        --corpus $Corpus `
        --output-dir $trainingPath
    if ($LASTEXITCODE -ne 0) { throw "Model training failed." }
}

function Invoke-Build {
    & $python (Join-Path $resolvedRoot "tools\build_dragapult_corpus_graph_candidate.py") `
        --model (Join-Path $trainingPath "model.json") `
        --output-dir $candidatePath `
        --candidate-id $CandidateId
    if ($LASTEXITCODE -ne 0) { throw "Candidate build failed." }
}

function Invoke-Test {
    $env:DRAGAPULT_CORPUS_CANDIDATE_PATH = $candidatePath
    $env:DRAGAPULT_AGENT_PATH = Join-Path $candidatePath "main.py"
    & $python (Join-Path $resolvedRoot "tools\test_dragapult_corpus_graph_model.py")
    if ($LASTEXITCODE -ne 0) { throw "Corpus-model contracts failed." }
    & $python (Join-Path $resolvedRoot "tools\test_dragapult_graph_v1.py")
    if ($LASTEXITCODE -ne 0) { throw "Dragapult Graph regressions failed." }
    & $python (Join-Path $resolvedRoot "tools\validate_agent.py") `
        --agent-dir $candidatePath `
        --report (Join-Path $trainingPath "validate_agent.json") `
        --replay (Join-Path $trainingPath "validate_agent_replay.json")
    if ($LASTEXITCODE -ne 0) { throw "Native Agent validation failed." }
}

function Invoke-Benchmark {
    & $python (Join-Path $resolvedRoot "tools\run_feedback_loop.py") `
        --config $configPath `
        --games-per-seat $GamesPerSeat `
        --workers $Workers `
        --run-id $FeedbackRunId
    if ($LASTEXITCODE -ne 0) { throw "Paired benchmark failed." }
}

Push-Location $resolvedRoot
try {
    switch ($Stage) {
        "audit" { Invoke-Audit }
        "train" { Invoke-Train }
        "build" { Invoke-Build }
        "test" { Invoke-Test }
        "benchmark" { Invoke-Benchmark }
        "all" {
            Invoke-Audit
            Invoke-Train
            Invoke-Build
            Invoke-Test
            Invoke-Benchmark
        }
    }
}
finally {
    Pop-Location
}
