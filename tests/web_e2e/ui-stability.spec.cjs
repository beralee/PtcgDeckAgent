const { test, expect } = require('@playwright/test');

async function bridgeRequest(page, command, payload = {}) {
  const requestId = await page.evaluate(({ command, payload }) => window.__PTCG_TEST__.request(command, payload), { command, payload });
  await page.waitForFunction(id => {
    const value = window.__PTCG_TEST__ && window.__PTCG_TEST__.result(id);
    return value && value.done === true;
  }, requestId);
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

async function activateControl(page, id, useTouch) {
  const point = await semanticPoint(page, id);
  if (useTouch) await page.touchscreen.tap(point.x, point.y);
  else await page.mouse.click(point.x, point.y);
}

test('real canvas input navigates main menu and settings without runtime errors', async ({ page }, testInfo) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (message.type() === 'error' && message.text().includes('WEB_RUNTIME_ERROR')) errors.push(message.text());
  });
  await startGame(page, 'v2');
  const initial = await bridgeRequest(page, 'snapshot');
  expect(initial.runtime_profile.host_kind).toBe('web');
  const useTouch = testInfo.project.name.includes('touch');
  await activateControl(page, 'BtnSettings', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('Settings');
  await activateControl(page, 'BtnBack', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('MainMenu');
  expect(errors).toEqual([]);
});

test('real canvas input round-trips battle setup and deck manager', async ({ page }, testInfo) => {
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
  await activateControl(page, 'BtnBack', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('MainMenu');
  expect(errors).toEqual([]);
});

test('blur cancels active pointer ownership and late release does not navigate', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium-desktop', 'Mouse down/up lifecycle probe is a desktop Chromium contract');
  await startGame(page, 'v2');
  const point = await semanticPoint(page, 'BtnSettings');
  await page.mouse.move(point.x, point.y);
  await page.mouse.down();
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).active_pointers.length).toBe(1);
  await page.evaluate(() => window.dispatchEvent(new Event('blur')));
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).active_pointers.length).toBe(0);
  await page.mouse.up();
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('MainMenu');
});

test('legacy kill switch starts the same production UI', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium-desktop', 'Kill-switch smoke only needs one browser engine');
  await startGame(page, 'legacy');
  const snapshot = await bridgeRequest(page, 'snapshot');
  expect(snapshot.scene).toBe('MainMenu');
  await activateControl(page, 'BtnSettings', false);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('Settings');
});
