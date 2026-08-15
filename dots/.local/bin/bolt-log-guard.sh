#!/usr/bin/env bash
# Stopgap for the VERBOSE libbolt-plugin.so build currently installed at
# /usr/lib/libbolt-plugin.so, which logs every hooked GL call per frame. Bolt pipes
# the RS3 client's stdout into /tmp/bolt_verbose.log, measured at ~400 MB/min, which
# fills the 32G /tmp tmpfs in roughly 78 minutes and takes the whole machine down
# with ENOSPC (happened 2026-08-11 twice: ~08:00 and ~13:31).
#
# THIS IS NOT THE FIX. The fix is restoring the stock library:
#     sudo cp /usr/lib/libbolt-plugin.so.bak /usr/lib/libbolt-plugin.so
# which needs Bolt closed and root. Until that happens, this keeps the box alive.
#
# Truncates rather than deletes: the client holds the fd open, so rm frees nothing
# until it exits. Exits on its own once no rs2client is running.
#
# Measures ALLOCATED BLOCKS (stat %b * 512), not logical size (stat %s). Truncating does
# not reset the writer's file offset, so the log immediately reappears as a SPARSE file
# whose logical size keeps climbing (observed at 40G while /tmp held only 460M). Checking
# %s would therefore fire on every single pass forever and flood the journal; %b is the
# number that actually reflects tmpfs pages consumed.

# Runs FOREVER rather than exiting when rs2client does. The earlier version tied its
# lifetime to the client, which meant every new RS3 launch started unprotected -- that is
# exactly how the 13:31 recurrence on 2026-08-11 happened, and it happened AGAIN on the
# 14:4x launch (guard gone, client up 5h47m with no protection). Cheap enough to just
# always run: one stat() every 45s.

LOG=/tmp/bolt_verbose.log
MAX_BYTES=$((200 * 1024 * 1024))   # let it reach 200MB of REAL usage, then zero it
INTERVAL=45

logger -t bolt-log-guard "guard started (threshold $((MAX_BYTES / 1024 / 1024))MB, interval ${INTERVAL}s)"

while true; do
    if [ -f "$LOG" ]; then
        blocks=$(stat -c %b "$LOG" 2>/dev/null || echo 0)
        size=$((blocks * 512))
        if [ "$size" -gt "$MAX_BYTES" ]; then
            truncate -s 0 "$LOG" 2>/dev/null
            logger -t bolt-log-guard "truncated $LOG at $((size / 1024 / 1024))MB"
        fi
    fi
    sleep "$INTERVAL"
done
