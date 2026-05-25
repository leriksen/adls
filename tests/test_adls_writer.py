"""
adls-test-sp-writer permission tests.

ACLs:
  landing/              r-x (access + default)
  landing/dev01/        r-x (access + default)
  landing/dev01/inbound rwx (access + default)
"""
import pytest
from conftest import assert_denied


# ── ALLOW: descend into hierarchy ───────────────────────────────────────────

def test_list_landing_root(writer_client, writer_artifacts):
    paths = list(writer_client.get_file_system_client("landing").get_paths(path=""))
    assert isinstance(paths, list)


def test_list_dev01(writer_client, writer_artifacts):
    paths = list(writer_client.get_file_system_client("landing").get_paths(path="dev01"))
    assert isinstance(paths, list)


def test_list_inbound(writer_client, writer_artifacts):
    paths = list(writer_client.get_file_system_client("landing").get_paths(path="dev01/inbound"))
    assert isinstance(paths, list)


# ── ALLOW: create / read / delete in inbound ────────────────────────────────

def test_read_seed_file(writer_client, writer_artifacts):
    fc = writer_client.get_file_system_client("landing").get_file_client(writer_artifacts["seed_file"])
    assert fc.download_file().readall() == b"hello from writer"


def test_create_and_delete_file(writer_client, writer_artifacts):
    fs = writer_client.get_file_system_client("landing")
    fc = fs.get_file_client(f"{writer_artifacts['scratch_dir']}/temp.txt")
    fc.upload_data(b"temp", overwrite=True)
    fc.delete_file()
    assert not fc.exists()


def test_create_subdir(writer_client, writer_artifacts):
    dc = writer_client.get_file_system_client("landing").get_directory_client(
        f"{writer_artifacts['scratch_dir']}/subdir"
    )
    dc.create_directory()
    assert dc.exists()


# ── DENY: write outside inbound ──────────────────────────────────────────────

def test_cannot_write_at_landing_root(writer_client, writer_artifacts):
    fs = writer_client.get_file_system_client("landing")
    assert_denied(lambda: fs.get_file_client("denied.txt").upload_data(b"x", overwrite=True))


def test_cannot_write_in_dev01(writer_client, writer_artifacts):
    fs = writer_client.get_file_system_client("landing")
    assert_denied(lambda: fs.get_file_client("dev01/denied.txt").upload_data(b"x", overwrite=True))


def test_cannot_create_dir_in_dev01(writer_client, writer_artifacts):
    fs = writer_client.get_file_system_client("landing")
    assert_denied(lambda: fs.get_directory_client("dev01/denied-dir").create_directory())


# ── DENY: other containers ───────────────────────────────────────────────────

@pytest.mark.parametrize("container", ["reference", "staging", "deadletter"])
def test_cannot_list_other_containers(writer_client, writer_artifacts, container):
    assert_denied(lambda: list(writer_client.get_file_system_client(container).get_paths(path="")))
