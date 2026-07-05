const cloud = require('@alipay/faas-server-sdk');

const COLLECTION_NAME = 'decksuggest';
const MAX_ACTIVE_RECOMMENDATIONS = 20;
const DB_QUERY_PAGE_SIZE = 100;
const MAX_SCAN_PAGES = 20;
const MAX_ID_LENGTH = 96;
const MAX_TITLE_LENGTH = 96;
const MAX_SUMMARY_LENGTH = 140;
const MAX_BODY_LENGTH = 520;
const MAX_URL_LENGTH = 260;
const MAX_WHY_PLAY_ITEMS = 3;
const MAX_DETAIL_SECTIONS = 8;
const MAX_DETAIL_BULLETS = 5;

const trimText = (value, maxLength = 0) => {
  if (value === undefined || value === null) return '';
  let text = String(value).trim().replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  while (text.includes('\n\n\n')) text = text.replace(/\n\n\n/g, '\n\n');
  if (maxLength > 0 && text.length > maxLength) text = text.slice(0, maxLength).trim();
  return text;
};

const toTimestamp = (value) => {
  if (value === undefined || value === null || value === '') return 0;

  if (typeof value === 'number') {
    if (!Number.isFinite(value) || value <= 0) return 0;
    return value < 10000000000 ? value * 1000 : value;
  }

  const text = trimText(value);
  if (!text) return 0;

  if (/^\d+$/.test(text)) {
    const numberValue = Number(text);
    if (!Number.isFinite(numberValue) || numberValue <= 0) return 0;
    return numberValue < 10000000000 ? numberValue * 1000 : numberValue;
  }

  const parsed = Date.parse(text);
  return Number.isFinite(parsed) ? parsed : 0;
};

const getRecommendationSortTime = (doc, recommendation) => {
  return Math.max(
    toTimestamp(recommendation.generated_at),
    toTimestamp(doc.generated_at),
    toTimestamp(doc.generatedAt),
    toTimestamp(doc.updated_at),
    toTimestamp(doc.updatedAt),
    toTimestamp(doc.created_at),
    toTimestamp(doc.createdAt),
    toTimestamp(doc.created_at_iso),
    toTimestamp(doc.createdAtIso)
  );
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
    for (const [key, value] of params.entries()) result[key] = value;
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
      if (decoded && decoded !== trimmed) return parseText(decoded, false);
    } catch (_) {}
  }

  return {};
};

const parseAny = (value, isBase64Encoded = false) => {
  if (value === undefined || value === null) return {};
  if (Buffer.isBuffer(value)) return parseText(value.toString('utf8'));
  if (value instanceof Uint8Array) return parseText(Buffer.from(value).toString('utf8'));

  if (typeof value === 'string') {
    if (isBase64Encoded) {
      try {
        return parseText(Buffer.from(value, 'base64').toString('utf8'), false);
      } catch (_) {}
    }
    return parseText(value);
  }

  if (isPlainObject(value)) return value;
  return {};
};

const mergePayload = (target, source) => {
  if (!isPlainObject(source)) return;
  for (const [key, value] of Object.entries(source)) {
    if (value !== undefined && value !== null && value !== '') target[key] = value;
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

const parseDeckId = (url) => {
  const text = trimText(url, MAX_URL_LENGTH);
  const match = text.match(/tcg\.mik\.moe\/decks\/list\/(\d+)/);
  if (!match) return 0;
  const deckId = Number(match[1]);
  return Number.isFinite(deckId) && deckId > 0 ? deckId : 0;
};

const normalizeStringArray = (value, maxItems, maxLength) => {
  const raw = Array.isArray(value) ? value : [];
  const result = [];
  for (const item of raw) {
    const text = trimText(item, maxLength);
    if (!text) continue;
    result.push(text);
    if (result.length >= maxItems) break;
  }
  return result;
};

const normalizeSource = (value) => {
  const source = isPlainObject(value) ? value : {};
  return {
    label: trimText(source.label, MAX_TITLE_LENGTH),
    city: trimText(source.city, 32),
    date: trimText(source.date, 32),
    players: Math.max(0, Number(source.players || 0) || 0),
    rank: Math.max(0, Number(source.rank || 0) || 0),
    url: trimText(source.url, MAX_URL_LENGTH),
  };
};

const normalizeDetail = (value) => {
  const detail = isPlainObject(value) ? value : {};
  const rawSections = Array.isArray(detail.sections) ? detail.sections : [];
  const sections = [];

  for (const rawSection of rawSections) {
    if (!isPlainObject(rawSection)) continue;

    const heading = trimText(rawSection.heading, MAX_TITLE_LENGTH);
    const body = trimText(rawSection.body, MAX_BODY_LENGTH);
    const bullets = normalizeStringArray(rawSection.bullets, MAX_DETAIL_BULLETS, MAX_SUMMARY_LENGTH);

    if (!heading && !body && bullets.length === 0) continue;

    sections.push({ heading, body, bullets });
    if (sections.length >= MAX_DETAIL_SECTIONS) break;
  }

  return { sections };
};

const normalizeRecommendation = (doc) => {
  const raw = isPlainObject(doc.recommendation) ? doc.recommendation : doc;

  const importUrl = trimText(raw.import_url || raw.source_url || raw.url, MAX_URL_LENGTH);
  const parsedDeckId = parseDeckId(importUrl);
  const explicitDeckId = Number(raw.deck_id || raw.deckId || 0) || 0;
  const deckId = explicitDeckId > 0 ? explicitDeckId : parsedDeckId;

  const id = trimText(raw.id || raw.slug || raw.recommendation_id || doc._id, MAX_ID_LENGTH);
  const deckName = trimText(raw.deck_name || raw.deckName, MAX_TITLE_LENGTH);
  const title = trimText(raw.title, MAX_TITLE_LENGTH);
  const styleSummary = trimText(raw.style_summary || raw.summary, MAX_SUMMARY_LENGTH);

  if (!id || !deckName || !importUrl || parsedDeckId <= 0 || deckId <= 0) return null;
  if (!title && !styleSummary) return null;

  return {
    id,
    deck_id: deckId,
    deck_name: deckName,
    title,
    style_summary: styleSummary,
    why_play: normalizeStringArray(raw.why_play || raw.whyPlay || raw.reasons, MAX_WHY_PLAY_ITEMS, MAX_SUMMARY_LENGTH),
    best_for: trimText(raw.best_for || raw.bestFor, MAX_SUMMARY_LENGTH),
    pilot_tip: trimText(raw.pilot_tip || raw.pilotTip, MAX_SUMMARY_LENGTH),
    source: normalizeSource(raw.source),
    import_url: importUrl,
    detail: normalizeDetail(raw.detail || { sections: raw.sections }),
    generated_at: trimText(raw.generated_at || raw.generatedAt || doc.created_at_iso, MAX_TITLE_LENGTH),
  };
};

const extractDocs = (queryResult) => {
  if (Array.isArray(queryResult)) return queryResult;
  if (Array.isArray(queryResult.data)) return queryResult.data;
  if (Array.isArray(queryResult.list)) return queryResult.list;
  if (Array.isArray(queryResult.docs)) return queryResult.docs;
  return [];
};

const parseIdList = (value) => {
  if (Array.isArray(value)) return value.map((item) => trimText(item)).filter(Boolean);
  const text = trimText(value);
  if (!text) return [];
  return text.split(',').map((item) => trimText(item)).filter(Boolean);
};

const parseLimit = (payload) => {
  const rawValue = payload.limit || payload.batch_limit || payload.batchLimit || payload.count || payload.size;
  if (rawValue === undefined || rawValue === null || rawValue === '') return 1;

  const raw = Array.isArray(rawValue) ? rawValue[0] : rawValue;
  const parsed = typeof raw === 'number' ? raw : Number(trimText(raw));
  if (!Number.isFinite(parsed) || parsed <= 0) return 1;

  return Math.min(MAX_ACTIVE_RECOMMENDATIONS, Math.max(1, Math.floor(parsed)));
};

const isEnabledDoc = (doc) => {
  if (doc.enabled === false) return false;
  const status = trimText(doc.status || (doc.recommendation && doc.recommendation.status)).toLowerCase();
  if (!status) return true;
  return ['active', 'published', 'ready'].includes(status);
};

const sortCandidates = (a, b) => {
  const timeA = Number(a._sort_time || 0) || 0;
  const timeB = Number(b._sort_time || 0) || 0;
  if (timeA !== timeB) return timeB - timeA;

  const priorityA = Number(a._priority || 0) || 0;
  const priorityB = Number(b._priority || 0) || 0;
  if (priorityA !== priorityB) return priorityB - priorityA;

  return String(a.id || '').localeCompare(String(b.id || ''));
};

const buildCandidateOrder = (items, currentId) => {
  if (!currentId) return items.slice();

  const currentIndex = items.findIndex((item) => item.id === currentId);
  if (currentIndex < 0) return items.slice();

  const ordered = [];
  for (let offset = 1; offset <= items.length; offset += 1) {
    ordered.push(items[(currentIndex + offset) % items.length]);
  }
  return ordered;
};

const chooseRecommendations = (items, payload, limit) => {
  const currentId = trimText(payload.current_id || payload.currentId);
  const excludeIds = new Set(parseIdList(payload.exclude_ids || payload.excludeIds));
  const ordered = buildCandidateOrder(items, currentId);
  const selected = [];
  const selectedIds = new Set();

  for (const candidate of ordered) {
    if (excludeIds.has(candidate.id) || selectedIds.has(candidate.id)) continue;

    selected.push(candidate);
    selectedIds.add(candidate.id);
    if (selected.length >= limit) return selected;
  }

  if (selected.length > 0) return selected;

  for (const candidate of ordered) {
    if (selectedIds.has(candidate.id)) continue;

    selected.push(candidate);
    selectedIds.add(candidate.id);
    if (selected.length >= limit) break;
  }

  return selected;
};

const chooseRecommendation = (items, payload) => {
  return chooseRecommendations(items, payload, 1)[0] || items[0];
};

const getDocKey = (doc, pageIndex, itemIndex) => {
  return trimText(doc._id || doc.id || doc.recommendation_id || (doc.recommendation && doc.recommendation.id))
    || `page:${pageIndex}:item:${itemIndex}`;
};

const queryAllDocs = async (collection) => {
  const docs = [];
  const seenKeys = new Set();

  for (let pageIndex = 0; pageIndex < MAX_SCAN_PAGES; pageIndex += 1) {
    let query = collection;
    const offset = pageIndex * DB_QUERY_PAGE_SIZE;

    if (typeof query.skip === 'function') {
      query = query.skip(offset);
    } else if (pageIndex > 0) {
      break;
    }

    if (typeof query.limit === 'function') {
      query = query.limit(DB_QUERY_PAGE_SIZE);
    }

    const queryResult = await query.get();
    const pageDocs = extractDocs(queryResult);
    let addedCount = 0;

    for (let itemIndex = 0; itemIndex < pageDocs.length; itemIndex += 1) {
      const doc = pageDocs[itemIndex];
      if (!isPlainObject(doc)) continue;

      const key = getDocKey(doc, pageIndex, itemIndex);
      if (seenKeys.has(key)) continue;

      seenKeys.add(key);
      docs.push(doc);
      addedCount += 1;
    }

    if (pageDocs.length < DB_QUERY_PAGE_SIZE || addedCount === 0) break;
  }

  return docs;
};

const buildCandidates = (docs) => {
  const candidates = [];

  for (const doc of docs) {
    if (!isPlainObject(doc) || !isEnabledDoc(doc)) continue;

    const recommendation = normalizeRecommendation(doc);
    if (!recommendation) continue;

    recommendation._priority = Number(doc.priority || (doc.recommendation && doc.recommendation.priority) || 0) || 0;
    recommendation._sort_time = getRecommendationSortTime(doc, recommendation);
    candidates.push(recommendation);
  }

  candidates.sort(sortCandidates);
  return candidates;
};

const stripInternalFields = (recommendation) => {
  const selected = { ...recommendation };
  delete selected._priority;
  delete selected._sort_time;
  return selected;
};

exports.main = async (event, context) => {
  cloud.init();
  const db = cloud.database();

  const payload = parseEvent(event);
  const requestedLimit = parseLimit(payload);

  console.log('卡组推荐入参解析结果:', {
    payload_keys: Object.keys(payload),
    id: trimText(payload.id || payload.recommendation_id),
    current_id: trimText(payload.current_id || payload.currentId),
    exclude_ids: parseIdList(payload.exclude_ids || payload.excludeIds),
    limit: requestedLimit,
  });

  const docs = await queryAllDocs(db.collection(COLLECTION_NAME));
  const candidates = buildCandidates(docs);
  const activeCandidates = candidates.slice(0, MAX_ACTIVE_RECOMMENDATIONS);

  if (candidates.length === 0 || activeCandidates.length === 0) {
    return {
      ok: false,
      code: 'NO_RECOMMENDATION',
      message: '暂时没有可用的卡组推荐',
      recommendation: null,
      recommendations: [],
      total: 0,
      total_available: 0,
      retention_limit: MAX_ACTIVE_RECOMMENDATIONS,
      requested_limit: requestedLimit,
      returned: 0,
      scanned_docs: docs.length,
    };
  }

  const requestedId = trimText(payload.id || payload.recommendation_id);
  const requested = requestedId ? candidates.find((item) => item.id === requestedId) : null;
  const selectedItems = requested
    ? [requested]
    : chooseRecommendations(activeCandidates, payload, requestedLimit);
  const strippedItems = selectedItems.map(stripInternalFields);
  const selected = strippedItems[0] || stripInternalFields(chooseRecommendation(activeCandidates, payload));

  const response = {
    ok: true,
    code: 'OK',
    message: '获取推荐成功',
    recommendation: selected,
    total: activeCandidates.length,
    total_available: candidates.length,
    retention_limit: MAX_ACTIVE_RECOMMENDATIONS,
    requested_limit: requestedLimit,
    returned: strippedItems.length > 0 ? strippedItems.length : 1,
    scanned_docs: docs.length,
    requested_found: Boolean(requested),
    served_at: new Date().toISOString(),
  };

  if (!requested && requestedLimit > 1) {
    response.recommendations = strippedItems;
  }

  return response;
};
