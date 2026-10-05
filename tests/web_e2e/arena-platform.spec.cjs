const { test, expect } = require('@playwright/test');
const { execFileSync } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');

async function request(page, command, payload = {}) {
  const id = await page.evaluate(({ command, payload }) => window.__PTCG_TEST__.request(command, payload), { command, payload });
  await page.waitForFunction(id => window.__PTCG_TEST__.result(id)?.done, id, { timeout: 10000 });
  const result = await page.evaluate(id => window.__PTCG_TEST__.consume(id), id);
  expect(result.ok, result.error).toBe(true);
  return result.value;
}

async function renderBackend(page, info, label) {
  const backend = await page.evaluate(() => {
    const gl = document.querySelector('#canvas').getContext('webgl2');
    const debug = gl.getExtension('WEBGL_debug_renderer_info');
    return { renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER),
      vendor: debug ? gl.getParameter(debug.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR) };
  });
  await info.attach(`${label}-render-backend`, { body: JSON.stringify(backend), contentType: 'application/json' });
  fs.writeFileSync(info.outputPath(`${label}-backend.json`), JSON.stringify(backend));
  expect(backend.renderer, 'Hardware acceptance cannot silently use a software GPU').not.toMatch(/swiftshader|llvmpipe|software/i);
}

test('Portable 3D accepts real input and redraws after rotation', async ({ page }, info) => {
  const errors = [];
  page.on('console', msg => { if (/SCRIPT ERROR|ERROR:|WebGL.*INVALID_OPERATION/.test(msg.text())) { errors.push(msg.text()); console.log(msg.text()); } });
  page.on('pageerror', e => errors.push(String(e)));
  await page.route(/https?:\/\/(?:[^/]+\.)?skillserver\.cn\/.*/, route => route.fulfill({ status: 200, contentType: 'application/json', body: '{}' }));
  await page.goto('/PtcgDeckAgent.html?web_ui_adapter=v2', { waitUntil: 'domcontentloaded' });
  // Godot's capability check deliberately loses a disposable probe context.
  // Only context loss on the actual game canvas is a rendering failure.
  await page.evaluate(() => {
    window.__arenaCanvasContextLost = false;
    document.querySelector('#canvas').addEventListener('webglcontextlost', () => { window.__arenaCanvasContextLost = true; });
  });
  await page.locator('#start-game').click();
  await page.waitForFunction(() => window.__PTCG_TEST__, null, { timeout: 90000 });
  await expect.poll(async () => (await request(page, 'snapshot')).scene).toBe('MainMenu');
  console.log('Battle platform: engine ready');
  await request(page, 'prepare_arena_fixture');
  await expect.poll(async () => {
    return (await request(page, 'arena_probe')).ready;
  }, { timeout: 20000 }).toBe(true);
  console.log('Battle platform: fixture ready');
  const touch = !!info.project.use.hasTouch;
  const activate = async key => {
    let state, previous, stable = 0;
    await expect.poll(async () => {
      state = await request(page, 'arena_probe');
      const geometry = JSON.stringify([state.points[key], state.width, state.height]);
      stable = geometry === previous ? stable + 1 : 0;
      previous = geometry;
      return stable >= 2 && state.points[key].x > 1 && state.points[key].y > 1;
    }, { intervals: [40] }).toBe(true);
    const rect = await page.locator('#canvas').boundingBox();
    const point = state.points[key];
    const x = rect.x + point.x * rect.width / state.width;
    const y = rect.y + point.y * rect.height / state.height;
    expect(x).toBeGreaterThanOrEqual(rect.x);
    expect(x).toBeLessThanOrEqual(rect.x + rect.width);
    expect(y).toBeGreaterThanOrEqual(rect.y);
    expect(y).toBeLessThanOrEqual(rect.y + rect.height);
    if (touch) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
  };
  for (const orientation of ['initial', 'rotated']) {
    console.log(`Battle platform: ${orientation}`);
    if (orientation === 'rotated') {
      const size = page.viewportSize();
      await page.setViewportSize({ width: size.height, height: size.width });
      await expect.poll(async () => (await request(page, 'arena_probe')).portrait).toBe(size.width > size.height);
      await page.waitForTimeout(800);
    }
    let state = await request(page, 'arena_probe');
    expect(state.production_3d_available).toBe(true);
    expect(state.production_3d_selected).toBe(true);
    expect(state.fixture_3d).toBe(true);
    expect(state.low).toBe(true);
    expect(Math.max(state.render_width, state.render_height)).toBeLessThanOrEqual(960);
    expect(state.excluded_3d_media_absent).toBe(true);
    const board = info.outputPath(`${orientation}-board.png`);
    const actions = info.outputPath(`${orientation}-actions.png`);
    await page.screenshot({ path: board });
    if (state.compact) {
      expect(state.compact_toolbars_removed).toBe(true);
      expect(state.status_entries).toBe(5);
      expect(state.status_inside).toBe(true);
      expect(state.board_below_status).toBe(true);
      await activate('status_exit');
      await expect.poll(async () => (await request(page, 'arena_probe')).choice).toBe('confirm_exit');
      await activate('confirm_exit_cancel');
      await expect.poll(async () => (await request(page, 'arena_probe')).choice).toBe('');
    }
    await activate('my_active');
    await expect.poll(async () => (await request(page, 'arena_probe')).choice).toBe('pokemon_action');
    let pixels;
    await expect.poll(async () => {
      await page.screenshot({ path: actions });
      pixels = JSON.parse(execFileSync('python', [path.join(__dirname, 'check_frame_change.py'), board, actions], { encoding: 'utf8', timeout: 10000 }));
      return pixels.color_deviation > 6 && pixels.changed_fraction > 0.002;
    }, { timeout: 8000, message: 'The action dialog must actually repaint the canvas' }).toBe(true);
    await info.attach(`${orientation}-pixel-check`, { body: JSON.stringify(pixels), contentType: 'application/json' });
    await activate('_dialog_cancel');
    await expect.poll(async () => (await request(page, 'arena_probe')).choice).toBe('');
  }
  await info.attach('engine-errors', { body: JSON.stringify(errors), contentType: 'application/json' });
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__arenaCanvasContextLost)).toBe(false);
});

test('Portable 3D stays within the paired 2D frame budget', async ({ browser }, info) => {
  test.setTimeout(240000);
  const reports = {};
  const errors = [];
  const contextKeys = ['baseURL', 'viewport', 'screen', 'deviceScaleFactor', 'isMobile', 'hasTouch', 'userAgent', 'locale', 'colorScheme'];
  const contextOptions = Object.fromEntries(contextKeys.filter(key => key in info.project.use).map(key => [key, info.project.use[key]]));
  for (const mode of ['2d', '3d']) {
    // Match the native runner's isolated user data and release the old engine
    // before starting its pair. Reusing the same WebKit page showed startup
    // stalls over a minute; the two runs must not share persistent user state.
    const context = await browser.newContext(contextOptions);
    const page = await context.newPage();
    const started = Date.now();
    page.on('console', msg => { if (/SCRIPT ERROR|ERROR:|WebGL.*INVALID_OPERATION/.test(msg.text())) errors.push(`${mode}: ${msg.text()}`); });
    page.on('pageerror', error => errors.push(`${mode}: ${error}`));
    try {
      await page.route(/https?:\/\/(?:[^/]+\.)?skillserver\.cn\/.*/, route => route.fulfill({ status: 200, contentType: 'application/json', body: '{}' }));
      await page.goto('/PtcgDeckAgent.html?web_ui_adapter=v2', { waitUntil: 'domcontentloaded' });
      await page.locator('#start-game').click();
      await page.waitForFunction(() => window.__PTCG_TEST__, null, { timeout: 90000 });
      await expect.poll(async () => (await request(page, 'snapshot')).scene).toBe('MainMenu');
      console.log(`Arena performance: ${mode} engine ready after ${Date.now() - started} ms`);
      await renderBackend(page, info, mode);
      await request(page, 'prepare_arena_performance', { mode });
      await expect.poll(async () => {
        reports[mode] = await request(page, 'arena_performance_result');
        return reports[mode].cases?.length;
      }, { timeout: 90000, intervals: [1500] }).toBe(2);
      fs.writeFileSync(info.outputPath(`${mode}.json`), JSON.stringify(reports[mode]));
      await page.screenshot({ path: info.outputPath(`${mode}.png`) });
      console.log(`Arena performance: ${mode} complete after ${Date.now() - started} ms`);
    } catch (error) {
      await page.screenshot({ path: info.outputPath(`${mode}-failure.png`) }).catch(() => {});
      throw error;
    } finally {
      await context.close();
    }
  }
  await info.attach('engine-errors', { body: JSON.stringify(errors), contentType: 'application/json' });
  // Still fail on rendering errors, but retain the independent timing verdict.
  expect.soft(errors).toEqual([]);
  const comparison = info.outputPath('comparison.json');
  // Same validator and fixed gates as the native/emulator runner; no browser-only waiver.
  try {
    execFileSync('python', [path.resolve(__dirname, '../../tools/arena3d/compare_render_performance.py'),
      info.outputPath('2d.json'), info.outputPath('3d.json'), '--output', comparison], { timeout: 10000 });
  } finally {
    if (fs.existsSync(comparison)) await info.attach('paired-performance', { path: comparison, contentType: 'application/json' });
  }
});

