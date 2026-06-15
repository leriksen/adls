#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPORT="$SCRIPT_DIR/report.md"

bash "$SCRIPT_DIR/run_posix_tests.sh" &
POSIX_PID=$!

bash "$SCRIPT_DIR/run_sftp_tests.sh" &
SFTP_PID=$!

POSIX_EXIT=0; wait "$POSIX_PID" || POSIX_EXIT=$?
SFTP_EXIT=0;  wait "$SFTP_PID"  || SFTP_EXIT=$?

# Merge reports
{
  echo "## POSIX ACL tests"
  echo ""
  cat "$SCRIPT_DIR/report_posix.md"
  echo ""
  echo "## SFTP tests"
  echo ""
  cat "$SCRIPT_DIR/report_sftp.md"
} > "$REPORT"

echo ""
echo "=== Combined report ==="
cat "$REPORT"

if [[ $POSIX_EXIT -ne 0 || $SFTP_EXIT -ne 0 ]]; then
  echo "POSIX tests exit: $POSIX_EXIT  SFTP tests exit: $SFTP_EXIT" >&2
  exit 1
fi
