"""
sftpuser0 (push) SFTP permission tests.

Home:        landing/dev01/inbound
Permissions: Create, Write, Read, List, Delete on landing container
"""
import io
import pytest


# ── ALLOW: list and navigate ─────────────────────────────────────────────────

def test_list_home_dir(sftp_push_client):
    entries = sftp_push_client.listdir(".")
    assert isinstance(entries, list)


def test_list_scratch_dir(sftp_push_client, sftp_push_artifacts):
    entries = sftp_push_client.listdir(sftp_push_artifacts["scratch_dir"])
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
    sftp_push_client.remove(path)


def test_create_subdir(sftp_push_client, sftp_push_artifacts):
    path = f"{sftp_push_artifacts['scratch_dir']}/push-subdir"
    sftp_push_client.mkdir(path)
    sftp_push_client.rmdir(path)


# ── ALLOW: delete ────────────────────────────────────────────────────────────

def test_create_and_delete_file(sftp_push_client, sftp_push_artifacts):
    path = f"{sftp_push_artifacts['scratch_dir']}/push-delete.txt"
    sftp_push_client.putfo(io.BytesIO(b"temp"), path)
    sftp_push_client.remove(path)
    with pytest.raises(FileNotFoundError):
        sftp_push_client.stat(path)


def test_create_and_delete_subdir(sftp_push_client, sftp_push_artifacts):
    path = f"{sftp_push_artifacts['scratch_dir']}/push-delete-dir"
    sftp_push_client.mkdir(path)
    sftp_push_client.rmdir(path)
    with pytest.raises(FileNotFoundError):
        sftp_push_client.stat(path)
