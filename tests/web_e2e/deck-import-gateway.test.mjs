import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createDeckImportGateway } from '../../web/deck_import_gateway.mjs';

async function withGateway(upstream, run) {
  const handler = createDeckImportGateway(upstream);
  const server = createServer(async (req, res) => { if (!await handler(req, res)) { res.writeHead(404); res.end(); } });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try { await run(`http://127.0.0.1:${server.address().port}/api/deck-import/tcg-mik/`); }
  finally { await new Promise(resolve => server.close(resolve)); }
}
const post = body => ({ method: 'POST', headers: { 'Content-Type': 'application/json', Origin: 'https://game.example', Cookie: 'never-forward=secret' }, body: JSON.stringify(body) });

test('miniapp export forwards the exact code and strips unrelated fields', async () => {
  await withGateway(async (url, options) => {
    assert.equal(url, 'https://tcg.mik.moe/api/v3/deck/export-miniapp');
    assert.deepEqual(JSON.parse(options.body), { deckCode: 'dFJ1jZgeo_xEbSTvjj' });
    return Response.json({ code: 200, data: { deckCode: 'dFJ1jZgeo_xEbSTvjj' } });
  }, async root => {
    const response = await fetch(root + 'deck/export-miniapp', post({ deckCode: 'dFJ1jZgeo_xEbSTvjj', url: 'http://localhost/admin' }));
    assert.equal(response.status, 200);
    assert.equal((await response.json()).data.deckCode, 'dFJ1jZgeo_xEbSTvjj');
  });
});

test('malformed miniapp codes never reach upstream', async () => {
  await withGateway(() => { throw new Error('Must not call upstream'); }, async root => {
    for (const deckCode of ['', 'short', 'dFJ1jZgeo_xEbSTvjj!', 'dFJ1jZgeo/xEbSTvjj', 123, null, ['dFJ1jZgeo_xEbSTvjj']]) {
      assert.equal((await fetch(root + 'deck/export-miniapp', post({ deckCode }))).status, 400);
    }
  });
});

test('gateway forwards only public deck identity, without browser credentials or Origin', async () => {
  await withGateway(async (url, options) => {
    assert.equal(url, 'https://tcg.mik.moe/api/v3/deck/detail');
    assert.deepEqual(JSON.parse(options.body), { deckId: 574793 });
    assert.deepEqual(options.headers, { 'Content-Type': 'application/json' });
    assert.equal(options.redirect, 'error');
    return Response.json({ code: 200, data: { cards: [] } });
  }, async root => {
    const result = await fetch(root + 'deck/detail', post({ deckId: 574793, url: 'http://localhost/admin' }));
    assert.equal(result.status, 200);
    assert.equal((await result.json()).code, 200);
  });
});

test('invalid operations, identity, methods and oversized requests never reach upstream', async () => {
  await withGateway(() => { throw new Error('Must not call upstream'); }, async root => {
    for (const [path, options, status] of [
      ['admin', post({ deckId: 1 }), 404], ['deck/detail', {}, 405],
      ['deck/detail', post({ deckId: -1 }), 400], ['deck/detail', post({ deckId: '1' }), 400],
      ['card/card-detail', post({ setCode: '../etc', cardIndex: '001' }), 400],
      ['deck/detail', post({ deckId: 1, extra: 'x'.repeat(5000) }), 413]
    ]) assert.equal((await fetch(root + path, options)).status, status);
  });
});

test('uncached card lookup preserves the exact printing identity', async () => {
  await withGateway(async (url, options) => {
    assert.equal(url, 'https://tcg.mik.moe/api/v3/card/card-detail');
    assert.deepEqual(JSON.parse(options.body), { setCode: 'CSV6C', cardIndex: '114' });
    return Response.json({ code: 200, data: { name: 'Test card' } });
  }, async root => assert.equal((await fetch(root + 'card/card-detail', post({ setCode: 'CSV6C', cardIndex: '114' }))).status, 200));
});

test('dotted Chinese expansion names remain valid exact card lookups', async () => {
  await withGateway(async (_url, options) => {
    assert.deepEqual(JSON.parse(options.body), { setCode: 'CS6.5C', cardIndex: '071' });
    return Response.json({ code: 200 });
  }, async root => assert.equal((await fetch(root + 'card/card-detail', post({ setCode: 'CS6.5C', cardIndex: '071' }))).status, 200));
});

test('upstream errors and malformed responses become bounded, non-sensitive failures', async () => {
  for (const upstream of [() => Promise.reject(new Error('private upstream diagnostics')), () => Promise.resolve(new Response('no', { status: 403 })), () => Promise.resolve(new Response('not JSON'))]) {
    await withGateway(upstream, async root => {
      const response = await fetch(root + 'deck/detail', post({ deckId: 1 }));
      assert.equal(response.status, 502);
      assert.doesNotMatch(await response.text(), /private upstream/);
    });
  }
});

test('opt-in live provider returns the actual 60-card deck through the gateway', { skip: process.env.PTCG_LIVE_TCG_IMPORT !== '1' }, async () => {
  await withGateway(globalThis.fetch, async root => {
    const response = await fetch(root + 'deck/detail', post({ deckId: 574793 }));
    assert.equal(response.status, 200);
    const result = await response.json();
    assert.equal(result.code, 200);
    assert.equal(result.data.cards.reduce((sum, card) => sum + card.count, 0), 60);
  });
});
