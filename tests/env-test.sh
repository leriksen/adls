# Source env-dev.sh first so ARM_CLIENT_ID / ARM_CLIENT_SECRET are available
# for the admin fixture (Terraform SP has Storage Blob Data Owner).
#
#   source terraform/env-dev.sh
#   source tests/env-test.sh
#   pytest tests/

_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPO_ROOT="$(cd "${_TESTS_DIR}/.." && pwd)"

export AZURE_TENANT_ID="$(cat "${_REPO_ROOT}/terraform/.tenant_id")"

export ADLS_WRITER_CLIENT_ID="$(cat "${_TESTS_DIR}/.adls_writer_client_id")"
export ADLS_WRITER_CLIENT_SECRET="$(cat "${_TESTS_DIR}/.adls_writer_client_secret")"

export ADLS_READER_CLIENT_ID="$(cat "${_TESTS_DIR}/.adls_reader_client_id")"
export ADLS_READER_CLIENT_SECRET="$(cat "${_TESTS_DIR}/.adls_reader_client_secret")"

export ADLS_STORAGE_ACCOUNT="adlsargdl01"

export SFTP_PUSH_KEY_FILE="${_REPO_ROOT}/terraform/.sftp_push_key"
export SFTP_PULL_KEY_FILE="${_REPO_ROOT}/terraform/.sftp_pull_key"
