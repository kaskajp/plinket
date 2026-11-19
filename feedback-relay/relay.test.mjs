import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import test from 'node:test';
import { createRelayServer } from './server.mjs';
import { LinearRelay, issueID } from './linear.mjs';

function report(overrides = {}) {
  return {
    id: randomUUID(), title: 'Playback stops', details: 'It stops after one song.',
    appVersion: '1.1.0 (2)', platform: 'iOS', osVersion: '27.2', locale: 'en-US',
    screenshots: [], ...overrides,
  };
}
const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);

async function serverFixture(t, options = {}) {
  const reports = [];
  const server = createRelayServer({ relay: { submit: async value => { reports.push(value); } }, ...options });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;
  return {
    reports,
    send: (body, init = {}) => fetch(`${base}/report`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body), ...init,
    }),
  };
}

function linearFixture(options = {}) {
  const operations = [];
  const issues = new Set();
  let failUpload = options.failUpload;
  const fetcher = async (url, init) => {
    if (String(url).startsWith('https://uploads.example/')) {
      operations.push({ kind: 'put', init });
      if (failUpload) { failUpload = false; return new Response('', { status: 503 }); }
      return new Response('');
    }
    const { query, variables } = JSON.parse(init.body);
    assert.equal(init.headers.Authorization, 'server-only-key');
    if (query.includes('FeedbackExists')) {
      operations.push({ kind: 'exists', variables });
      return Response.json({ data: { issues: { nodes: issues.has(variables.id)
        ? [{ id: variables.id, project: { id: 'project' } }] : [] } } });
    }
    if (query.includes('FeedbackUpload')) {
      operations.push({ kind: 'upload', variables });
      return Response.json({ data: { fileUpload: { success: true, uploadFile: {
        uploadUrl: 'https://uploads.example/signed', assetUrl: 'https://assets.example/screenshot.jpg',
        headers: [{ key: 'x-upload', value: 'required' }],
      } } } });
    }
    operations.push({ kind: 'create', variables });
    issues.add(variables.input.id);
    if (options.loseResponse) throw new Error('Connection lost after mutation');
    return Response.json({ data: { issueCreate: { success: true, issue: { id: variables.input.id } } } });
  };
  const config = { apiKey: 'server-only-key', teamID: 'team', projectID: 'project', triageStateID: 'triage', fetcher };
  return { relay: new LinearRelay(config), config, operations, issues };
}

test('accepts an app report and decodes its screenshot', async t => {
  const fixture = await serverFixture(t);
  const input = report({ screenshots: [jpeg.toString('base64')], teamId: 'attacker-team', apiKey: 'attacker-key' });
  const response = await fixture.send(input);
  assert.equal(response.status, 201);
  assert.deepEqual(await response.json(), { id: input.id });
  assert.deepEqual(fixture.reports[0].screenshots, [jpeg]);
  assert.equal(fixture.reports[0].teamId, undefined);
  assert.equal(fixture.reports[0].apiKey, undefined);
});

test('rejects malformed, empty, excessive and non-image payloads before calling Linear', async t => {
  const fixture = await serverFixture(t, { trustProxy: true });
  const cases = [null, report({ title: '  ' }), report({ details: '' }), report({ title: 'x'.repeat(201) }),
    report({ screenshots: Array(4).fill(jpeg.toString('base64')) }),
    report({ screenshots: [Buffer.from('not an image').toString('base64')] }),
    report({ screenshots: ['!!!!'] }), report({ id: 'other-issue' }), report({ screenshots: [{}] })];
  for (const [index, input] of cases.entries()) {
    const response = await fixture.send(input, { headers: { 'Content-Type': 'application/json', 'X-Forwarded-For': `test-${index}` } });
    assert.equal(response.status, 400);
  }
  assert.equal(fixture.reports.length, 0);
});

test('enforces screenshot and request body byte limits', async t => {
  const fixture = await serverFixture(t);
  const tooLarge = Buffer.alloc(2 * 1024 * 1024 + 1).toString('base64');
  assert.equal((await fixture.send(report({ screenshots: [tooLarge] }))).status, 400);
  assert.equal((await fixture.send(report({ details: 'x'.repeat(9 * 1024 * 1024) }))).status, 413);
  assert.equal(fixture.reports.length, 0);
});

test('rate limits clients, ignores untrusted forwarded headers, and expires counters', async t => {
  let time = 0;
  const fixture = await serverFixture(t, { now: () => time });
  for (let i = 0; i < 5; i++) {
    assert.equal((await fixture.send(report(), { headers: { 'Content-Type': 'application/json', 'X-Forwarded-For': `spoof-${i}` } })).status, 201);
  }
  const limited = await fixture.send(report());
  assert.equal(limited.status, 429);
  assert.equal(limited.headers.get('Retry-After'), '600');
  time += 600_000;
  assert.equal((await fixture.send(report())).status, 201);
});

test('upstream errors never acknowledge receipt or expose upstream details', async t => {
  const messages = [];
  const fixture = await serverFixture(t, {
    relay: { submit: async () => { throw new Error('secret-api-key'); } },
    logger: { error: message => messages.push(message) },
  });
  const response = await fixture.send(report());
  assert.equal(response.status, 502);
  assert.doesNotMatch(await response.text(), /secret/);
  assert.deepEqual(messages, ['Feedback submission failed']);
});

test('uploads screenshots before creating an issue in configured triage and project', async () => {
  const fixture = linearFixture();
  const input = report({ screenshots: [jpeg] });
  await fixture.relay.submit(input);
  assert.deepEqual(fixture.operations.map(op => op.kind), ['exists', 'upload', 'put', 'create']);
  const put = fixture.operations.find(op => op.kind === 'put');
  assert.equal(put.init.headers['x-upload'], 'required');
  assert.deepEqual(put.init.body, jpeg);
  const created = fixture.operations.find(op => op.kind === 'create').variables.input;
  assert.equal(created.teamId, 'team');
  assert.equal(created.projectId, 'project');
  assert.equal(created.stateId, 'triage');
  assert.match(created.id, /^[a-f0-9-]{14}4[a-f0-9-]+$/);
  assert.match(created.description, /!\[Screenshot 1\]\(<https:\/\/assets.example\/screenshot.jpg>\)/);
  assert.match(created.description, /Platform: iOS/);
  assert.match(created.description, /App: 1.1.0 \(2\)/);
  assert.match(created.description, /It stops after one song/);
});

test('upload failure leaves no incomplete issue and allows retry', async () => {
  const fixture = linearFixture({ failUpload: true });
  const input = report({ screenshots: [jpeg] });
  await assert.rejects(fixture.relay.submit(input), /upload failed/);
  assert.equal(fixture.issues.size, 0);
  await fixture.relay.submit(input);
  assert.equal(fixture.issues.size, 1);
});

test('retries, concurrent submits and relay restarts do not create duplicate issues', async () => {
  const fixture = linearFixture();
  const input = report();
  await Promise.all([fixture.relay.submit(input), fixture.relay.submit(input)]);
  await fixture.relay.submit(input);
  await new LinearRelay(fixture.config).submit(input);
  assert.equal(fixture.operations.filter(op => op.kind === 'create').length, 1);
  assert.equal(fixture.issues.size, 1);
  assert.equal(issueID(input.id), issueID(input.id.toUpperCase()));
});

test('lost mutation response is reconciled with Linear before acknowledging success', async () => {
  const fixture = linearFixture({ loseResponse: true });
  const input = report();
  await fixture.relay.submit(input);
  assert.equal(fixture.issues.size, 1);
  assert.deepEqual(fixture.operations.map(op => op.kind), ['exists', 'create', 'exists']);
});

test('GraphQL errors in an HTTP 200 response are failures', async () => {
  const fixture = linearFixture();
  const relay = new LinearRelay({ ...fixture.config, fetcher: async () => Response.json({ errors: [{ message: 'No permission' }] }) });
  await assert.rejects(relay.submit(report()), /Linear rejected request/);
});

test('caps concurrent submissions instead of starting unbounded upstream work', async t => {
  let release;
  const blocked = new Promise(resolve => { release = resolve; });
  let notify;
  const allStarted = new Promise(resolve => { notify = resolve; });
  let active = 0;
  const fixture = await serverFixture(t, {
    relay: { submit: async () => { if (++active === 4) notify(); await blocked; } },
  });
  const pending = Array.from({ length: 4 }, () => fixture.send(report()));
  await allStarted;
  try {
    assert.equal((await fixture.send(report())).status, 503);
    assert.equal(active, 4);
  } finally {
    release();
    for (const response of await Promise.all(pending)) assert.equal(response.status, 201);
  }
});

test('global rate cap also limits submissions spread across client IPs', async t => {
  const fixture = await serverFixture(t, { trustProxy: true });
  for (let i = 0; i < 50; i++) {
    assert.equal((await fixture.send(report(), {
      headers: { 'Content-Type': 'application/json', 'X-Forwarded-For': `client-${i}` },
    })).status, 201);
  }
  assert.equal((await fixture.send(report(), {
    headers: { 'Content-Type': 'application/json', 'X-Forwarded-For': 'another-client' },
  })).status, 429);
  assert.equal(fixture.reports.length, 50);
});
