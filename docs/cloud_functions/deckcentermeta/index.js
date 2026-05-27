const cloud = require('@alipay/faas-server-sdk');

const COLLECTION_NAME = 'ptcg_deck_center_meta';
const CHANNEL = 'deck_recommendations';
const SCHEMA_VERSION = 1;
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

  const headers = {};
  mergePayload(headers, parseAny(root.headers));
  mergePayload(headers, parseAny(httpInfo.headers));
  mergePayload(headers, parseAny(request.headers));
  payload.__headers = headers;

  return payload;
};

const rowsFromGetResult = (result) => {
  if (!result) return [];
  if (Array.isArray(result)) return result;
  if (Array.isArray(result.data)) return result.data;
  if (isPlainObject(result.data)) return [result.data];
  if (Array.isArray(result.list)) return result.list;
  if (Array.isArray(result.docs)) return result.docs;
  return [];
};

const numberOrZero = (value) => {
  const numberValue = Number(value || 0);
  return Number.isFinite(numberValue) ? numberValue : 0;
};

const headerValue = (headers, name) => {
  if (!isPlainObject(headers)) return '';
  const wanted = name.toLowerCase();
  for (const [key, value] of Object.entries(headers)) {
    if (String(key).toLowerCase() === wanted) {
      return trimText(value);
    }
  }
  return '';
};

const payloadSecret = (payload) => {
  const direct = trimText(payload.secret || payload.update_secret || payload.deck_center_secret);
  if (direct) return direct;
  const auth = headerValue(payload.__headers, 'authorization');
  if (auth.toLowerCase().startsWith('bearer ')) {
    return auth.slice(7).trim();
  }
  return auth;
};

const configuredSecret = () => {
  return trimText(process.env.PTCG_DECK_CENTER_UPDATE_SECRET || process.env.DECK_CENTER_UPDATE_SECRET);
};

const isWriteAction = (action) => {
  return action === 'update' || action === 'set' || action === 'publish';
};

const buildRevision = (payload, recommendation, nowIso) => {
  const explicit = limitText(payload.latest_revision || payload.revision, 180);
  if (explicit) return explicit;

  const generatedAt = limitText(recommendation.generated_at || payload.generated_at, 64);
  const recId = limitText(recommendation.id || payload.recommendation_id || payload.latest_recommendation_id, 96);
  const deckId = numberOrZero(recommendation.deck_id || payload.deck_id || payload.latest_deck_id);
  const parts = [generatedAt || nowIso, recId, deckId > 0 ? String(deckId) : ''].filter((part) => part !== '');
  return limitText(parts.join(':'), 180);
};

const normalizeMeta = (payload, now) => {
  const recommendation = isPlainObject(payload.recommendation) ? payload.recommendation : {};
  const nowIso = new Date(now).toISOString();
  const latestRevision = buildRevision(payload, recommendation, nowIso);
  if (!latestRevision) {
    throw new Error('latest_revision could not be derived from the request');
  }

  const recommendationId = limitText(
    payload.latest_recommendation_id || payload.recommendation_id || recommendation.id,
    96,
  );
  const deckId = numberOrZero(payload.latest_deck_id || payload.deck_id || recommendation.deck_id);

  return {
    meta_key: CHANNEL,
    schema_version: SCHEMA_VERSION,
    channel: CHANNEL,
    latest_revision: latestRevision,
    latest_recommendation_id: recommendationId,
    latest_deck_id: deckId,
    latest_title: limitText(payload.latest_title || recommendation.title, 140),
    latest_deck_name: limitText(payload.latest_deck_name || recommendation.deck_name, 96),
    updated_at: now,
    updated_at_iso: nowIso,
    source: limitText(payload.source, 80) || 'manual',
    function_name: 'deckcentermeta',
  };
};

const emptyMeta = () => {
  return {
    ok: true,
    code: 'EMPTY',
    schema_version: SCHEMA_VERSION,
    channel: CHANNEL,
    latest_revision: '',
    latest_recommendation_id: '',
    latest_deck_id: 0,
    latest_title: '',
    latest_deck_name: '',
    updated_at: 0,
    updated_at_iso: '',
  };
};

const publicMetaResponse = (meta, code = 'OK') => {
  return {
    ok: true,
    code,
    schema_version: SCHEMA_VERSION,
    channel: CHANNEL,
    latest_revision: limitText(meta.latest_revision, 180),
    latest_recommendation_id: limitText(meta.latest_recommendation_id, 96),
    latest_deck_id: numberOrZero(meta.latest_deck_id),
    latest_title: limitText(meta.latest_title, 140),
    latest_deck_name: limitText(meta.latest_deck_name, 96),
    updated_at: numberOrZero(meta.updated_at),
    updated_at_iso: limitText(meta.updated_at_iso, 64),
    source: limitText(meta.source, 80),
  };
};

const fetchLatestMeta = async (db) => {
  const collection = db.collection(COLLECTION_NAME);
  let rows = [];
  try {
    const query = collection.where({ meta_key: CHANNEL });
    const result = await query.get();
    rows = rowsFromGetResult(result);
  } catch (error) {
    console.log('deck center meta query failed:', error);
    return {};
  }

  rows = rows.filter((row) => isPlainObject(row) && trimText(row.latest_revision) !== '');
  rows.sort((a, b) => numberOrZero(b.updated_at) - numberOrZero(a.updated_at));
  return rows.length > 0 ? rows[0] : {};
};

exports.main = async (event, context) => {
  cloud.init();
  const db = cloud.database();
  const payload = parseEvent(event);
  const action = limitText(payload.action, 32).toLowerCase() || 'get';

  if (!isWriteAction(action)) {
    const latest = await fetchLatestMeta(db);
    return Object.keys(latest).length > 0 ? publicMetaResponse(latest) : emptyMeta();
  }

  const requiredSecret = configuredSecret();
  if (!requiredSecret) {
    return {
      ok: false,
      code: 'SERVER_NOT_CONFIGURED',
      message: 'deck center update secret is not configured',
    };
  }
  if (payloadSecret(payload) !== requiredSecret) {
    return {
      ok: false,
      code: 'UNAUTHORIZED',
      message: 'deck center update secret is missing or invalid',
    };
  }

  let data;
  try {
    data = normalizeMeta(payload, Date.now());
  } catch (error) {
    return {
      ok: false,
      code: 'BAD_REQUEST',
      message: error.message,
    };
  }

  const doc = await db.collection(COLLECTION_NAME).add({ data });
  console.log('deck center meta updated:', {
    doc_id: doc._id,
    latest_revision: data.latest_revision,
    latest_recommendation_id: data.latest_recommendation_id,
    latest_deck_id: data.latest_deck_id,
  });

  return {
    ...publicMetaResponse(data, 'UPDATED'),
    doc_id: doc._id,
  };
};
