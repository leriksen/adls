/**
 * producer.js — uploads files at ~15/min (with jitter) spread randomly
 * across all storage accounts, containers, and paths.
 *
 * Auth: source terraform/env-dev.sh first (sets ARM_* env vars).
 * Ctrl+C to stop.
 */

const { BlobServiceClient } = require("@azure/storage-blob");
const { ClientSecretCredential } = require("@azure/identity");

// Mirrors terraform/variables.tf storage defaults
const STORAGE = [
  {
    account: "argdl01",
    containers: [
      { name: "landing", paths: ["incoming", "processed", "failed", "quarantine"] },
    ],
  },
  {
    account: "argdl02",
    containers: [
      { name: "silver", paths: ["financial", "operational", "customer"] },
    ],
  },
];

// Flatten to all (account, container, path) triples
const TARGETS = STORAGE.flatMap((sa) =>
  sa.containers.flatMap((c) =>
    c.paths.map((p) => ({ account: sa.account, container: c.name, path: p }))
  )
);

const credential = new ClientSecretCredential(
  process.env.ARM_TENANT_ID,
  process.env.ARM_CLIENT_ID,
  process.env.ARM_CLIENT_SECRET
);

// Cache one BlobServiceClient per account
const blobClients = {};
function blobClient(account) {
  if (!blobClients[account]) {
    blobClients[account] = new BlobServiceClient(
      `https://${account}.blob.core.windows.net`,
      credential
    );
  }
  return blobClients[account];
}

// ~15/min average → 4 000ms average interval, ±40% jitter → 2 400–5 600ms
function nextInterval() {
  return 2_400 + Math.random() * 3_200;
}

function pick() {
  return TARGETS[Math.floor(Math.random() * TARGETS.length)];
}

async function uploadOne(seq) {
  const { account, container, path } = pick();
  const blobName = `${path}/event-${Date.now()}-${seq}.parquet`;
  const content  = `seq=${seq}\nts=${new Date().toISOString()}\n`;

  await blobClient(account)
    .getContainerClient(container)
    .getBlockBlobClient(blobName)
    .upload(content, Buffer.byteLength(content), {
      blobHTTPHeaders: { blobContentType: "text/plain" },
    });

  console.log(`[PRODUCE] ${account}/${container}/${blobName}`);
}

async function main() {
  await credential.getToken("https://storage.azure.com/.default");

  let seq = 1;
  while (true) {
    try {
      await uploadOne(seq++);
    } catch (err) {
      console.error(`[PRODUCE] ERROR: ${err.message}`);
    }
    await new Promise((r) => setTimeout(r, nextInterval()));
  }
}

main().catch((err) => {
  console.error(`[PRODUCER] fatal: ${err.message}`);
  process.exit(1);
});
