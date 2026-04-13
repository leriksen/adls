/**
 * consumer.js — polls all storage queues for BlobCreated events,
 * pauses ~2s, then deletes the blob. Runs at ~12/min average.
 *
 * Auth: source terraform/env-dev.sh first (sets ARM_* env vars).
 * Ctrl+C to stop.
 */

const { QueueServiceClient } = require("@azure/storage-queue");
const { BlobServiceClient }  = require("@azure/storage-blob");
const { ClientSecretCredential } = require("@azure/identity");

// One entry per storage account — must match terraform/variables.tf defaults
const QUEUES = [
  { account: "argdl01", queue: "raw-events"     },
  { account: "argdl02", queue: "curated-events" },
];

const credential = new ClientSecretCredential(
  process.env.ARM_TENANT_ID,
  process.env.ARM_CLIENT_ID,
  process.env.ARM_CLIENT_SECRET
);

// Cache clients per account
const queueClients = {};
const blobClients  = {};

function queueClient(account, queueName) {
  const key = `${account}:${queueName}`;
  if (!queueClients[key]) {
    queueClients[key] = new QueueServiceClient(
      `https://${account}.queue.core.windows.net`,
      credential
    ).getQueueClient(queueName);
  }
  return queueClients[key];
}

function blobClient(account) {
  if (!blobClients[account]) {
    blobClients[account] = new BlobServiceClient(
      `https://${account}.blob.core.windows.net`,
      credential
    );
  }
  return blobClients[account];
}

// Parse account, container, and blob path from a blob URL
function parseBlobUrl(url) {
  const u       = new URL(url);
  const account = u.hostname.split(".")[0];
  const parts   = u.pathname.split("/").filter(Boolean);
  return { account, container: parts[0], blobPath: parts.slice(1).join("/") };
}

// ~12/min average: 5 000ms average cycle, minus ~2 000ms delete delay → 3 000ms sleep
// ±33% jitter → 2 000–4 000ms sleep
function nextInterval() {
  return 2_000 + Math.random() * 2_000;
}

// ~2s pause between receiving queue entry and deleting the blob
function deleteDelay() {
  return 1_500 + Math.random() * 1_000;
}

// Pick a random queue entry to check each cycle
function pickQueue() {
  return QUEUES[Math.floor(Math.random() * QUEUES.length)];
}

async function processMessage(entry, message) {
  let events;
  try {
    const decoded = Buffer.from(message.messageText, "base64").toString("utf8");
    events = JSON.parse(decoded);
  } catch {
    // unparseable — ack and move on
    await queueClient(entry.account, entry.queue)
      .deleteMessage(message.messageId, message.popReceipt);
    return;
  }

  const eventArray = Array.isArray(events) ? events : [events];

  for (const event of eventArray) {
    if (event.eventType !== "Microsoft.Storage.BlobCreated") continue;

    const { account, container, blobPath } = parseBlobUrl(event.data.url);

    console.log(`[CONSUME] ${account}/${container}/${blobPath}`);

    await new Promise((r) => setTimeout(r, deleteDelay()));

    try {
      await blobClient(account)
        .getContainerClient(container)
        .getBlobClient(blobPath)
        .delete();
    } catch (err) {
      if (err.statusCode !== 404) {
        console.error(`[CONSUME] ERROR deleting ${blobPath}: ${err.message}`);
      }
    }
  }

  await queueClient(entry.account, entry.queue)
    .deleteMessage(message.messageId, message.popReceipt);
}

async function main() {
  await credential.getToken("https://storage.azure.com/.default");

  while (true) {
    const entry = pickQueue();
    const client = queueClient(entry.account, entry.queue);

    try {
      const response = await client.receiveMessages({
        numberOfMessages: 1,
        visibilityTimeout: 60,
      });

      if (response.receivedMessageItems.length > 0) {
        await processMessage(entry, response.receivedMessageItems[0]);
      }
    } catch (err) {
      console.error(`[CONSUME] ERROR on ${entry.queue}: ${err.message}`);
    }

    await new Promise((r) => setTimeout(r, nextInterval()));
  }
}

main().catch((err) => {
  console.error(`[CONSUMER] fatal: ${err.message}`);
  process.exit(1);
});
