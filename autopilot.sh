#!/usr/bin/env bash
set -euo pipefail

workie autopilot \
  phase-01-scaffold-config \
  phase-02-actions \
  phase-03-react-integration \
  phase-04-agent-definition \
  phase-05-cli-channel \
  phase-06-memory-persistence \
  phase-07-prompt-skills \
  phase-08-telegram-channel \
  phase-09-web-subagents \
  phase-10-cron-polish \
  --show-output \
  --auto-approve
