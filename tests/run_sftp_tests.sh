#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$REPO_ROOT/tests/.venv"

pushd "$REPO_ROOT/terraform" > /dev/null
source ./env-dev.sh
terraform output -raw sftp_push_private_key > "$REPO_ROOT/tests/sftp_push.pem"
terraform output -raw sftp_pull_private_key  > "$REPO_ROOT/tests/sftp_pull.pem"
chmod 600 "$REPO_ROOT/tests/sftp_push.pem" "$REPO_ROOT/tests/sftp_pull.pem"
popd > /dev/null
source "$REPO_ROOT/tests/env-test.sh"

if [[ ! -d "$VENV" ]]; then
  python3 -m venv "$VENV"
fi

source "$VENV/bin/activate"
pip install -q -r "$REPO_ROOT/tests/requirements.txt"

REPORT="$REPO_ROOT/tests/report_sftp.md"

trap 'rm -f "$REPO_ROOT/tests/sftp_push.pem" "$REPO_ROOT/tests/sftp_pull.pem"' EXIT

pytest "$REPO_ROOT/tests/test_sftp_push.py" "$REPO_ROOT/tests/test_sftp_pull.py" -v \
  --md-report \
  --md-report-output="$REPORT" \
  --md-report-verbose=1

cat "$REPORT"
