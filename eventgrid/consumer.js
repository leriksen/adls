/**
 * consumer.js — polls testqueue for BlobCreated events from Event Grid,
 * waits a few seconds, then deletes the blob.
 *
 * Intentionally slower than the producer so the queue builds up over time.
 * Ctrl+C to stop.
 *
 * Auth: source terraform/env-dev.sh first (sets ARM_* env vars).
 *
 * Event Grid → Storage Queue delivery notes:
 *   - The queue message body is a JSON array of Event Grid events.
 *   - Each event has eventType, subject, eventTime, id, data { url, api, ... }.
 *   - visibilityTimeout hides the message from other consumers while we process it;
 *     if we crash it reappears automatically.
 */

const { QueueServiceClient } = require("@azure/storage-queue");
const { BlobServiceClient }  = require("@azure/storage-blob");
const { ClientSecretCredential } = require("@azure/identity");

const ACCOUNT_NAME     = "leifadls";
const QUEUE_NAME       = "testqueue";
const POLL_INTERVAL_MS = 5_000; // poll every 5s — slower than the 3s producer
const DELETE_DELAY_MS  = 3_000; // pause before deleting so you can watch in portal

const credential = new ClientSecretCredential(
  process.env.ARM_TENANT_ID,
  process.env.ARM_CLIENT_ID,
  process.env.ARM_CLIENT_SECRET
);

const queueServiceClient = new QueueServiceClient(
  `https://${ACCOUNT_NAME}.queue.core.windows.net`,
  credential
);
const blobServiceClient = new BlobServiceClient(
  `https://${ACCOUNT_NAME}.blob.core.windows.net`,
  credential
);
const queueClient = queueServiceClient.getQueueClient(QUEUE_NAME);

// Running totals
const stats = { polls: 0, messagesReceived: 0, eventsHandled: 0, blobsDeleted: 0, errors: 0 };

function ts() {
  return new Date().toISOString();
}

function log(msg) {
  console.log(`[${ts()}] [CONSUMER] ${msg}`);
}

function parseBlobUrl(blobUrl) {
  const url   = new URL(blobUrl);
  const parts = url.pathname.split("/").filter(Boolean);
  return { container: parts[0], blobPath: parts.slice(1).join("/") };
}

async function handleEvent(event, eventIndex) {
  log(`  event[${eventIndex}] type     : ${event.eventType}`);
  log(`  event[${eventIndex}] id       : ${event.id}`);
  log(`  event[${eventIndex}] time     : ${event.eventTime}`);
  log(`  event[${eventIndex}] subject  : ${event.subject}`);

  if (event.eventType !== "Microsoft.Storage.BlobCreated") {
    log(`  event[${eventIndex}] -- skipping, not a BlobCreated event`);
    return;
  }

  const { container, blobPath } = parseBlobUrl(event.data.url);

  log(`  event[${eventIndex}] api      : ${event.data.api}`);
  log(`  event[${eventIndex}] url      : ${event.data.url}`);
  log(`  event[${eventIndex}] size     : ${event.data.contentLength ?? "unknown"} bytes`);
  log(`  event[${eventIndex}] parsed   : container="${container}"  blob="${blobPath}"`);
  log(`  event[${eventIndex}] waiting ${DELETE_DELAY_MS / 1000}s before deleting (blob is live in Azure right now)...`);

  await new Promise((r) => setTimeout(r, DELETE_DELAY_MS));

  log(`  event[${eventIndex}] sending delete request for "${blobPath}"...`);
  const t0 = Date.now();
  await blobServiceClient
    .getContainerClient(container)
    .getBlobClient(blobPath)
    .delete();
  log(`  event[${eventIndex}] DELETED in ${Date.now() - t0}ms — blob is gone`);

  stats.eventsHandled++;
  stats.blobsDeleted++;
}

async function processMessage(message, msgIndex) {
  log(`  msg[${msgIndex}] id             : ${message.messageId}`);
  log(`  msg[${msgIndex}] insertedOn     : ${message.insertedOn}`);
  log(`  msg[${msgIndex}] expiresOn      : ${message.expiresOn}`);
  log(`  msg[${msgIndex}] dequeueCount   : ${message.dequeueCount}`);
  log(`  msg[${msgIndex}] decoding body...`);

  let events;
  try {
    const decoded = Buffer.from(message.messageText, "base64").toString("utf8");
    log(`  msg[${msgIndex}] decoded  : ${decoded.slice(0, 120)}...`);
    events = JSON.parse(decoded);
  } catch (err) {
    log(`  msg[${msgIndex}] ERROR: could not parse as JSON — ${err.message}`);
    log(`  msg[${msgIndex}] raw text: ${message.messageText}`);
    stats.errors++;
    // Still ack it so it doesn't block the queue forever
    await queueClient.deleteMessage(message.messageId, message.popReceipt);
    return;
  }

  const eventArray = Array.isArray(events) ? events : [events];
  log(`  msg[${msgIndex}] contains ${eventArray.length} event(s)`);

  for (let i = 0; i < eventArray.length; i++) {
    try {
      await handleEvent(eventArray[i], i);
    } catch (err) {
      log(`  msg[${msgIndex}] event[${i}] ERROR: ${err.message}`);
      stats.errors++;
    }
  }

  log(`  msg[${msgIndex}] acknowledging (deleting from queue)...`);
  await queueClient.deleteMessage(message.messageId, message.popReceipt);
  log(`  msg[${msgIndex}] acknowledged — message removed from queue`);
  stats.messagesReceived++;
}

function printStats() {
  log(
    `stats — polls:${stats.polls}  msgs:${stats.messagesReceived}  ` +
    `events:${stats.eventsHandled}  deleted:${stats.blobsDeleted}  errors:${stats.errors}`
  );
}

async function poll() {
  log("=== CONSUMER STARTING ===");
  log(`account : ${ACCOUNT_NAME}`);
  log(`queue   : ${QUEUE_NAME}`);
  log(`poll    : every ${POLL_INTERVAL_MS}ms`);
  log(`delay   : ${DELETE_DELAY_MS}ms before each delete`);
  log("authenticating with service principal...");

  await credential.getToken("https://storage.azure.com/.default");
  log("token acquired — starting poll loop");
  console.log();

  // noinspection InfiniteLoopJS
  while (true) {
    stats.polls++;
    log(`=== POLL #${stats.polls} ===`);
    log(`checking queue "${QUEUE_NAME}"...`);

    let response;
    try {
      response = await queueClient.receiveMessages({
        numberOfMessages: 5,
        visibilityTimeout: 60, // hide from other consumers for 60s while we process
      });
    } catch (err) {
      log(`ERROR receiving messages: ${err.message}`);
      stats.errors++;
      await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
      continue;
    }

    const count = response.receivedMessageItems.length;
    if (count === 0) {
      log(`queue is empty — nothing to process`);
    } else {
      log(`received ${count} message(s) — processing...`);
      console.log();

      for (let i = 0; i < count; i++) {
        log(`--- processing message ${i + 1} of ${count} ---`);
        await processMessage(response.receivedMessageItems[i], i);
        console.log();
      }
    }

    printStats();
    log(`sleeping ${POLL_INTERVAL_MS / 1000}s until next poll`);
    console.log();

    await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
  }
}

poll().catch((err) => {
  console.error(`[CONSUMER] fatal: ${err.message}`);
  process.exit(1);
});