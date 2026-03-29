$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'parallel_training_launcher.ps1'
. $scriptPath

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

$workspaceRoot = Join-Path $env:TEMP 'ptcg_parallel_launcher_test'
if (Test-Path $workspaceRoot) {
	Remove-Item -LiteralPath $workspaceRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $workspaceRoot | Out-Null

$approvedBaseline = @{
	version_id = 'AI-20260329-01'
	display_name = 'approved best'
	agent_config_path = 'user://ai_agents/approved.json'
	value_net_path = 'user://ai_models/approved.json'
}

$plan = New-ParallelTrainingPlan -WorkspaceRoot $workspaceRoot -ApprovedBaseline $approvedBaseline

Assert-Equal $plan.lanes.Count 20 'launcher should build 20 lane configs'

$groupCounts = @{}
$laneRoots = @{}
$dataRoots = @{}
$modelRoots = @{}
foreach ($lane in $plan.lanes) {
	if ($groupCounts.ContainsKey($lane.group)) {
		$groupCounts[$lane.group] = 1 + $groupCounts[$lane.group]
	} else {
		$groupCounts[$lane.group] = 1
	}
	$laneRoots[$lane.lane_root] = $true
	$dataRoots[$lane.data_root] = $true
	$modelRoots[$lane.model_root] = $true

	Assert-Equal $lane.baseline.version_id 'AI-20260329-01' 'every lane should reference the shared approved baseline snapshot'
	Assert-True (Test-Path $lane.lane_root) 'each lane root should be materialized'
	Assert-True (Test-Path $lane.data_root) 'each lane data root should be materialized'
	Assert-True (Test-Path $lane.model_root) 'each lane model root should be materialized'
}

Assert-Equal $groupCounts['conservative'] 5 'conservative group should get 5 lanes'
Assert-Equal $groupCounts['standard'] 5 'standard group should get 5 lanes'
Assert-Equal $groupCounts['aggressive'] 5 'aggressive group should get 5 lanes'
Assert-Equal $groupCounts['deep'] 5 'deep group should get 5 lanes'
Assert-Equal $laneRoots.Count 20 'lane roots should be unique per lane'
Assert-Equal $dataRoots.Count 20 'data roots should be unique per lane'
Assert-Equal $modelRoots.Count 20 'model roots should be unique per lane'

$recipeIds = @($plan.lanes | ForEach-Object { $_.recipe_id } | Sort-Object -Unique)
Assert-True ($recipeIds.Count -ge 4) 'launcher should assign heterogeneous recipes across the lane groups'

$planFile = Join-Path $workspaceRoot 'parallel_training_plan.json'
Export-ParallelTrainingPlan -Plan $plan -OutputPath $planFile
Assert-True (Test-Path $planFile) 'launcher should export a machine-readable plan file'

$planJson = Get-Content -Path $planFile -Raw | ConvertFrom-Json
Assert-Equal $planJson.lanes.Count 20 'exported JSON plan should contain every lane'
Assert-Equal $planJson.approved_baseline.version_id 'AI-20260329-01' 'exported JSON should preserve the approved baseline snapshot'

$resolvedGitBash = Resolve-GitBashPath
Assert-Equal $resolvedGitBash 'D:\Program Files\Git\bin\bash.exe' 'launcher should prefer the installed Git Bash over system bash.exe'

$godotPath = 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe'
$gitBashPath = 'D:/Program Files/Git/bin/bash.exe'
$firstLane = $plan.lanes[0]
$launchSpec = New-ParallelLaneLaunchSpec -Lane $firstLane -GodotPath $godotPath -GitBashPath $gitBashPath

Assert-Equal $launchSpec.lane_id $firstLane.lane_id 'launch spec should preserve lane id'
Assert-Equal $launchSpec.appdata_root $firstLane.appdata_root 'launch spec should preserve lane-local APPDATA root'
Assert-True (Test-Path $launchSpec.launch_script_path) 'launch spec should materialize a lane launch script'
Assert-True ($launchSpec.stdout_log -like '*.stdout.log') 'launch spec should define a stdout log'
Assert-True ($launchSpec.stderr_log -like '*.stderr.log') 'launch spec should define a stderr log'

$launchScriptText = Get-Content -Path $launchSpec.launch_script_path -Raw
Assert-True ($launchScriptText.Contains($firstLane.appdata_root)) 'lane launch script should pin APPDATA to the lane-local root'
Assert-True ($launchScriptText.Contains($godotPath)) 'lane launch script should embed the Godot executable path'
Assert-True ($launchScriptText.Contains($gitBashPath)) 'lane launch script should embed the Git Bash path'
Assert-True ($launchScriptText.Contains($firstLane.recipe_id)) 'lane launch script should pass the lane recipe id through to train_loop.sh'

$started = @()
$starter = {
	param($LaunchSpec)
	$script:started += $LaunchSpec
	return [pscustomobject]@{
		Id = 5000 + $script:started.Count
	}
}

$manifestPath = Start-ParallelTrainingPlan -Plan $plan -GodotPath $godotPath -GitBashPath $gitBashPath -StartProcessFn $starter
Assert-True (Test-Path $manifestPath) 'starting the plan should export a launch manifest'
Assert-Equal $started.Count 20 'starting the plan should attempt to launch every lane'

$manifestJson = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
Assert-Equal $manifestJson.processes.Count 20 'launch manifest should record every lane process'
Assert-Equal $manifestJson.processes[0].pid 5001 'launch manifest should record returned process ids'
Assert-Equal $manifestJson.processes[0].lane_id 'lane_01' 'launch manifest should record lane ids'
Assert-Equal $manifestJson.processes[0].appdata_root $plan.lanes[0].appdata_root 'launch manifest should record lane-local APPDATA roots'

Write-Output 'parallel_training_launcher tests passed'
