#!/bin/bash
# Pull Wasted's flight recorder off the device.
#
#   ./docs/pull-logs.sh              → the whole log
#   ./docs/pull-logs.sh error        → only failures
#   ./docs/pull-logs.sh island       → Live Activity: created / rotated / refused
#   ./docs/pull-logs.sh background   → did iOS actually grant our background runs?
#   ./docs/pull-logs.sh nudge        → which nudges fired, and which were suppressed
#
# Categories: app monitor island widget nudge receipt background trial onboarding error
#
# devicectl rejects some absolute destination paths ("File paths cannot contain
# '..'"), so this copies into a temp CWD with a RELATIVE destination — the one
# form that works reliably.
set -e

DEVICE="${WASTED_DEVICE:-9B8A2D59-C282-5C05-A501-51C47D3C724E}"
WORK="$(mktemp -d)"
cd "$WORK"

xcrun devicectl device copy from \
  --device "$DEVICE" \
  --domain-type appGroupDataContainer \
  --domain-identifier group.com.sanskar.Wasted \
  --source Library/Logs/wasted.log \
  --destination ./wasted.log > /dev/null

if [ -n "$1" ]; then
  grep -i "	$1	" wasted.log || echo "no '$1' entries"
else
  cat wasted.log
fi

echo
echo "--- $(wc -l < wasted.log | tr -d ' ') lines · $WORK/wasted.log ---"
