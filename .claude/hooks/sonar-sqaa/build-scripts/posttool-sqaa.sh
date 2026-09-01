#!/bin/bash
if ! command -v sonar &> /dev/null; then
  exit 0
fi

output=$(cat | sonar hook claude-post-tool-use --project Sonar-Gitar-Demos_Customer-Pulse 2>&1)

if command -v jq &> /dev/null && echo "$output" | jq -e '.hookSpecificOutput.additionalContext' &> /dev/null; then
  if echo "$output" | grep -qi "no issues found"; then
    emoji="✅"
  else
    emoji="❌"
  fi
  echo "$output" | jq --arg emoji "$emoji" '.hookSpecificOutput.additionalContext = ($emoji + "  " + .hookSpecificOutput.additionalContext)'
else
  echo "$output"
fi
