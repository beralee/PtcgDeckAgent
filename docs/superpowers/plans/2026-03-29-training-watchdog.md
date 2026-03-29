# Training Watchdog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local watchdog that monitors the active smoke and overnight training jobs, writes hourly status logs, and automatically restarts the overnight job if it exits or stalls.

**Architecture:** Build a small PowerShell watchdog around the existing `scripts/training/train_loop.sh` entrypoint. Keep the decision logic in testable helper functions, then use a long-running polling loop to inspect matching processes, CPU deltas, file activity, and restart policy.

**Tech Stack:** Windows PowerShell 5, Git Bash, existing `train_loop.sh` pipeline, repo-local log/state files.

---

### Task 1: Add Script-Level Tests

**Files:**
- Create: `scripts/training/test_training_watchdog.ps1`
- Create later: `scripts/training/training_watchdog.ps1`

- [ ] Step 1: Write a failing PowerShell test script that dot-sources the watchdog script and validates:
  - running jobs stay healthy when CPU or file activity advances
  - restartable jobs become `missing` when no process exists
  - non-restartable jobs become `completed` when no process exists
  - stale jobs become `stalled`
  - restart command arguments are assembled correctly

- [ ] Step 2: Run the test script and confirm it fails because the watchdog script does not exist yet.

### Task 2: Implement Watchdog Script

**Files:**
- Create: `scripts/training/training_watchdog.ps1`

- [ ] Step 1: Add helper functions for:
  - building `train_loop.sh` argument lists
  - evaluating job health from process count, CPU delta, file activity, and restart policy
  - reading latest file activity from watched paths
  - logging JSONL and human-readable status lines

- [ ] Step 2: Add the main polling loop with:
  - configurable smoke and overnight job definitions
  - 5-minute polling
  - hourly summary logging
  - overnight auto-restart on `missing` or `stalled`
  - smoke monitoring only

- [ ] Step 3: Persist lightweight state for last healthy timestamp, restart count, and last observed CPU total.

### Task 3: Verify and Launch

**Files:**
- Modify: `scripts/training/training_watchdog.ps1`

- [ ] Step 1: Re-run the PowerShell test script and confirm it passes.
- [ ] Step 2: Start the watchdog as a detached PowerShell process against the current `smoke_20260329` and `overnight_20260329` jobs.
- [ ] Step 3: Verify the watchdog creates a log file and a state file, and records the live jobs without restarting them unnecessarily.
