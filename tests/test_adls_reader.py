"""
adls-test-sp-reader permission tests.

Runs after test_adls_writer.py — writer_artifacts must already exist.

ACLs:
  landing/                       r-x (access + default)
  landing/dev01/                 r-x (access only)
  landing/dev01/inbound/         r-x (access + default)
  landing/dev01/inbound/sterling r-x (access + default, inherited)
"""
import pytest
from conftest import assert_denied


# ── ALLOW: descend into hierarchy and see writer artifacts ───────────────────

def test_list_landing_root(reader_client, writer_artifacts):
    paths = list(reader_client.get_file_system_client("landing").get_paths(path=""))
    assert isinstance(paths, list)


def test_list_dev01(reader_client, writer_artifacts):
    paths = list(reader_client.get_file_system_client("landing").get_paths(path="dev01"))
    assert isinstance(paths, list)


def test_list_inbound(reader_client, writer_artifacts):
    paths = list(reader_client.get_file_system_client("landing").get_paths(path="dev01/inbound"))
    assert isinstance(paths, list)


def test_list_sterling(reader_client, writer_artifacts):
    paths = list(reader_client.get_file_system_client("landing").get_paths(path="dev01/inbound/sterling"))
    assert isinstance(paths, list)


def test_can_see_scratch_dir(reader_client, writer_artifacts):
    scratch_name = writer_artifacts["scratch_dir"].split("/")[-1]
    paths = [p.name for p in reader_client.get_file_system_client("landing").get_paths(path="dev01/inbound/sterling")]
    assert any(scratch_name in p for p in paths)


def test_can_list_scratch_dir(reader_client, writer_artifacts):
    paths = list(reader_client.get_file_system_client("landing").get_paths(path=writer_artifacts["scratch_dir"]))
    assert isinstance(paths, list)


def test_can_read_seed_file(reader_client, writer_artifacts):
    fc = reader_client.get_file_system_client("landing").get_file_client(writer_artifacts["seed_file"])
    assert fc.download_file().readall() == b"hello from writer"


# ── DENY: any write ──────────────────────────────────────────────────────────

def test_cannot_create_file_in_sterling(reader_client, writer_artifacts):
    fs = reader_client.get_file_system_client("landing")
    assert_denied(lambda: fs.get_file_client(
        f"{writer_artifacts['scratch_dir']}/reader-denied.txt"
    ).upload_data(b"x", overwrite=True))


def test_cannot_delete_seed_file(reader_client, writer_artifacts):
    fc = reader_client.get_file_system_client("landing").get_file_client(writer_artifacts["seed_file"])
    assert_denied(fc.delete_file)


def test_cannot_create_dir_in_sterling(reader_client, writer_artifacts):
    fs = reader_client.get_file_system_client("landing")
    assert_denied(lambda: fs.get_directory_client(
        f"{writer_artifacts['scratch_dir']}/reader-denied-dir"
    ).create_directory())


# ── DENY: other containers ───────────────────────────────────────────────────

@pytest.mark.parametrize("container", ["reference", "staging", "deadletter"])
def test_cannot_list_other_containers(reader_client, writer_artifacts, container):
    assert_denied(lambda: list(reader_client.get_file_system_client(container).get_paths(path="")))