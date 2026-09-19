// Public, read-only HTTP adapter for a game's same-origin web host.
// Mount before static files. No arbitrary URL proxying, account cookies or AI inference.
const prefix = '/api/deck-import/tcg-mik/';
const operations = new Set(['deck/detail', 'deck/export-miniapp', 'card/card-detail']);
const maxResponseBytes = 3 * 1024 * 1024;

function reply(response, status, value) {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
  response.end(JSON.stringify(value));
}

export function createDeckImportGateway(fetchUpstream = globalThis.fetch) {
  return async function handle(request, response) {
    const pathname = new URL(request.url, 'http://localhost').pathname;
    if (!pathname.startsWith(prefix)) return false;
    const operation = pathname.slice(prefix.length);
    if (!operations.has(operation)) { reply(response, 404, { error: 'Unknown import operation' }); return true; }
    if (request.method !== 'POST') { reply(response, 405, { error: 'POST required' }); return true; }
    if (!String(request.headers['content-type'] || '').startsWith('application/json')) { reply(response, 415, { error: 'JSON required' }); return true; }
    try {
      let raw = '';
      for await (const chunk of request) {
        raw += chunk.toString('utf8');
        if (Buffer.byteLength(raw) > 4096) { reply(response, 413, { error: 'Request too large' }); return true; }
      }
      let body;
      try { body = JSON.parse(raw); } catch { reply(response, 400, { error: 'Invalid JSON' }); return true; }
      let payload;
      if (operation === 'deck/detail') {
        if (!Number.isSafeInteger(body?.deckId) || body.deckId <= 0) { reply(response, 400, { error: 'Invalid deck ID' }); return true; }
        payload = { deckId: body.deckId };
      } else if (operation === 'deck/export-miniapp') {
        if (typeof body?.deckCode !== 'string' || !/^[a-zA-Z0-9_-]{18}$/.test(body.deckCode)) { reply(response, 400, { error: 'Invalid miniapp deck code' }); return true; }
        payload = { deckCode: body.deckCode };
      } else {
        if (typeof body?.setCode !== 'string' || typeof body?.cardIndex !== 'string' || !/^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,31}$/.test(body.setCode) || !/^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,31}$/.test(body.cardIndex)) { reply(response, 400, { error: 'Invalid card identity' }); return true; }
        payload = { setCode: body.setCode, cardIndex: body.cardIndex };
      }
      const upstream = await fetchUpstream('https://tcg.mik.moe/api/v3/' + operation, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload), redirect: 'error', signal: AbortSignal.timeout(12000)
      });
      if (!upstream.ok) { reply(response, 502, { error: 'Card provider unavailable' }); return true; }
      if (Number(upstream.headers.get('content-length')) > maxResponseBytes) { await upstream.body?.cancel(); throw new Error('Response too large'); }
      const reader = upstream.body.getReader();
      const chunks = [];
      let size = 0;
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > maxResponseBytes) { await reader.cancel(); throw new Error('Response too large'); }
        chunks.push(Buffer.from(value));
      }
      const data = JSON.parse(Buffer.concat(chunks).toString('utf8'));
      if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Error('Invalid provider response');
      reply(response, 200, data);
    } catch {
      if (!response.headersSent) reply(response, 502, { error: 'Card import temporarily unavailable' });
    }
    return true;
  };
}
