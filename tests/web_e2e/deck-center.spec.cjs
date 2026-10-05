const { test, expect } = require('@playwright/test');

async function read(page, command, payload = {}) {
  const id = await page.evaluate(({ command, payload }) => window.__PTCG_TEST__.request(command, payload), { command, payload });
  await page.waitForFunction(id => window.__PTCG_TEST__.result(id)?.done, id);
  const result = await page.evaluate(id => window.__PTCG_TEST__.consume(id), id);
  if (!result.ok) throw new Error(result.error);
  return result.value;
}

async function visibleControl(page, name, text) {
  const controls = await read(page, 'list_controls');
  const snapshot = await read(page, 'snapshot');
  const view = snapshot.runtime_profile.viewport_size;
  const width = view.x || view.width, height = view.y || view.height;
  if (name && !controls.some(item => item.name === name)) {
    let named;
    try {
      named = await read(page, 'find_control', { id: name });
    } catch (error) {
      // Lists are rendered across frames. An absent control is a pending
      // condition for expect.poll, not a transport or runtime failure.
      if (error.message === 'control not found') return null;
      throw error;
    }
    if (named.name) controls.push(named);
  }
  const control = controls.filter(item => item.visible && !item.disabled && (name ? item.name === name : item.text === text))
    .filter(item => item.rect.y + item.rect.height / 2 > 0 && item.rect.y + item.rect.height / 2 < height)
    .sort((a, b) => a.rect.y - b.rect.y)[0];
  if (!control) return null;
  const canvas = await page.locator('#canvas').boundingBox();
  return { ...control, point: { x: canvas.x + (control.rect.x + control.rect.width / 2) * canvas.width / width,
    y: canvas.y + (control.rect.y + control.rect.height / 2) * canvas.height / height },
    physicalHeight: control.rect.height * canvas.height / height };
}

async function activate(page, name, touch, text) {
  let control;
  await expect.poll(async () => { control = await visibleControl(page, name, text); return !!control; }).toBe(true);
  // Allow the next layout frame to settle, then use a real pointer on the canvas.
  await page.waitForTimeout(150);
  control = await visibleControl(page, name, text);
  if (touch) await page.touchscreen.tap(control.point.x, control.point.y);
  else await page.mouse.click(control.point.x, control.point.y);
}

async function label(page, name) {
  const control = await read(page, 'find_control', { id: name });
  return control.visible ? control.text || '' : '';
}

async function swipe(page, origin, delta) {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [origin] });
  for (let step = 1; step <= 10; step++) {
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: origin.x + delta.x * step / 10, y: origin.y + delta.y * step / 10 }] });
  }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await cdp.detach();
}

async function scrollWithoutWheel(page, name) {
  const state = () => read(page, 'find_control', { id: name });
  await expect.poll(async () => (await state()).scroll_max).toBeGreaterThan(0);
  const scroll = await state();
  const viewport = (await read(page, 'snapshot')).runtime_profile.viewport_size;
  const canvas = await page.locator('#canvas').boundingBox();
  const sx = canvas.width / (viewport.x || viewport.width);
  const sy = canvas.height / (viewport.y || viewport.height);
  const x = canvas.x + (scroll.rect.x + scroll.rect.width) * sx - 11;
  const y = canvas.y + scroll.rect.y * sy;
  const height = scroll.rect.height * sy;
  await page.mouse.click(x, y + height - 8);
  await expect.poll(async () => (await state()).scroll_vertical).toBeGreaterThan(0);
  await page.keyboard.press('Home');
  await expect.poll(async () => (await state()).scroll_vertical).toBe(0);
  await page.keyboard.press('PageDown');
  await expect.poll(async () => (await state()).scroll_vertical).toBeGreaterThan(0);
  await page.keyboard.press('End');
  await expect.poll(async () => { const value = await state(); return Math.abs(value.scroll_vertical - value.scroll_max); }).toBeLessThanOrEqual(1);
  await page.keyboard.press('Home');
  await page.mouse.move(x, y + 18);
  await page.mouse.down();
  await page.mouse.move(x, y + height * 0.8, { steps: 12 });
  await page.mouse.up();
  await expect.poll(async () => (await state()).scroll_vertical).toBeGreaterThan(0);
  await page.keyboard.press('Home');
  await expect.poll(async () => (await state()).scroll_vertical).toBe(0);
}

async function expectDiscoveryActionsInsideStage(page) {
  const stage = (await read(page, 'find_control', { id: 'DiscoverySlideStage' })).rect;
  for (const name of ['RecommendationDetailButton', 'RecommendationImportButton']) {
    const button = await visibleControl(page, name);
    expect(button, name).not.toBeNull();
    expect(button.physicalHeight, name).toBeGreaterThanOrEqual(47.5);
    expect(button.rect.y, `${name} top`).toBeGreaterThanOrEqual(stage.y - 1);
    expect(button.rect.y + button.rect.height, `${name} bottom clipped`).toBeLessThanOrEqual(stage.y + stage.height + 1);
  }
}

test('discovery slides with posters, touch swipes and the original editor', async ({ page }, info) => {
  const touch = info.project.name.includes('touch');
  const portrait = info.project.name === 'portrait-touch';
  const errors = [];
  page.on('console', message => { if (/SCRIPT ERROR|WEB_RUNTIME_ERROR/.test(message.text())) errors.push(message.text()); });
  page.on('pageerror', error => errors.push(String(error)));
  await page.route(/https?:\/\/(?:[^/]+\.)?skillserver\.cn\/.*/, route => route.fulfill({ contentType: 'application/json', body: '{}' }));
  await page.goto('/PtcgDeckAgent.html?web_ui_adapter=v2');
  await page.locator('#start-game').click();
  await page.waitForFunction(() => window.__PTCG_TEST__, null, { timeout: 90000 });
  await expect.poll(async () => (await read(page, 'snapshot')).scene).toBe('MainMenu');
  await activate(page, 'BtnDeckManager', touch);
  await expect.poll(async () => (await read(page, 'snapshot')).scene).toBe('DeckManager');
  await expect.poll(async () => !!(await visibleControl(page, 'DeckRowMoreButton'))).toBe(true);
  const more = await visibleControl(page, 'DeckRowMoreButton');
  expect(more.physicalHeight).toBeGreaterThanOrEqual(47.5);
  if (portrait) expect(more.text).toBe('更多操作');
  expect(await visibleControl(page, 'RecommendationDetailButton')).not.toBeNull();
  await activate(page, 'DiscoveryPauseButton', touch);
  if (touch) {
    const initial = (await read(page, 'find_control', { id: 'DiscoverySlideStage' })).rect;
    const poster = await visibleControl(page, 'RecommendationPosterFrame');
    const title = await label(page, 'RecommendationDeckName');
    await swipe(page, poster.point, { x: 0, y: -90 });
    await expect.poll(async () => (await read(page, 'find_control', { id: 'DeckScroll' })).scroll_vertical).toBeGreaterThan(0);
    expect((await read(page, 'find_control', { id: 'DiscoverySlideStage' })).rect.y).toBeLessThan(initial.y - 30);
    expect(await label(page, 'RecommendationDeckName')).toBe(title);
    expect((await read(page, 'snapshot')).scene).toBe('DeckManager');
    await swipe(page, { x: 250, y: 180 }, { x: 0, y: 160 });
    await expect.poll(async () => (await read(page, 'find_control', { id: 'DeckScroll' })).scroll_vertical).toBe(0);
  }
  if (!touch) {
    await scrollWithoutWheel(page, 'DeckScroll');
    await page.setViewportSize({ width: 520, height: 860 });
    await page.waitForTimeout(700);
    await scrollWithoutWheel(page, 'DeckScroll');
    await page.screenshot({ path: info.outputPath('narrow-desktop-scroll.png') });
    await page.setViewportSize({ width: 1360, height: 860 });
    await page.waitForTimeout(700);
  }
  const firstTitle = await label(page, 'RecommendationDeckName');
  await activate(page, 'RecommendationNextButton', touch);
  await page.waitForTimeout(120);
  await page.screenshot({ path: info.outputPath('carousel-moving.png') });
  await expect.poll(() => label(page, 'RecommendationDeckName')).not.toBe(firstTitle);
  await page.waitForTimeout(500);
  await expectDiscoveryActionsInsideStage(page);
  await activate(page, 'RecommendationDetailButton', touch);
  await expect.poll(async () => !!(await visibleControl(page, 'RecommendationDetailCloseButton'))).toBe(true);
  if (touch) {
    const articleSize = page.viewportSize();
    // The bundled article fits in landscape. Rotate to make it overflow so
    // this swipe proves scrolling, then restore the original orientation.
    if (!portrait) {
      await page.setViewportSize({ width: 390, height: 844 });
      await page.waitForTimeout(700);
    }
    const article = await visibleControl(page, 'RecommendationDetailScroll');
    await page.touchscreen.tap(article.point.x, article.point.y);
    expect((await read(page, 'snapshot')).scene).toBe('DeckManager');
    await swipe(page, article.point, { x: 0, y: -100 });
    await expect.poll(async () => (await read(page, 'find_control', { id: 'RecommendationDetailScroll' })).scroll_vertical).toBeGreaterThan(0);
    await page.screenshot({ path: info.outputPath('article-scrolled.png') });
    if (!portrait) {
      await page.setViewportSize(articleSize);
      await page.waitForTimeout(700);
    }
  }
  if (!touch) {
    // This article fits a wide desktop window. Use a narrow window so the
    // reader actually overflows and must be navigated without a wheel.
    await page.setViewportSize({ width: 520, height: 860 });
    await page.waitForTimeout(700);
    await scrollWithoutWheel(page, 'RecommendationDetailScroll');
    await page.setViewportSize({ width: 1360, height: 860 });
    await page.waitForTimeout(700);
  }
  await activate(page, 'RecommendationDetailCloseButton', touch);
  await expect.poll(async () => (await read(page, 'list_controls')).some(c => c.name === 'RecommendationDetailCloseButton' && c.visible)).toBe(false);
  await page.waitForTimeout(400);
  await activate(page, 'RecommendationImportButton', touch);
  await expect.poll(async () => !!(await visibleControl(page, 'BtnCloseImport'))).toBe(true);
  await activate(page, 'BtnCloseImport', touch);
  await expect.poll(async () => (await read(page, 'list_controls')).some(c => c.name === 'BtnCloseImport' && c.visible)).toBe(false);
  await page.waitForTimeout(400);
  await activate(page, 'RecommendationPreviousButton', touch);
  await expect.poll(() => label(page, 'RecommendationDeckName')).toBe(firstTitle);
  await page.waitForTimeout(600);
  if (touch) {
    const poster = await visibleControl(page, 'RecommendationPosterFrame');
    const cdp = await page.context().newCDPSession(page);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [poster.point] });
    for (let step = 1; step <= 8; step++) {
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: poster.point.x - step * 9, y: poster.point.y }] });
    }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await cdp.detach();
    await expect.poll(() => label(page, 'RecommendationDeckName')).not.toBe(firstTitle);
    await page.waitForTimeout(600);
  }
  await activate(page, 'RecommendationPosterFrame', touch);
  await expect.poll(async () => !!(await visibleControl(page, 'DiscoveryPosterCloseButton'))).toBe(true);
  await page.screenshot({ path: info.outputPath('poster.png') });
  await activate(page, 'DiscoveryPosterCloseButton', touch);
  await page.screenshot({ path: info.outputPath('center.png') });
  const library = await read(page, 'find_control', { id: 'DeckLibrary' });
  const viewport = (await read(page, 'snapshot')).runtime_profile.viewport_size;
  expect(library.rect.width).toBeGreaterThan((viewport.x || viewport.width) * (touch ? 0.82 : 0.90));
  await activate(page, 'DeckRowInfoButton', touch);
  await expect.poll(async () => !!(await visibleControl(page, 'CenterDetailBackButton'))).toBe(true);
  if (!touch) await scrollWithoutWheel(page, 'CenterDetailScroll');
  await page.screenshot({ path: info.outputPath('full-deck.png') });
  await activate(page, 'CenterDetailBackButton', touch);
  await activate(page, 'DeckRowViewButton', touch);
  await expect.poll(async () => !!(await visibleControl(page, 'CenterDetailBackButton'))).toBe(true);
  await activate(page, 'CenterDetailBackButton', touch);
  await activate(page, 'DeckRowMoreButton', touch);
  await expect.poll(async () => !!(await visibleControl(page, 'DeckRowRenameButton'))).toBe(true);
  expect((await visibleControl(page, 'DeckRowDeleteButton')).physicalHeight).toBeGreaterThanOrEqual(47.5);
  await page.screenshot({ path: info.outputPath('more.png') });
  const originalSize = page.viewportSize();
  await page.setViewportSize(portrait ? { width: 844, height: 390 } : { width: 390, height: 844 });
  await page.waitForTimeout(700);
  await expect.poll(async () => (await visibleControl(page, 'DeckRowDeleteButton'))?.physicalHeight || 0).toBeGreaterThanOrEqual(47.5);
  await page.setViewportSize(originalSize);
  await page.waitForTimeout(700);
  await activate(page, null, touch, '取消');
  await page.waitForTimeout(400); // Existing close quarantine deliberately rejects the touch tail.
  await activate(page, 'DeckRowEditButton', touch);
  if (portrait) {
    await expect.poll(async () => !!(await visibleControl(page, 'WebDeckEditContinueButton'))).toBe(true);
    await page.setViewportSize({ width: 844, height: 390 });
    await page.waitForTimeout(700);
    await activate(page, 'WebDeckEditContinueButton', touch);
  }
  await expect.poll(async () => (await read(page, 'snapshot')).scene).toBe('DeckEditor');
  await expect.poll(async () => (await read(page, 'find_control', { id: 'BtnReplace' })).visible).toBe(true);
  expect((await read(page, 'list_controls')).some(item => item.name === 'EditorUndoButton')).toBe(false);
  await page.screenshot({ path: info.outputPath('original-editor.png') });
  expect(errors).toEqual([]);
});
