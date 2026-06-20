"""
sftpuser1 (pull) SFTP permission tests.

Home:        landing/dev01/inbound/sterling
Permissions: (none) on landing container + ACL authorization enabled
             Read/list access in sterling via POSIX ACL other:r-x only

Runs after test_sftp_push.py — sftp_push_artifacts must already exist.
"""
import io
from conftest import assert_sftp_denied


# ── ALLOW: list and navigate down ────────────────────────────────────────────

def test_list_home_dir(sftp_pull_client, sftp_push_artifacts):
    entries = sftp_pull_client.listdir(".")
    assert isinstance(entries, list)


def test_can_see_scratch_dir(sftp_pull_client, sftp_push_artifacts):
    entries = sftp_pull_client.listdir(".")
    scratch_name = sftp_push_artifacts["scratch_dir"].split("/")[-1]
    assert scratch_name in entries


def test_can_list_scratch_dir(sftp_pull_client, sftp_push_artifacts):
    entries = sftp_pull_client.listdir(sftp_push_artifacts["scratch_dir"])
    assert "seed.txt" in entries


def test_can_download_seed_file(sftp_pull_client, sftp_push_artifacts):
    buf = io.BytesIO()
    sftp_pull_client.getfo(sftp_push_artifacts["seed_file"], buf)
    assert buf.getvalue() == b"hello from sftp push"


# ── DENY: navigate up ────────────────────────────────────────────────────────

def test_cannot_navigate_up(sftp_pull_client):
    # chdir(..) is permitted by execute-only ACL on parent; listing is denied
    sftp_pull_client.chdir("..")
    assert_sftp_denied(lambda: sftp_pull_client.listdir("."))
    sftp_pull_client.chdir("sterling")


# ── DENY: write ──────────────────────────────────────────────────────────────

def test_cannot_upload_file(sftp_pull_client, sftp_push_artifacts):
    path = f"{sftp_push_artifacts['scratch_dir']}/pull-denied.txt"
    assert_sftp_denied(lambda: sftp_pull_client.putfo(io.BytesIO(b"x"), path))


def test_cannot_create_dir(sftp_pull_client, sftp_push_artifacts):
    path = f"{sftp_push_artifacts['scratch_dir']}/pull-denied-dir"
    assert_sftp_denied(lambda: sftp_pull_client.mkdir(path))


# ── DENY: delete ─────────────────────────────────────────────────────────────

def test_cannot_delete_file(sftp_pull_client, sftp_push_artifacts):
    assert_sftp_denied(lambda: sftp_pull_client.remove(sftp_push_artifacts["seed_file"]))