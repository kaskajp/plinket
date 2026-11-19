import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';
import { LinearRelay } from './linear.mjs';

const maxBodyBytes = 9 * 1024 * 1024;
const maxImageBytes = 2 * 1024 * 1024;
const rateWindow = 10 * 60 * 1000;
const maxClients = 10_000;
const maxConcurrent = 4;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

class RequestError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function text(value, maximum) {
  if (typeof value !== 'string' || !value.trim() || [...value.trim()].length > maximum) {
    throw new RequestError(400, 'Invalid report');
  }
  return value.trim();
}

export function validateReport(body) {
  if (!body || typeof body !== 'object' || !uuidPattern.test(body.id)) throw new RequestError(400, 'Invalid report ID');
  if (!Array.isArray(body.screenshots) || body.screenshots.length > 3) throw new RequestError(400, 'Too many screenshots');
  const screenshots = body.screenshots.map(encoded => {
    if (typeof encoded !== 'string' || encoded.length > Math.ceil(maxImageBytes / 3) * 4
        || encoded.length % 4 !== 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(encoded)) {
      throw new RequestError(400, 'Invalid screenshot');
    }
    const data = Buffer.from(encoded, 'base64');
    if (data.toString('base64') !== encoded || data.length < 4 || data.length > maxImageBytes || data[0] !== 0xff || data[1] !== 0xd8
        || data.at(-2) !== 0xff || data.at(-1) !== 0xd9) throw new RequestError(400, 'Expected a JPEG screenshot');
    return data;
  });
  const platform = text(body.platform, 20);
  if (!['iOS', 'macOS'].includes(platform)) throw new RequestError(400, 'Invalid platform');
  return {
    id: body.id.toLowerCase(), title: text(body.title, 200), details: text(body.details, 10_000),
    appVersion: text(body.appVersion, 100), platform,
    osVersion: text(body.osVersion, 200), locale: text(body.locale, 100), screenshots,
  };
}

async function readReport(request) {
  if (Number(request.headers['content-length']) > maxBodyBytes) throw new RequestError(413, 'Report too large');
  let size = 0;
  const chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    if (size > maxBodyBytes) throw new RequestError(413, 'Report too large');
    chunks.push(chunk);
  }
  try {
    return validateReport(JSON.parse(Buffer.concat(chunks).toString('utf8')));
  } catch (error) {
    if (error instanceof RequestError) throw error;
    throw new RequestError(400, 'Invalid JSON');
  }
}

export function createRelayServer({ relay, trustProxy = false, now = Date.now, logger = console }) {
  const clients = new Map();
  let active = 0;
  let globalWindow = { start: now(), count: 0 };
  function allow(ip) {
    const time = now();
    for (const [key, value] of clients) {
      if (time - value.start >= rateWindow) clients.delete(key);
    }
    if (time - globalWindow.start >= rateWindow) globalWindow = { start: time, count: 0 };
    const bucket = clients.get(ip) ?? { start: time, count: 0 };
    if (bucket.count >= 5 || globalWindow.count >= 50 || (!clients.has(ip) && clients.size >= maxClients)) return false;
    bucket.count++;
    globalWindow.count++;
    clients.set(ip, bucket);
    return true;
  }
  const server = createServer(async (request, response) => {
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('Content-Type', 'application/json');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    const reply = (status, value) => {
      response.writeHead(status);
      response.end(JSON.stringify(value));
    };
    if (request.url === '/health' && request.method === 'GET') return reply(200, { ok: true });
    if (request.url !== '/report') return reply(404, { error: 'Not found' });
    if (request.method !== 'POST') {
      response.setHeader('Allow', 'POST');
      return reply(405, { error: 'Use POST' });
    }
    if (request.headers['content-type']?.split(';')[0].trim() !== 'application/json') {
      return reply(415, { error: 'Use application/json' });
    }
    const forwarded = request.headers['x-forwarded-for'];
    const ip = trustProxy && typeof forwarded === 'string' ? forwarded.split(',').at(-1).trim() : request.socket.remoteAddress;
    if (!allow(ip)) {
      response.setHeader('Retry-After', '600');
      return reply(429, { error: 'Please try again later' });
    }
    if (active >= maxConcurrent) return reply(503, { error: 'Please try again later' });
    active++;
    try {
      const report = await readReport(request);
      await relay.submit(report);
      reply(201, { id: report.id });
    } catch (error) {
      if (error instanceof RequestError) return reply(error.status, { error: error.message });
      logger.error('Feedback submission failed');
      reply(502, { error: 'Submission failed; please retry' });
    } finally {
      active--;
    }
  });
  server.requestTimeout = 30_000;
  server.headersTimeout = 10_000;
  server.maxHeadersCount = 30;
  server.maxConnections = 100;
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  for (const key of ['LINEAR_API_KEY', 'LINEAR_TEAM_ID', 'LINEAR_PROJECT_ID', 'LINEAR_TRIAGE_STATE_ID']) {
    if (!process.env[key]) throw new Error(`Missing ${key}`);
  }
  const relay = new LinearRelay({
    apiKey: process.env.LINEAR_API_KEY, teamID: process.env.LINEAR_TEAM_ID,
    projectID: process.env.LINEAR_PROJECT_ID, triageStateID: process.env.LINEAR_TRIAGE_STATE_ID,
  });
  const server = createRelayServer({ relay, trustProxy: process.env.TRUST_PROXY === 'true' });
  server.listen(Number(process.env.PORT ?? 8080), process.env.HOST ?? '127.0.0.1', () => {
    console.log('Plinket feedback relay listening');
  });
}
