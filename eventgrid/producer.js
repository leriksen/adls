/**
 * producer.js — continuously uploads files to staging/raw/eg-demo/ in ADLS Gen2.
 *
 * Runs slightly faster than the consumer so the queue gradually fills up,
 * illustrating back-pressure. Ctrl+C to stop.
 *
 * Auth: source terraform/env-dev.sh first (sets ARM_* env vars).
 */

const { BlobServiceClient } = require("@azure/storage-blob");
const { ClientSecretCredential } = require("@azure/identity");

const ACCOUNT_NAME = "leifadls";
const CONTAINER    = "staging";
const BLOB_PREFIX  = "raw/eg-demo";
const PRODUCE_INTERVAL_MS = 3_000; // upload every 3s

const credential = new ClientSecretCredential(
  process.env.ARM_TENANT_ID,
  process.env.ARM_CLIENT_ID,
  process.env.ARM_CLIENT_SECRET
);

const blobServiceClient = new BlobServiceClient(
  `https://${ACCOUNT_NAME}.blob.core.windows.net`,
  credential
);

function ts() {
  return new Date().toISOString();
}

function log(msg) {
  console.log(`[${ts()}] [PRODUCER] ${msg}`);
}

async function uploadOne(seq) {
  const blobName = `${BLOB_PREFIX}/event-${Date.now()}.txt`;
  const content  = `seq=${seq}\nproduced=${ts()}\naccount=${ACCOUNT_NAME}\ncontainer=${CONTAINER}\n`;
  const bytes    = Buffer.byteLength(content);

  log(`--- upload #${seq} ---`);
  log(`target  : ${ACCOUNT_NAME} / ${CONTAINER} / ${blobName}`);
  log(`content : ${bytes} bytes`);
  log(`sending upload request...`);

  const t0 = Date.now();
  await blobServiceClient
    .getContainerClient(CONTAINER)
    .getBlockBlobClient(blobName)
    .upload(content, bytes, { blobHTTPHeaders: { blobContentType: "text/plain" } });
  const elapsed = Date.now() - t0;

  log(`upload complete in ${elapsed}ms`);
  log(`Event Grid will fire BlobCreated — expect it in testqueue within ~10s`);
  log(`next upload in ${PRODUCE_INTERVAL_MS / 1000}s  (consumer is slower — watch the queue grow)`);
  console.log();
}

async function main() {
  log("=== PRODUCER STARTING ===");
  log(`account  : ${ACCOUNT_NAME}`);
  log(`container: ${CONTAINER}`);
  log(`prefix   : ${BLOB_PREFIX}`);
  log(`interval : ${PRODUCE_INTERVAL_MS}ms`);
  log("authenticating with service principal...");

  // Trigger a token fetch early so the first upload doesn't pay the auth latency.
  await credential.getToken("https://storage.azure.com/.default");
  log("token acquired — starting loop");
  console.log();

  let seq = 1;
  // noinspection InfiniteLoopJS
  while (true) {
    try {
      await uploadOne(seq++);
    } catch (err) {
      log(`ERROR on upload #${seq - 1}: ${err.message}`);
    }
    await new Promise((r) => setTimeout(r, PRODUCE_INTERVAL_MS));
  }
}

main().catch((err) => {
  console.error(`[PRODUCER] fatal: ${err.message}`);
  process.exit(1);
});
