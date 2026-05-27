const crypto = require('node:crypto');
const cloud = require('@alipay/faas-server-sdk');

const COLLECTION_NAME = 'ptcguser';
const MAX_TEXT_LENGTH = 256;
const MAX_DIMENSION = 100000;

const trimText = (value) => {
  if (value === undefined || value === null) return '';
  return String(value).trim();
};

const limitText = (value, maxLength = MAX_TEXT_LENGTH) => {
  const text = trimText(value);
  return text.length > maxLength ? text.slice(0, maxLength) : text;
};

const finiteNumber = (value, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const limitDimension = (value) => {
  const parsed = finiteNumber(value, 0);
  return Math.max(0, Math.min(MAX_DIMENSION, Math.round(parsed)));
};

const toBoolean = (value, fallback = false) => {
  if (value === undefined || value === null || value === '') return fallback;
  if (value === true || value === false) return value;
  const text = String(value).trim().toLowerCase();
  if (['true', '1', 'yes', 'y'].includes(text)) return true;
  if (['false', '0', 'no', 'n'].includes(text)) return false;
  return fallback;
};

const isPlainObject = (value) => {
  return value && typeof value === 'object' && !Array.isArray(value) && !Buffer.isBuffer(value);
};

const firstValue = (...values) => {
  for (const value of values) {
    if (value !== undefined && value !== null && value !== '') return value;
  }
  return undefined;
};

const parseJson = (text) => {
  try {
    const parsed = JSON.parse(text);
    return isPlainObject(parsed) ? parsed : {};
  } catch (_) {
    return {};
  }
};

const parseForm = (text) => {
  if (!text.includes('=')) return {};
  try {
    const params = new URLSearchParams(text);
    const result = {};
    for (const [key, value] of params.entries()) {
      result[key] = value;
    }
    return result;
  } catch (_) {
    return {};
  }
};

const parseText = (text, allowBase64 = true) => {
  const trimmed = trimText(text);
  if (!trimmed) return {};

  const json = parseJson(trimmed);
  if (Object.keys(json).length > 0) return json;

  const form = parseForm(trimmed);
  if (Object.keys(form).length > 0) return form;

  if (allowBase64 && /^[A-Za-z0-9+/=\r\n]+$/.test(trimmed)) {
    try {
      const decoded = Buffer.from(trimmed, 'base64').toString('utf8').trim();
      if (decoded && decoded !== trimmed) {
        return parseText(decoded, false);
      }
    } catch (_) {}
  }

  return {};
};

const parseAny = (value, isBase64Encoded = false) => {
  if (value === undefined || value === null) return {};

  if (Buffer.isBuffer(value)) {
    return parseText(value.toString('utf8'));
  }

  if (value instanceof Uint8Array) {
    return parseText(Buffer.from(value).toString('utf8'));
  }

  if (typeof value === 'string') {
    if (isBase64Encoded) {
      try {
        return parseText(Buffer.from(value, 'base64').toString('utf8'), false);
      } catch (_) {}
    }
    return parseText(value);
  }

  if (isPlainObject(value)) {
    return value;
  }

  return {};
};

const mergePayload = (target, source) => {
  if (!isPlainObject(source)) return;
  for (const [key, value] of Object.entries(source)) {
    if (value !== undefined && value !== null && value !== '') {
      target[key] = value;
    }
  }
};

const parseEvent = (event) => {
  const root = parseAny(event);
  const payload = {};

  mergePayload(payload, root);
  mergePayload(payload, parseAny(root.requestData));
  mergePayload(payload, parseAny(root.data));
  mergePayload(payload, parseAny(root.payload));
  mergePayload(payload, parseAny(root.args));
  mergePayload(payload, parseAny(root.queryParameters));
  mergePayload(payload, parseAny(root.queryStringParameters));
  mergePayload(payload, parseAny(root.query));
  mergePayload(payload, parseAny(root.params));

  const body = parseAny(root.body, root.isBase64Encoded === true);
  mergePayload(payload, body);
  mergePayload(payload, parseAny(body.body));
  mergePayload(payload, parseAny(body.data));
  mergePayload(payload, parseAny(body.payload));
  mergePayload(payload, parseAny(body.requestData));

  const httpInfo = parseAny(root.httpInfo);
  mergePayload(payload, parseAny(httpInfo.queryParameters));
  mergePayload(payload, parseAny(httpInfo.queryStringParameters));
  mergePayload(payload, parseAny(httpInfo.body));

  const request = parseAny(root.request);
  mergePayload(payload, parseAny(request.query));
  mergePayload(payload, parseAny(request.body));

  return payload;
};

const makeId = (prefix) => {
  return `${prefix}_${crypto.randomBytes(16).toString('hex')}`;
};

const normalizeOrientation = (value, width, height) => {
  const text = limitText(value, 24).toLowerCase();
  if (['portrait', 'landscape', 'square', 'unknown'].includes(text)) return text;
  if (height > width && height > 0 && width > 0) return 'portrait';
  if (width > height && height > 0 && width > 0) return 'landscape';
  if (width > 0 && width === height) return 'square';
  return 'unknown';
};

const displayPayload = (payload) => {
  const screen = isPlainObject(payload.screen) ? payload.screen : {};
  const usable = isPlainObject(payload.screen_usable) ? payload.screen_usable : {};
  const windowInfo = isPlainObject(payload.window) ? payload.window : {};
  const viewport = isPlainObject(payload.viewport) ? payload.viewport : {};
  const display = isPlainObject(payload.display) ? payload.display : {};
  const device = isPlainObject(payload.device) ? payload.device : {};

  const screenWidth = limitDimension(firstValue(
    payload.screen_width,
    screen.width,
    screen.w,
    display.screen_width,
    device.screen_width
  ));
  const screenHeight = limitDimension(firstValue(
    payload.screen_height,
    screen.height,
    screen.h,
    display.screen_height,
    device.screen_height
  ));

  return {
    display_server: limitText(firstValue(payload.display_server, display.server), 32),
    screen_width: screenWidth,
    screen_height: screenHeight,
    screen_usable_width: limitDimension(firstValue(
      payload.screen_usable_width,
      usable.width,
      usable.w,
      display.screen_usable_width
    )),
    screen_usable_height: limitDimension(firstValue(
      payload.screen_usable_height,
      usable.height,
      usable.h,
      display.screen_usable_height
    )),
    window_width: limitDimension(firstValue(
      payload.window_width,
      windowInfo.width,
      windowInfo.w,
      display.window_width
    )),
    window_height: limitDimension(firstValue(
      payload.window_height,
      windowInfo.height,
      windowInfo.h,
      display.window_height
    )),
    viewport_width: limitDimension(firstValue(
      payload.viewport_width,
      viewport.width,
      viewport.w,
      display.viewport_width
    )),
    viewport_height: limitDimension(firstValue(
      payload.viewport_height,
      viewport.height,
      viewport.h,
      display.viewport_height
    )),
    screen_orientation: normalizeOrientation(
      firstValue(payload.screen_orientation, screen.orientation, display.orientation, device.orientation),
      screenWidth,
      screenHeight
    ),
    is_mobile_runtime: toBoolean(
      firstValue(payload.is_mobile_runtime, payload.mobile, device.is_mobile_runtime, device.mobile),
      false
    ),
  };
};

exports.main = async (event, context) => {
  cloud.init();
  const db = cloud.database();

  const payload = parseEvent(event);
  const now = Date.now();
  const visitId = limitText(payload.visit_id, 80) || makeId('visit');
  const clientId = limitText(payload.client_id, 128) || makeId('client');
  const displayData = displayPayload(payload);

  const data = {
    visit_id: visitId,
    client_id: clientId,
    source: limitText(payload.source, 80) || 'unknown',
    app_version: limitText(payload.app_version, 32),
    version: limitText(payload.version, 32),
    build_number: finiteNumber(payload.build_number, 0),
    channel: limitText(payload.channel, 32),
    platform: limitText(payload.platform, 64),
    locale: limitText(payload.locale, 64),
    engine_version: limitText(payload.engine_version, 80),
    display_server: displayData.display_server,
    screen_width: displayData.screen_width,
    screen_height: displayData.screen_height,
    screen_usable_width: displayData.screen_usable_width,
    screen_usable_height: displayData.screen_usable_height,
    window_width: displayData.window_width,
    window_height: displayData.window_height,
    viewport_width: displayData.viewport_width,
    viewport_height: displayData.viewport_height,
    screen_orientation: displayData.screen_orientation,
    is_mobile_runtime: displayData.is_mobile_runtime,
    reported_at: finiteNumber(payload.reported_at, 0),
    created_at: now,
    created_at_iso: new Date(now).toISOString(),
    function_name: 'ptcguser',
  };

  const doc = await db.collection(COLLECTION_NAME).add({ data });

  console.log('ptcg user visit recorded:', {
    visit_id: visitId,
    client_id: clientId,
    doc_id: doc._id,
    platform: data.platform,
    app_version: data.app_version,
    screen: `${data.screen_width}x${data.screen_height}`,
    viewport: `${data.viewport_width}x${data.viewport_height}`,
  });

  return {
    ok: true,
    code: 'OK',
    message: 'visit recorded',
    visit_id: visitId,
    client_id: clientId,
    doc_id: doc._id,
  };
};
