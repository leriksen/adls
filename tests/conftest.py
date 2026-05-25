import os
import uuid
import pytest
from azure.core.exceptions import HttpResponseError
from azure.identity import ClientSecretCredential
from azure.storage.filedatalake import DataLakeServiceClient

TENANT_ID       = os.environ["AZURE_TENANT_ID"]
STORAGE_ACCOUNT = os.environ.get("ADLS_STORAGE_ACCOUNT", "adlsargdl01")
ACCOUNT_URL     = f"https://{STORAGE_ACCOUNT}.dfs.core.windows.net"


def _client(client_id, client_secret):
    cred = ClientSecretCredential(
        tenant_id=TENANT_ID,
        client_id=client_id,
        client_secret=client_secret,
    )
    return DataLakeServiceClient(account_url=ACCOUNT_URL, credential=cred)


@pytest.fixture(scope="session")
def writer_client():
    return _client(
        os.environ["ADLS_WRITER_CLIENT_ID"],
        os.environ["ADLS_WRITER_CLIENT_SECRET"],
    )


@pytest.fixture(scope="session")
def reader_client():
    return _client(
        os.environ["ADLS_READER_CLIENT_ID"],
        os.environ["ADLS_READER_CLIENT_SECRET"],
    )


@pytest.fixture(scope="session")
def admin_client():
    return _client(
        os.environ["ARM_CLIENT_ID"],
        os.environ["ARM_CLIENT_SECRET"],
    )


@pytest.fixture(scope="session")
def writer_artifacts(writer_client, admin_client):
    """Writer creates the scratch dir and seed file; admin cleans up regardless of outcome."""
    run_id = uuid.uuid4().hex[:8]
    scratch = f"dev01/inbound/test-scratch-{run_id}"
    seed    = f"{scratch}/seed.txt"

    landing_writer = writer_client.get_file_system_client("landing")
    landing_admin  = admin_client.get_file_system_client("landing")

    landing_writer.get_directory_client(scratch).create_directory()
    landing_writer.get_file_client(seed).upload_data(b"hello from writer", overwrite=True)

    yield {"scratch_dir": scratch, "seed_file": seed}

    try:
        landing_admin.get_directory_client(scratch).delete_directory()
    except Exception:
        pass


def assert_denied(fn):
    with pytest.raises(HttpResponseError) as exc_info:
        fn()
    assert exc_info.value.status_code == 403, (
        f"Expected 403, got {exc_info.value.status_code}"
    )


def pytest_collection_modifyitems(items):
    def sort_key(item):
        if "test_adls_writer" in item.nodeid:
            return 0
        if "test_adls_reader" in item.nodeid:
            return 1
        return 2
    items.sort(key=sort_key)
