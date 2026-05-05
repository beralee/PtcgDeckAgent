const crypto = require('node:crypto');
const cloud = require('@alipay/faas-server-sdk');

const COLLECTION_NAME = 'ptcguser';
const MAX_TEXT_LENGTH = 256;

const trimText = (value) => {
  if (value === undefined || value === null) return '';
  return String(value).trim();
};

const limitText = (value, maxLength = MAX_TEXT_LENGTH) => {
  const text = trimText(value);
  return text.length > maxLength ? text.slice(0, maxLength) : text;
};

const isPlainObject = (value) => {
  return value && typeof value === 'object' && !Array.isArray(value) && !Buffer.isBuffer(value);
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

exports.main = async (event, context) => {
  cloud.init();
  const db = cloud.database();

  const payload = parseEvent(event);
  const now = Date.now();
  const visitId = limitText(payload.visit_id, 80) || makeId('visit');
  const clientId = limitText(payload.client_id, 128) || makeId('client');

  const data = {
    visit_id: visitId,
    client_id: clientId,
    source: limitText(payload.source, 80) || 'unknown',
    app_version: limitText(payload.app_version, 32),
    version: limitText(payload.version, 32),
    build_number: Number(payload.build_number || 0),
    channel: limitText(payload.channel, 32),
    platform: limitText(payload.platform, 64),
    locale: limitText(payload.locale, 64),
    engine_version: limitText(payload.engine_version, 80),
    reported_at: Number(payload.reported_at || 0),
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
