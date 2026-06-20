"""
sftpuser0 (push) SFTP permission tests.

Home:        landing/dev01/inbound/sterling
Permissions: Create, Write on landing container (no Read, List, Delete)
             + ACL authorization enabled; read/list access in sterling via POSIX ACL other:r-x

Note: push user is the POSIX owning user of directories/files they create.
The default ACL (user:rwx) propagates write permission to owned dirs, so they
can also delete files from directories they own — POSIX does not separate
"create here" from "delete here".
"""
import io
from conftest import assert_sftp_denied


# ── ALLOW: list and navigate down ────────────────────────────────────────────

def test_list_home_dir(sftp_push_client):
    entries = sftp_push_client.listdir(".")
    assert isinstance(entries, list)


def test_list_scratch_dir(sftp_push_client, sftp_push_artifacts):
    entries = sftp_push_client.listdir(sftp_push_artifacts["scratch_dir"])
    assert isinstance(entries, list)


def test_create_subdir_and_traverse(sftp_push_client, sftp_push_artifacts):
    path = f"{sftp_push_artifacts['scratch_dir']}/push-nested"
    sftp_push_client.mkdir(path)
    entries = sftp_push_client.listdir(path)
    assert isinstance(entries, list)


# ── ALLOW: read ──────────────────────────────────────────────────────────────

def test_read_seed_file(sftp_push_client, sftp_push_artifacts):
    buf = io.BytesIO()
    sftp_push_client.getfo(sftp_push_artifacts["seed_file"], buf)
    assert buf.getvalue() == b"hello from sftp push"


# ── ALLOW: write ─────────────────────────────────────────────────────────────

def test_upload_file(sftp_push_client, sftp_push_artifacts):
    path = f"{sftp_push_artifacts['scratch_dir']}/push-upload.txt"
    sftp_push_client.putfo(io.BytesIO(b"push data"), path)
    buf = io.BytesIO()
    sftp_push_client.getfo(path, buf)
    assert buf.getvalue() == b"push data"


def test_create_subdir(sftp_push_client, sftp_push_artifacts):
    path = f"{sftp_push_artifacts['scratch_dir']}/push-subdir"
    sftp_push_client.mkdir(path)
    assert sftp_push_client.stat(path) is not None


# ── DENY: navigate up ────────────────────────────────────────────────────────

def test_cannot_navigate_up(sftp_push_client):
    # No Read container permission → stat("..")  falls back to ACL (other:--x has no r) → denied
    assert_sftp_denied(lambda: sftp_push_client.chdir(".."))


# ── ALLOW: delete own files ───────────────────────────────────────────────────

def test_can_delete_own_file(sftp_push_client, sftp_push_artifacts):
    # POSIX owning user inherits write on dirs they create → can delete from those dirs
    path = f"{sftp_push_artifacts['scratch_dir']}/push-delete-test.txt"
    sftp_push_client.putfo(io.BytesIO(b"delete me"), path)
    sftp_push_client.remove(path)


# ── DENY: delete dir ─────────────────────────────────────────────────────────

def test_cannot_delete_dir(sftp_push_client, sftp_push_artifacts):
    assert_sftp_denied(lambda: sftp_push_client.rmdir(sftp_push_artifacts["scratch_dir"]))
