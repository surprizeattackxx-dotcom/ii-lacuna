#!/bin/bash
# Claude Desktop's scheduled-task runner (e.g. handoff-poller) spawns a
# `claude` CLI child per firing and never terminates it -- the process
# just blocks forever on stdin instead of exiting when the run finishes.
# They pile up hour after hour (found 51 idle ones eating ~9GB and pegging
# swap on 2026-08-18). Scheduled/background runs are distinguishable from
# real interactive Desktop chat tabs by the --disallowedTools AskUserQuestion
# flag Desktop passes them; a normal run finishes in well under a minute,
# so anything still alive past MAX_AGE_MIN is a leaked one, not a live task.
set -euo pipefail

MAX_AGE_MIN=15
MAX_AGE_SEC=$((MAX_AGE_MIN * 60))

ps -eo pid,etimes,args | grep -- '--disallowedTools AskUserQuestion' | grep -v grep | while read -r pid etimes _; do
    if [ "$etimes" -gt "$MAX_AGE_SEC" ]; then
        kill "$pid" 2>/dev/null && logger -t claude-scheduled-reaper "killed leaked scheduled-task process $pid (age ${etimes}s)"
    fi
done
