#!/usr/bin/env bash
set -euo pipefail

# Fast-forward all OpenSpec proposals through artifact generation
# Runs claude with /opsx:ff on each change directory in sequence

CHANGES_DIR="openspec/changes"

for change_dir in "$CHANGES_DIR"/*/; do
  change_name=$(basename "$change_dir")

  # Skip if no proposal.md exists
  if [[ ! -f "$change_dir/proposal.md" ]]; then
    echo "⏭  Skipping $change_name (no proposal.md)"
    continue
  fi

  echo "🚀 Fast-forwarding: $change_name"
  claude --dangerously-skip-permissions -p "/opsx:ff $change_name"
  echo "✅ Done: $change_name"
  echo ""
done

echo "🏁 All proposals fast-forwarded."
