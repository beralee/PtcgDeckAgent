const { test, expect } = require('@playwright/test');

test('downloaded author strategy starts and completes local Web matches', async ({ page }, testInfo) => {
  const fixtureDir = process.env.PTCG_WEB_STRATEGY_FIXTURE_DIR;
  test.skip(!fixtureDir, 'Supply a pinned public leaderboard/profile/package fixture directory');
  test.setTimeout(600000);
  const fs = require('node:fs');
  const path = require('node:path');
  const read = name => fs.readFileSync(path.join(fixtureDir, name));
  const parse = name => JSON.parse(read(name).toString('utf8').replace(/^\uFEFF/, ''));
  const profile = parse('profile.json');
  const release = profile.release;
  const bytes = read('marnie.ptcgai');
  expect(require('node:crypto').createHash('sha256').update(bytes).digest('hex').toUpperCase()).toBe(release.archive_sha256);
  const errors = [];
  page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', error => errors.push(String(error)));
  await startGame(page);
  await bridgeRequest(page, 'prepare_author_download_fixture', { package_id: release.package_id });
  await page.route('**/v1/ladder/leaderboard', route => route.fulfill({ contentType: 'application/json', body: JSON.stringify(parse('leaderboard.json')) }));
  await page.route(`**/v1/ladder/releases/${release.release_id}/profile`, route => route.fulfill({ contentType: 'application/json', body: JSON.stringify(profile) }));
  let downloads = 0;
  await page.route(`**${release.installable_release.distribution.href}`, route => {
    downloads++;
    return route.fulfill({ headers: {
      'Content-Type': 'application/vnd.ptcgdap.strategy-package',
      'Access-Control-Expose-Headers': 'ETag, Content-Length',
      'Content-Length': String(bytes.length), ETag: `"${release.archive_sha256}"`
    }, body: bytes });
  });
  const touch = testInfo.project.name.includes('touch');
  await activateControl(page, 'BtnStrategyHub', touch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('StrategyHub');
  await expect.poll(async () => (await bridgeRequest(page, 'list_controls')).some(item => item.name === 'ContinuousLadderReleaseButton')).toBe(true);
  await activateVisibleNamedControl(page, 'ContinuousLadderReleaseButton', touch);
  await expect.poll(async () => (await bridgeRequest(page, 'list_controls')).find(item => item.name === 'SelectedDownloadButton')?.disabled).toBe(false);
  await activateControl(page, 'SelectedDownloadButton', touch);
  await expect.poll(async () => (await bridgeRequest(page, 'list_controls')).find(item => item.name === 'SelectedDownloadButton')?.text || '', { timeout: 60000 }).toMatch(/^(对战|开战)$/);
  expect(downloads).toBe(1);
  await bridgeRequest(page, 'start_author_strategy_probe', { package_id: release.package_id, version: release.package_version });
  await expect.poll(async () => (await bridgeRequest(page, 'author_strategy_probe')).done, { timeout: 490000, intervals: [1000, 2000] }).toBe(true);
  const report = await bridgeRequest(page, 'author_strategy_probe');
  await testInfo.attach('local-matches', { body: JSON.stringify(report, null, 2), contentType: 'application/json' });
  expect(report.error).toBe('');
  expect(report.platform).toBe('Web');
  expect(report.matches).toHaveLength(2);
  for (const match of report.matches) {
    expect(match.error).toBe('');
    expect(match.game_over).toBe(true);
    expect(match.policy_execution_profile).toBe('main_thread_v1');
    expect(match.policy_successes).toBeGreaterThan(0);
    for (const field of ['policy_errors', 'engine_rejections', 'invalid_outputs', 'same_window_fallbacks', 'policy_worker_start_failures', 'policy_worker_stale_results']) expect(match[field], `${field}: ${JSON.stringify(match)}`).toBe(0);
  }
  await activateControl(page, 'SelectedDownloadButton', touch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('BattleSetup');
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'BtnStart' })).disabled).toBe(false);
  await activateControl(page, 'BtnStart', touch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('BattleScene');
  await expect.poll(async () => (await bridgeRequest(page, 'author_battle_probe')).audit.policy_execution_profile).toBe('main_thread_v1');
  expect((await bridgeRequest(page, 'author_battle_probe')).start_error).toBe('');
  await page.screenshot({ path: testInfo.outputPath('author-battle.png') });
  expect(errors.filter(value => /SCRIPT ERROR|Thread.*(unavailable|failed|support)|Uncaught|unreachable/.test(value))).toEqual([]);
});

async function bridgeRequest(page, command, payload = {}) {
  const requestId = await page.evaluate(({ command, payload }) => window.__PTCG_TEST__.request(command, payload), { command, payload });
  await page.waitForFunction(id => {
    const value = window.__PTCG_TEST__ && window.__PTCG_TEST__.result(id);
    return value && value.done === true;
  }, requestId, { timeout: 30000 });
  const result = await page.evaluate(id => window.__PTCG_TEST__.consume(id), requestId);
  if (!result || !result.ok) throw new Error(result && result.error ? result.error : `E2E bridge command failed: ${command}`);
  return result.value;
}

async function isolateExternalServices(page) {
  await page.route(/https?:\/\/(?:[^/]+\.)?skillserver\.cn\/.*/, route => route.fulfill({
    status: 200,
    contentType: 'application/json; charset=utf-8',
    body: '{}'
  }));
}

async function startGame(page, adapterMode = 'v2') {
  await isolateExternalServices(page);
  await page.goto(`/PtcgDeckAgent.html?web_ui_adapter=${adapterMode}`, { waitUntil: 'domcontentloaded' });
  await page.locator('#start-game').click();
  await page.waitForFunction(() => window.__PTCG_TEST__ && typeof window.__PTCG_TEST__.request === 'function', null, { timeout: 90000 });
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('MainMenu');
}

async function semanticPoint(page, id) {
  const control = await bridgeRequest(page, 'find_control', { id });
  expect(control.visible).toBe(true);
  expect(control.disabled).toBe(false);
  expect(control.rect.width).toBeGreaterThan(1);
  expect(control.rect.height).toBeGreaterThan(1);
  const snapshot = await bridgeRequest(page, 'snapshot');
  const canvas = await page.locator('#canvas').boundingBox();
  if (!canvas) throw new Error('Godot canvas has no browser bounding box');
  const viewport = snapshot.runtime_profile.viewport_size;
  const logicalWidth = Math.max(1, Number(viewport.x || viewport.width || canvas.width));
  const logicalHeight = Math.max(1, Number(viewport.y || viewport.height || canvas.height));
  return {
    x: canvas.x + (control.rect.x + control.rect.width * 0.5) * canvas.width / logicalWidth,
    y: canvas.y + (control.rect.y + control.rect.height * 0.5) * canvas.height / logicalHeight
  };
}

async function visibleSemanticPoint(page, id) {
  const controls = await bridgeRequest(page, 'list_controls');
  const snapshot = await bridgeRequest(page, 'snapshot');
  const viewport = snapshot.runtime_profile.viewport_size;
  const logicalWidth = Math.max(1, Number(viewport.x || viewport.width));
  const logicalHeight = Math.max(1, Number(viewport.y || viewport.height));
  const control = controls
    .filter(item => item.name === id && item.visible)
    .filter(item => item.rect.x + item.rect.width * 0.5 >= 0 && item.rect.x + item.rect.width * 0.5 <= logicalWidth)
    .filter(item => item.rect.y + item.rect.height * 0.5 >= 0 && item.rect.y + item.rect.height * 0.5 <= logicalHeight)
    .sort((a, b) => a.rect.y - b.rect.y)[0];
  if (!control) throw new Error(`No on-screen control found: ${id}`);
  const canvas = await page.locator('#canvas').boundingBox();
  if (!canvas) throw new Error('Godot canvas has no browser bounding box');
  return {
    x: canvas.x + (control.rect.x + control.rect.width * 0.5) * canvas.width / logicalWidth,
    y: canvas.y + (control.rect.y + control.rect.height * 0.5) * canvas.height / logicalHeight
  };
}

async function activateControl(page, id, useTouch) {
  const point = await semanticPoint(page, id);
  if (process.env.PTCG_E2E_POINTER_DIAGNOSTICS === '1') {
    const control = await bridgeRequest(page, 'find_control', { id });
    const snapshot = await bridgeRequest(page, 'snapshot');
    const canvas = await page.locator('#canvas').boundingBox();
    console.log('POINTER_DIAGNOSTIC', JSON.stringify({ id, point, control, viewport: snapshot.runtime_profile.viewport_size, canvas }));
  }
  if (useTouch) await page.touchscreen.tap(point.x, point.y);
  else await page.mouse.click(point.x, point.y);
}

async function activateVisibleNamedControl(page, id, useTouch) {
  const point = await visibleSemanticPoint(page, id);
  if (useTouch) await page.touchscreen.tap(point.x, point.y);
  else await page.mouse.click(point.x, point.y);
}

async function scrollControlIntoView(page, id) {
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const control = await bridgeRequest(page, 'find_control', { id });
    const snapshot = await bridgeRequest(page, 'snapshot');
    const viewport = snapshot.runtime_profile.viewport_size;
    const logicalHeight = Math.max(1, Number(viewport.y || viewport.height));
    const centerY = control.rect.y + control.rect.height * 0.5;
    if (centerY >= 0 && centerY <= logicalHeight) return;
    const canvas = await page.locator('#canvas').boundingBox();
    if (!canvas) throw new Error('Godot canvas has no browser bounding box');
    if (test.info().project.name.startsWith('webkit-touch')) {
      // Mobile WebKit cannot synthesize mouse wheels. Exercise the same canvas
      // touch listeners as a finger drag, without changing Godot scroll state.
      await page.evaluate(async ({ x, y, direction }) => {
        const canvas = document.querySelector('#canvas');
        for (let i = 0; i <= 9; i++) {
          const point = { identifier: 92, target: canvas, clientX: x, clientY: y - Math.min(i, 8) * 30 * direction };
          Object.assign(point, { pageX: point.clientX, pageY: point.clientY, screenX: point.clientX, screenY: point.clientY });
          const event = new Event(i === 0 ? 'touchstart' : i === 9 ? 'touchend' : 'touchmove', { bubbles: true, cancelable: true });
          Object.defineProperties(event, {
            touches: { value: i === 9 ? [] : [point] }, targetTouches: { value: i === 9 ? [] : [point] }, changedTouches: { value: [point] }
          });
          canvas.dispatchEvent(event);
          await new Promise(resolve => setTimeout(resolve, 16));
        }
      }, { x: canvas.x + canvas.width * 0.8, y: canvas.y + canvas.height * 0.7, direction: centerY > logicalHeight ? 1 : -1 });
    } else {
      await page.mouse.move(canvas.x + canvas.width * 0.5, canvas.y + canvas.height * 0.75);
      await page.mouse.wheel(0, centerY > logicalHeight ? 650 : -650);
    }
    await page.waitForTimeout(80);
  }
  throw new Error(`Control did not scroll into view: ${id}`);
}

test('miniapp import switches source, retries, and persists all 60 cards', async ({ page }, testInfo) => {
  const fixture = structuredClone(require('../fixtures/deck_import/miniapp_raging_bolt.json'));
  fixture.data.variant.variantName = 'Miniapp import regression';
  const code = 'dFJ1jZgeo_xEbSTvjj';
  const deckId = 353556119508282;
  const requests = [];
  await page.route('**/api/deck-import/tcg-mik/deck/export-miniapp', async route => {
    requests.push(route.request().postDataJSON());
    if (requests.length === 1) await route.fulfill({ status: 503, body: '{}' });
    else await route.fulfill({ contentType: 'application/json', body: JSON.stringify(fixture) });
  });
  await startGame(page, 'v2');
  const useTouch = testInfo.project.name.includes('touch');
  await activateControl(page, 'BtnDeckManager', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('DeckManager');
  await activateControl(page, 'BtnImport', useTouch);
  await activateControl(page, 'ImportSource_miniapp', useTouch);
  const editor = page.locator('body > input');
  await expect(editor).toHaveCount(1);
  await editor.fill(code);
  await page.screenshot({ path: testInfo.outputPath('miniapp-input.png') });
  await activateControl(page, 'BtnDoImport', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'ProgressLabel' })).text).toContain('暂时不可用');
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'UrlInput' })).text).toBe(code);
  await activateControl(page, 'BtnDoImport', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'saved_deck_probe', { id: deckId })).total_cards, { timeout: 60000 }).toBe(60);
  expect(requests).toEqual([{ deckCode: code }, { deckCode: code }]);
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'BtnDoImport' })).text).toBe('查看卡组');
  await page.screenshot({ path: testInfo.outputPath('miniapp-success.png') });
  await page.reload();
  await page.locator('#start-game').click();
  await page.waitForFunction(() => window.__PTCG_TEST__);
  await expect.poll(async () => (await bridgeRequest(page, 'saved_deck_probe', { id: deckId })).total_cards).toBe(60);
});

test('Safari deck import accepts pasted URL and persists a complete deck', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name.endsWith('landscape'), 'Portrait import and desktop');
  const fixture = structuredClone(require('./fixtures/tcg-deck-574793.json'));
  fixture.data.variant.variantName = 'Safari import regression 991574793';
  const requests = [];
  await page.route('**/api/deck-import/tcg-mik/deck/detail', async route => {
    requests.push(route.request().postDataJSON());
    await route.fulfill({ contentType: 'application/json', body: JSON.stringify(fixture) });
  });
  await startGame(page, 'v2');
  const useTouch = testInfo.project.name.includes('touch');
  await activateControl(page, 'BtnDeckManager', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('DeckManager');
  await activateControl(page, 'BtnImport', useTouch);
  const editor = page.locator('body > input');
  await expect(editor).toHaveCount(1);
  if (useTouch) await editor.tap(); else await editor.click();
  await editor.evaluate(input => {
    const clipboard = new DataTransfer();
    clipboard.setData('text/plain', 'https://tcg.mik.moe/decks/list/991574793');
    input.dispatchEvent(new ClipboardEvent('paste', { clipboardData: clipboard, bubbles: true, cancelable: true }));
  });
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'UrlInput' })).text).toBe('https://tcg.mik.moe/decks/list/991574793');
  await activateControl(page, 'BtnDoImport', useTouch);
  await expect.poll(() => requests.length).toBe(1);
  expect(requests[0]).toEqual({ deckId: 991574793 });
  await expect.poll(async () => (await bridgeRequest(page, 'saved_deck_probe', { id: 991574793 })).total_cards, { timeout: 60000 }).toBe(60);
  await expect.poll(() => page.evaluate(() => window.__ptcgImportStorage?.done), { timeout: 70000 }).toBe(true);
  expect(await page.evaluate(() => window.__ptcgImportStorage)).toEqual({ done: true, ok: true, error: '' });
  await page.reload();
  await page.locator('#start-game').click();
  await page.waitForFunction(() => window.__PTCG_TEST__);
  await expect.poll(async () => (await bridgeRequest(page, 'saved_deck_probe', { id: 991574793 })).total_cards).toBe(60);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('MainMenu');
  await activateControl(page, 'BtnDeckManager', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('DeckManager');
  await activateControl(page, 'BtnImport', useTouch);
  await expect(editor).toHaveCount(1);
  await editor.fill('991574794');
  await activateControl(page, 'BtnDoImport', useTouch);
  await expect.poll(() => requests.length).toBe(2);
  await expect.poll(async () => (await bridgeRequest(page, 'list_controls')).some(control => control.name === 'DeckRenameConfirmButton' && control.visible)).toBe(true);
  await expect(editor).toHaveValue(fixture.data.variant.variantName);
  await editor.fill('Safari renamed deck');
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'DeckRenameConfirmButton' })).disabled).toBe(false);
  await activateControl(page, 'DeckRenameConfirmButton', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'saved_deck_probe', { id: 991574794 })).deck_name).toBe('Safari renamed deck');
  expect(requests).toEqual([{ deckId: 991574793 }, { deckId: 991574794 }]);
  await page.screenshot({ path: testInfo.outputPath('import-saved.png') });
});

test('Safari deck import reports storage denial without claiming durable success', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'webkit-touch', 'Safari storage failure');
  await page.addInitScript(() => {
    const original = Storage.prototype.setItem;
    Storage.prototype.setItem = function(key, value) {
      if (key.startsWith('ptcgdap.deck.v1.')) throw new DOMException('Quota exceeded', 'QuotaExceededError');
      return original.call(this, key, value);
    };
  });
  const fixture = structuredClone(require('./fixtures/tcg-deck-574793.json'));
  fixture.data.variant.variantName = 'Safari quota regression';
  await page.route('**/api/deck-import/tcg-mik/deck/detail', route => route.fulfill({ contentType: 'application/json', body: JSON.stringify(fixture) }));
  await startGame(page, 'v2');
  await activateControl(page, 'BtnDeckManager', true);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('DeckManager');
  await activateControl(page, 'BtnImport', true);
  await page.locator('body > input').fill('991574795');
  await activateControl(page, 'BtnDoImport', true);
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'ProgressLabel' })).text).toContain('浏览器未能保存');
  expect(await page.evaluate(() => window.__ptcgImportStorage.ok)).toBe(false);
});

test('strategy hub settings scrolls through canvas input and keeps tabs usable', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name.endsWith('landscape'), 'Portrait touch and desktop are covered separately');
  await startGame(page, 'v2');
  const useTouch = testInfo.project.name.includes('touch');
  await activateControl(page, 'BtnStrategyHub', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('StrategyHub');
  await activateControl(page, 'AISettingsTab', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'AISettingsWorkspace' })).scroll_max).toBeGreaterThan(0);
  const center = await semanticPoint(page, 'AISettingsWorkspace');
  if (useTouch && testInfo.project.name.startsWith('chromium')) {
    const cdp = await page.context().newCDPSession(page);
    const from = { x: center.x, y: center.y + 100 };
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [from] });
    for (let i = 1; i <= 8; i++) {
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: from.x, y: from.y - i * 30 }] });
    }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await cdp.detach();
  } else if (useTouch) {
    // WebKit has no CDP touch-drag API: dispatch DOM touches through the canvas listener.
    await page.evaluate(({ x, y }) => {
      const canvas = document.querySelector('#canvas');
      for (let i = 0; i <= 9; i++) {
        const touchY = y + 100 - Math.min(i, 8) * 30;
        const point = { identifier: 91, target: canvas, clientX: x, clientY: touchY, pageX: x, pageY: touchY, screenX: x, screenY: touchY };
        const event = new Event(i === 0 ? 'touchstart' : i === 9 ? 'touchend' : 'touchmove', { bubbles: true, cancelable: true });
        Object.defineProperties(event, {
          touches: { value: i === 9 ? [] : [point] }, targetTouches: { value: i === 9 ? [] : [point] }, changedTouches: { value: [point] }
        });
        canvas.dispatchEvent(event);
      }
    }, center);
  } else {
    await page.mouse.move(center.x, center.y);
    await page.mouse.wheel(0, 650);
  }
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'AISettingsWorkspace' })).scroll_vertical).toBeGreaterThan(50);
  await activateControl(page, 'LocalStrategyTab', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'LocalStrategyWorkspace' })).visible).toBe(true);
  expect((await bridgeRequest(page, 'find_control', { id: 'AISettingsTab' })).text).toBe('DeepSeek');
  const developerTab = await bridgeRequest(page, 'find_control', { id: 'ReplayTab' });
  expect(developerTab.visible).toBe(true);
  expect(developerTab.text).toBe('开发者');
  await activateControl(page, 'ReplayTab', useTouch);
  expect((await bridgeRequest(page, 'find_control', { id: 'DeveloperPortalButton' })).visible).toBe(true);
});

test('real canvas input navigates main menu and settings without runtime errors', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name.endsWith('landscape'), 'The landscape WebKit project is scoped to battle HUD touch regression');
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (message.type() === 'error' && message.text().includes('WEB_RUNTIME_ERROR')) errors.push(message.text());
  });
  await startGame(page, 'v2');
  const initial = await bridgeRequest(page, 'snapshot');
  expect(initial.runtime_profile.host_kind).toBe('web');
  const useTouch = testInfo.project.name.includes('touch');
  await activateControl(page, 'BtnStrategyHub', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('StrategyHub');
  await activateControl(page, 'AISettingsTab', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('StrategyHub');
  await activateControl(page, 'BackButton', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('MainMenu');
  expect(errors).toEqual([]);
});

test('iOS Web AI key opens a real DOM editor and syncs typed text', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'webkit-touch', 'This regression targets portrait iOS Safari text entry');
  await startGame(page, 'v2');
  await activateControl(page, 'BtnStrategyHub', true);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('StrategyHub');
  await activateControl(page, 'AISettingsTab', true);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('StrategyHub');
  await scrollControlIntoView(page, 'ApiKeyInput');

  await activateControl(page, 'ApiKeyInput', true);
  const immediateDomState = await page.evaluate(() => {
    const state = window.__ptcgDeckAgentTextInput || null;
    return {
      version: state ? state.version : 0,
      hasInput: !!(state && state.input),
      connected: !!(state && state.input && state.input.isConnected),
      activeTag: document.activeElement ? document.activeElement.tagName : '',
      inputCount: document.querySelectorAll('body > input').length,
      openCount: state ? state.openCount : 0,
      createdCount: state ? state.createdCount : 0,
      blurCount: state ? state.blurCount : 0,
      removedCount: state ? state.removedCount : 0,
      refocusCount: state ? state.refocusCount : 0,
      lastError: state ? state.lastError : ''
    };
  });
  const editor = page.locator('body > input').filter({ hasNot: page.locator('#canvas') });
  try {
    await expect(editor).toHaveCount(1);
  } catch (error) {
    const diagnostics = await bridgeRequest(page, 'text_input_diagnostics', { id: 'ApiKeyInput' });
    throw new Error(`${error.message}\nImmediate DOM state: ${JSON.stringify(immediateDomState)}\nText input diagnostics: ${JSON.stringify(diagnostics)}`);
  }
  await expect(editor).toBeFocused();
  await editor.fill('sk-webkit-e2e');
  try {
    await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'ApiKeyInput' })).text).toBe('sk-webkit-e2e');
  } catch (error) {
    const diagnostics = await bridgeRequest(page, 'text_input_diagnostics', { id: 'ApiKeyInput' });
    const domDiagnostics = await page.evaluate(() => {
      const state = window.__ptcgDeckAgentTextInput || null;
      return {
        activeValueLength: state && state.input ? state.input.value.length : -1,
        activeTag: document.activeElement ? document.activeElement.tagName : '',
        stateVersion: state ? state.version : 0,
        stateId: state ? state.id : 0,
        inputConnected: !!(state && state.input && state.input.isConnected),
        inputCount: state ? state.openCount : 0,
        blurCount: state ? state.blurCount : 0,
        removedCount: state ? state.removedCount : 0,
        lastError: state ? state.lastError : ''
      };
    });
    throw new Error(`${error.message}\nDOM diagnostics: ${JSON.stringify(domDiagnostics)}\nGodot diagnostics: ${JSON.stringify(diagnostics)}`);
  }
  await page.evaluate(() => {
    const state = window.__ptcgDeckAgentTextInput;
    const callback = window.__ptcgDeckAgentTextInputCallback;
    if (state && state.input && typeof callback === 'function') {
      callback(JSON.stringify({ event: 'commit', value: state.input.value, id: state.id || 0 }));
    }
    if (state && typeof state.close === 'function') state.close();
  });
  await expect(editor).toHaveCount(0);
});

test('iOS Web native API key paste is isolated, cancellable, and persistent', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'webkit-touch', 'This regression targets portrait iOS Safari native paste');
  await startGame(page, 'v2');
  await activateControl(page, 'BtnStrategyHub', true);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('StrategyHub');
  await activateControl(page, 'AISettingsTab', true);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('StrategyHub');
  await scrollControlIntoView(page, 'BtnPasteApiKey');
  const originalKey = (await bridgeRequest(page, 'find_control', { id: 'ApiKeyInput' })).text;
  await activateControl(page, 'BtnPasteApiKey', true);
  const secretOverlay = page.locator('#ptcg-native-secret-entry');
  const secretInput = page.locator('#ptcg-native-secret-input');
  const secretReadClipboard = page.locator('#ptcg-native-secret-read-clipboard');
  const secretCancel = page.locator('#ptcg-native-secret-cancel');
  const secretConfirm = page.locator('#ptcg-native-secret-confirm');
  await expect(secretOverlay).toHaveCount(1);
  await expect(secretInput).toBeFocused();
  await expect(secretReadClipboard).toHaveCount(1);
  await secretCancel.click();
  await expect(secretOverlay).toHaveCount(0);
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'ApiKeyInput' })).text).toBe(originalKey);

  await activateControl(page, 'BtnPasteApiKey', true);
  await expect(secretOverlay).toHaveCount(1);
  await expect(secretInput).toBeFocused();
  const nativePasteStyle = await secretInput.evaluate(input => {
    const style = getComputedStyle(input);
    return {
      userSelect: style.getPropertyValue('user-select') || input.style.getPropertyValue('user-select'),
      webkitUserSelect: style.getPropertyValue('-webkit-user-select') || input.style.getPropertyValue('-webkit-user-select'),
      touchAction: style.getPropertyValue('touch-action') || input.style.getPropertyValue('touch-action'),
      masked: input.style.webkitTextSecurity
    };
  });
  expect(nativePasteStyle.userSelect === 'text' || nativePasteStyle.webkitUserSelect === 'text').toBe(true);
  expect(nativePasteStyle.touchAction).toBe('auto');
  expect(nativePasteStyle.masked).toBe('disc');
  await page.evaluate(() => {
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {
        readText: () => Promise.reject(new Error('permission denied for fallback regression'))
      }
    });
  });
  await secretReadClipboard.click();
  await expect(secretOverlay).toHaveCount(1);
  await expect(secretInput).toBeFocused();
  await expect(page.locator('#ptcg-native-secret-hint')).toContainText('无法直接读取');

  await page.evaluate(() => {
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {
        readText: () => Promise.resolve('sk-one-tap-clipboard-e2e')
      }
    });
  });
  await secretReadClipboard.click();
  await expect(secretInput).toHaveValue('sk-one-tap-clipboard-e2e');
  await secretConfirm.click();
  await expect(secretOverlay).toHaveCount(0);
  try {
    await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'ApiKeyInput' })).text).toBe('sk-one-tap-clipboard-e2e');
  } catch (error) {
    const diagnostics = await bridgeRequest(page, 'text_input_diagnostics', { id: 'ApiKeyInput' });
    throw new Error(`${error.message}\nGodot diagnostics: ${JSON.stringify(diagnostics)}`);
  }
  await scrollControlIntoView(page, 'BtnSave');
  await activateControl(page, 'BtnSave', true);
  await expect.poll(async () => {
    const probe = await bridgeRequest(page, 'settings_api_key_probe', { expected: 'sk-one-tap-clipboard-e2e' });
    return probe.input_matches && probe.saved_matches;
  }).toBe(true);
});

test('real canvas input round-trips battle setup and deck manager', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name.endsWith('landscape'), 'The landscape WebKit project is scoped to battle HUD touch regression');
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (message.type() === 'error' && message.text().includes('WEB_RUNTIME_ERROR')) errors.push(message.text());
  });
  await startGame(page, 'v2');
  const useTouch = testInfo.project.name.includes('touch');

  await activateControl(page, 'BtnStartBattle', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('BattleSetup');
  await activateControl(page, 'BtnBack', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('MainMenu');

	await activateControl(page, 'BtnDeckManager', useTouch);
	await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('DeckManager');
	const deckSearch = await bridgeRequest(page, 'find_control', { id: 'DeckSearchInput' });
	expect(deckSearch.visible).toBe(true);
	expect(deckSearch.rect.width).toBeGreaterThan(200);
	expect(deckSearch.rect.height).toBeGreaterThan(useTouch ? 70 : 30);
	const clearAtRest = await bridgeRequest(page, 'find_control', { id: 'DeckSearchClearButton' });
	expect(clearAtRest.visible).toBe(true);
	expect(clearAtRest.disabled).toBe(true);
	expect(clearAtRest.rect.height).toBeGreaterThan(useTouch ? 70 : 30);
	await activateControl(page, 'DeckSearchInput', useTouch);
	const localDeckEditor = page.locator('body > input').filter({ hasNot: page.locator('#canvas') });
	await expect(localDeckEditor).toHaveCount(1);
	// Wait beyond Godot Web IME's 100 ms focus tick before entering text.
	// Its hidden editor must not steal ownership from the DOM search field.
	await page.waitForTimeout(250);
	await expect(localDeckEditor).toBeFocused();
	await expect(page.locator('div.ime')).toBeHidden();
	await localDeckEditor.fill('Dragapult ex');
	expect(await page.evaluate(() => window.__ptcgDeckAgentTextInput ? window.__ptcgDeckAgentTextInput.version : 0)).toBe(11);
	if (useTouch) {
		await page.evaluate(() => {
			const state = window.__ptcgDeckAgentTextInput;
			const input = state && state.input;
			if (!input) throw new Error('Mobile deck-search DOM editor disappeared before IME deletion');
			input.focus();
			input.setSelectionRange(input.value.length, input.value.length);
			input.dispatchEvent(new InputEvent('beforeinput', {
				bubbles: true,
				cancelable: true,
				inputType: 'deleteContentBackward'
			}));
		});
	} else {
		await localDeckEditor.focus();
		await expect(localDeckEditor).toBeFocused();
		await page.keyboard.press('Backspace');
	}
	await expect(localDeckEditor).toHaveValue('Dragapult e');
	await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'DeckSearchInput' })).text).toBe('Dragapult e');
	await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'DeckSearchClearButton' })).disabled).toBe(false);
	await activateControl(page, 'DeckSearchClearButton', useTouch);
	await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'DeckSearchInput' })).text).toBe('');
	await expect.poll(async () => page.evaluate(() => {
		const state = window.__ptcgDeckAgentTextInput || null;
		return !state || !state.input || state.input.value === '';
	})).toBe(true);
	const recommendation = await bridgeRequest(page, 'find_control', { id: 'RecommendationFeedCard' });
	expect(recommendation.visible).toBe(true);
	await activateControl(page, 'BtnImport', useTouch);
	await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'UrlInput' })).visible).toBe(true);
	const importEditor = page.locator('body > input').filter({ hasNot: page.locator('#canvas') });
	await expect(importEditor).toHaveCount(1);
	const preparedState = await page.evaluate(() => {
		const state = window.__ptcgDeckAgentTextInput || null;
		return state ? {
			version: state.version,
			prepareCount: state.prepareCount,
			focused: document.activeElement === state.input,
		} : null;
	});
	expect(preparedState).not.toBeNull();
	expect(preparedState.version).toBe(11);
	expect(preparedState.prepareCount).toBeGreaterThan(0);
	expect(preparedState.focused).toBe(false);
	await importEditor.click();
	await expect(importEditor).toBeFocused();
	await importEditor.fill('574793');
	await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'UrlInput' })).text).toBe('574793');
	await activateControl(page, 'BtnCloseImport', useTouch);
	await expect(importEditor).toHaveCount(0);
	await activateControl(page, 'BtnBack', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('MainMenu');
  expect(errors).toEqual([]);
});

test('deck editor card search exposes HUD radios and filters ex cards', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium-desktop', 'DeckEditor is landscape-only on Web and this regression uses the desktop canvas');
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (message.type() === 'error' && message.text().includes('WEB_RUNTIME_ERROR')) errors.push(message.text());
  });
  await startGame(page, 'v2');
  await activateControl(page, 'BtnDeckManager', false);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('DeckManager');
  await activateVisibleNamedControl(page, 'DeckRowEditButton', false);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('DeckEditor');

  const searchButton = await bridgeRequest(page, 'find_control', { id: 'BtnCardSearch' });
  expect(searchButton.visible).toBe(true);
  expect(searchButton.rect.height).toBeGreaterThan(60);
  await activateControl(page, 'BtnCardSearch', false);

  const nameInput = await bridgeRequest(page, 'find_control', { id: 'DeckPoolSearchInput' });
  const category = await bridgeRequest(page, 'find_control', { id: 'DeckPoolSearchCategoryRadio0' });
  const exType = await bridgeRequest(page, 'find_control', { id: 'DeckPoolSearchTagRadio_ex' });
	const teraType = await bridgeRequest(page, 'find_control', { id: 'DeckPoolSearchTagRadio_Tera' });
  const energy = await bridgeRequest(page, 'find_control', { id: 'DeckPoolSearchEnergyRadio_All' });
	const grassEnergy = await bridgeRequest(page, 'find_control', { id: 'DeckPoolSearchEnergyRadio_G' });
  expect(nameInput.visible).toBe(true);
  expect(nameInput.rect.width).toBeGreaterThan(400);
  expect(nameInput.rect.height).toBeGreaterThan(40);
  for (const control of [category, exType, teraType, energy, grassEnergy]) {
    expect(control.visible).toBe(true);
    expect(control.rect.height).toBeGreaterThan(40);
  }

	await activateControl(page, 'DeckPoolSearchTagRadio_Tera', false);
	await activateControl(page, 'DeckPoolSearchEnergyRadio_G', false);
	await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'DeckPoolSearchResultLabel' })).text).toContain('找到 2 张');
	await activateControl(page, 'DeckPoolSearchEnergyRadio_All', false);
	await activateControl(page, 'DeckPoolSearchTagRadio_ex', false);

  await activateControl(page, 'DeckPoolSearchInput', false);
  const editor = page.locator('body > input').filter({ hasNot: page.locator('#canvas') });
  await expect(editor).toHaveCount(1);
  await editor.fill('ex');
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'DeckPoolSearchInput' })).text).toBe('ex');
  await page.evaluate(() => {
    const state = window.__ptcgDeckAgentTextInput;
    const callback = window.__ptcgDeckAgentTextInputCallback;
    if (state && state.input && typeof callback === 'function') {
      callback(JSON.stringify({ event: 'commit', value: state.input.value, id: state.id || 0 }));
    }
    if (state && typeof state.close === 'function') state.close();
  });
  const searchScreenshot = testInfo.outputPath('deck-editor-card-search.png');
  await page.screenshot({ path: searchScreenshot });
  await testInfo.attach('deck editor card search', { path: searchScreenshot, contentType: 'image/png' });
  await activateControl(page, 'DeckPoolSearchDoneButton', false);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('DeckEditor');
  expect(errors).toEqual([]);
});

test('blur cancels active pointer ownership and late release does not navigate', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium-desktop', 'Mouse down/up lifecycle probe is a desktop Chromium contract');
  await startGame(page, 'v2');
  const point = await semanticPoint(page, 'BtnStrategyHub');
  await page.mouse.move(point.x, point.y);
  await page.mouse.down();
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).active_pointers.length).toBe(1);
  await page.evaluate(() => window.dispatchEvent(new Event('blur')));
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).active_pointers.length).toBe(0);
  await page.mouse.up();
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('MainMenu');
});

test('iOS Web touch confirms modal and persistent battle HUD actions', async ({ page }, testInfo) => {
  test.skip(!testInfo.project.name.startsWith('webkit-touch'), 'This regression targets the iOS Safari touch pipeline');
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (message.type() === 'error' && message.text().includes('WEB_RUNTIME_ERROR')) errors.push(message.text());
  });
  await startGame(page, 'v2');
  await activateControl(page, 'BtnBattleReplay', true);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('DeckTrainingBrowser');

  const firstScenario = 'DeckTrainingScenarioStartButton_dragapult_gardevoir_01';
  if (testInfo.project.name.endsWith('landscape')) {
    await bridgeRequest(page, 'launch_deck_training', { scenario_id: 'dragapult_gardevoir_01' });
  } else {
    await scrollControlIntoView(page, firstScenario);
    await activateControl(page, firstScenario, true);
  }
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('BattleScene');
  await expect.poll(async () => {
    try {
      return (await bridgeRequest(page, 'find_control', { id: 'StageIntroConfirmButton' })).visible;
    } catch (_error) {
      return false;
    }
  }).toBe(true);

  await activateControl(page, 'StageIntroConfirmButton', true);
  await expect.poll(async () => {
    try {
      return (await bridgeRequest(page, 'find_control', { id: 'StageIntroConfirmButton' })).visible;
    } catch (_error) {
      return false;
    }
  }).toBe(false);

  const handFixture = await bridgeRequest(page, 'prepare_battle_hand_fixture');
  expect(handFixture.card_name).toMatch(/高级球|Ultra Ball/);
  expect(handFixture.ios_web_touch_profile).toBe(true);
  await page.waitForTimeout(150);
  await activateControl(page, 'E2EHandUltraBall', true);
  await expect.poll(async () => (await bridgeRequest(page, 'battle_hud_probe')).detail_visible).toBe(true);
  await activateControl(page, 'DetailCancelButton', true);
  await expect.poll(async () => (await bridgeRequest(page, 'battle_hud_probe')).detail_visible).toBe(false);

  for (let cycleIndex = 0; cycleIndex < 8; cycleIndex += 1) {
    const turnCycle = await bridgeRequest(page, 'cycle_battle_hand_fixture_turn');
    expect(turnCycle.scheduled).toBe(true);
    await expect.poll(async () => {
      try {
        const control = await bridgeRequest(page, 'find_control', { id: 'E2EHandUltraBall' });
        const probe = await bridgeRequest(page, 'battle_hud_probe');
        return `${control.visible}:${probe.current_player_index}`;
      } catch (_error) {
        return 'false:-1';
      }
    }).toBe(`true:${turnCycle.player_index}`);
    await page.waitForTimeout(80);
    await activateControl(page, 'E2EHandUltraBall', true);
    await expect.poll(async () => (await bridgeRequest(page, 'battle_hud_probe')).detail_visible).toBe(true);
    await activateControl(page, 'DetailCancelButton', true);
    await expect.poll(async () => (await bridgeRequest(page, 'battle_hud_probe')).detail_visible).toBe(false);
  }

  const pokemonHud = await bridgeRequest(page, 'prepare_battle_hud_fixture', { kind: 'pokemon_action' });
  expect(pokemonHud.pending_choice).toBe('pokemon_action');
  expect(pokemonHud.dialog_visible).toBe(true);
  await page.waitForTimeout(150);
  await activateControl(page, 'DialogCancel', true);
  await expect.poll(async () => {
    const state = await bridgeRequest(page, 'battle_hud_probe');
    return `${state.pending_choice}:${state.dialog_visible}`;
  }).toBe(':false');

  const cardCancelHud = await bridgeRequest(page, 'prepare_battle_hud_fixture', { kind: 'card_detail' });
  expect(cardCancelHud.detail_visible).toBe(true);
  expect(cardCancelHud.detail_action_bar_visible).toBe(true);
  expect(cardCancelHud.selected_hand_card).toBe(true);
  await page.waitForTimeout(150);
  await activateControl(page, 'DetailCancelButton', true);
  await expect.poll(async () => {
    const state = await bridgeRequest(page, 'battle_hud_probe');
    return `${state.detail_visible}:${state.selected_hand_card}`;
  }).toBe('false:false');

  const cardUseHud = await bridgeRequest(page, 'prepare_battle_hud_fixture', { kind: 'card_detail' });
  expect(cardUseHud.detail_visible).toBe(true);
  expect(cardUseHud.detail_action_bar_visible).toBe(true);
  await page.waitForTimeout(150);
  await activateControl(page, 'DetailUseButton', true);
  await expect.poll(async () => {
    const state = await bridgeRequest(page, 'battle_hud_probe');
    return `${state.detail_visible}:${state.selected_hand_card}`;
  }).toBe('false:true');

  await activateControl(page, 'BtnZeusHelp', true);
  await expect.poll(async () => {
    try {
      return (await bridgeRequest(page, 'find_control', { id: 'StageHelpGuideButton' })).visible;
    } catch (_error) {
      return false;
    }
  }).toBe(true);
  expect(errors).toEqual([]);
});

test('Chromium touch hand survives twenty semantic generations with first-tap success', async ({ page }, testInfo) => {
  test.setTimeout(300000);
  test.skip(testInfo.project.name !== 'chromium-touch', 'This regression targets Android-style Chromium touch');
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (message.type() === 'error' && message.text().includes('WEB_RUNTIME_ERROR')) errors.push(message.text());
  });
  await startGame(page, 'v2');
  await activateControl(page, 'BtnBattleReplay', true);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('DeckTrainingBrowser');
  await bridgeRequest(page, 'launch_deck_training', { scenario_id: 'dragapult_gardevoir_01' });
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('BattleScene');
  let introVisible = false;
  try {
    introVisible = (await bridgeRequest(page, 'find_control', { id: 'StageIntroConfirmButton' })).visible;
  } catch (_error) {
    introVisible = false;
  }
  if (introVisible) await activateControl(page, 'StageIntroConfirmButton', true);

  const handFixture = await bridgeRequest(page, 'prepare_battle_hand_fixture');
  expect(handFixture.pointer_surface_enabled).toBe(true);
  expect(handFixture.ios_web_touch_profile).toBe(false);
  let previousGeneration = handFixture.hand_generation;

  for (let cycleIndex = 0; cycleIndex < 20; cycleIndex += 1) {
    if (cycleIndex % 5 === 0) console.log(`TOUCH_GENERATION_PROGRESS: ${cycleIndex}/20`);
    const turnCycle = await bridgeRequest(page, 'cycle_battle_hand_fixture_turn');
    await expect.poll(async () => {
      try {
        const control = await bridgeRequest(page, 'find_control', { id: 'E2EHandUltraBall' });
        const probe = await bridgeRequest(page, 'battle_hud_probe');
        return `${control.visible}:${probe.current_player_index}`;
      } catch (_error) {
        return 'false:-1';
      }
    }).toBe(`true:${turnCycle.player_index}`);
    const readyProbe = await bridgeRequest(page, 'battle_hud_probe');
    expect(readyProbe.hand_generation).toBeGreaterThan(previousGeneration);
    previousGeneration = readyProbe.hand_generation;

    await activateControl(page, 'E2EHandUltraBall', true);
    await expect.poll(async () => (await bridgeRequest(page, 'battle_hud_probe')).detail_visible).toBe(true);
    // The fixture may be read-only depending on the scenario phase; the
    // persistent close button exercises the same overlay lifecycle.
    await activateControl(page, 'DetailCloseBtn', true);
    await page.waitForTimeout(350);
    const closeProbe = await bridgeRequest(page, 'battle_hud_probe');
    expect(closeProbe).toMatchObject({
      detail_visible: false,
      active_surface_gestures: 0
    });
  }

  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).active_pointers.length).toBe(0);
  expect(errors).toEqual([]);
});

test('legacy kill switch starts the same production UI', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium-desktop', 'Kill-switch smoke only needs one browser engine');
  await startGame(page, 'legacy');
  const snapshot = await bridgeRequest(page, 'snapshot');
  expect(snapshot.scene).toBe('MainMenu');
  await activateControl(page, 'BtnStrategyHub', false);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('StrategyHub');
  await activateControl(page, 'AISettingsTab', false);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('StrategyHub');
});

test('AI ladder shows ranked authors and opens and closes strategy details', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name.endsWith('landscape'), 'Landscape battle HUD has a separate regression');
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  await startGame(page, 'v2');
  const items = [1, 2, 3, 4].map(rank => ({
    rank, profile_id: 'godot_v18_ladder_v1', release_id: `ui-ladder-${rank}`,
    developer_id: `ui-author-${rank}`, owner_id: `ui-author-${rank}`, owner_kind: 'developer',
    competition_conflict_group: `ui-group-${rank}`, release_source_kind: 'developer_ptcgai',
    runtime_kind: 'godot_restricted_ptcgai_v1', state: 'active',
    uploaded_at_epoch: 100, next_due_at_epoch: 200, last_series_at_epoch: 150,
    rated_series_count: 20, actual_game_count: 40, mu: (1500 - rank).toFixed(6), sigma: '100.000000',
    provisional: rank === 1, display_name: `天梯策略 ${rank}`, author_display_name: `荣誉开发者 ${rank}`
  }));
  await page.route('**/v1/ladder/leaderboard', route => route.fulfill({
    contentType: 'application/json',
    // The public service contract requires canonical JSON, including recursively sorted keys.
    body: JSON.stringify({ document_type: 'godot_v18_release_leaderboard_v1', profile_id: 'godot_v18_ladder_v1', items },
      (_key, value) => value && typeof value === 'object' && !Array.isArray(value)
        ? Object.fromEntries(Object.keys(value).sort().map(key => [key, value[key]])) : value)
  }));
  const useTouch = testInfo.project.name.includes('touch');
  await activateControl(page, 'BtnStrategyHub', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('StrategyHub');
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'CatalogTab' })).text).toBe('AI天梯');
  await expect.poll(async () => (await bridgeRequest(page, 'list_controls'))
    .filter(control => control.name === 'ContinuousLadderReleaseButton').length).toBe(4);
  const controls = await bridgeRequest(page, 'list_controls');
  const rankedCards = controls.filter(control => control.name === 'ContinuousLadderReleaseButton').sort((a, b) => a.rect.y - b.rect.y);
  expect(rankedCards).toHaveLength(4);
  const expectedRanks = ['#1 · 榜首', '#2 · 第二名', '#3 · 第三名', '#4'];
  for (const [index, card] of rankedCards.entries()) {
    expect(card.text).toContain(`荣誉开发者 ${index + 1}`);
    // Repeated cards share node names: address each actual path, not the last matching node.
    const parent = card.path.slice(0, card.path.lastIndexOf('/'));
    let rankLabel;
    for (const container of [parent, parent.slice(0, parent.lastIndexOf('/'))]) {
      try { rankLabel = await bridgeRequest(page, 'find_control', { id: `${container}/LadderRankLabel` }); break; }
      catch (_error) { /* Desktop inserts an action row; phone uses the vertical content directly. */ }
    }
    expect(rankLabel?.text).toBe(expectedRanks[index]);
  }
  await page.screenshot({ path: testInfo.outputPath('ai-ladder.png') });
  await activateControl(page, rankedCards[0].path, useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'find_control', { id: 'CloseStrategyDetailButton' })).visible).toBe(true);
  await activateControl(page, 'CloseStrategyDetailButton', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'list_controls'))
    .some(control => control.name === 'CloseStrategyDetailButton')).toBe(false);
  expect(errors).toEqual([]);
});
