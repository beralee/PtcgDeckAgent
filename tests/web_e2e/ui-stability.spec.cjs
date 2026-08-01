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
  if (process.env.PTCG_E2E_POINTER_DIAGNOSTICS === '1') {
    const control = await bridgeRequest(page, 'find_control', { id });
    const snapshot = await bridgeRequest(page, 'snapshot');
    const canvas = await page.locator('#canvas').boundingBox();
    console.log('POINTER_DIAGNOSTIC', JSON.stringify({ id, point, control, viewport: snapshot.runtime_profile.viewport_size, canvas }));
  }
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
    await page.mouse.move(canvas.x + canvas.width * 0.5, canvas.y + canvas.height * 0.75);
    await page.mouse.wheel(0, centerY > logicalHeight ? 650 : -650);
    await page.waitForTimeout(80);
  }
  throw new Error(`Control did not scroll into view: ${id}`);
}

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
  await activateControl(page, 'BtnSettings', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('Settings');
  await activateControl(page, 'BtnBack', useTouch);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('MainMenu');
  expect(errors).toEqual([]);
});

test('iOS Web AI key opens a real DOM editor and syncs typed text', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'webkit-touch', 'This regression targets portrait iOS Safari text entry');
  await startGame(page, 'v2');
  await activateControl(page, 'BtnSettings', true);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('Settings');
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
  await activateControl(page, 'BtnSettings', true);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('Settings');
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
  await activateControl(page, 'BtnSettings', false);
  await expect.poll(async () => (await bridgeRequest(page, 'snapshot')).scene).toBe('Settings');
});
