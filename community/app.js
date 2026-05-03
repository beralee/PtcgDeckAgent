const DATA_URL = './data/community-data.json';

const fallbackData = {
  generated_at: new Date().toISOString(),
  format: '本地预览',
  environment_briefing: {
    name: '环境解读',
    title: '今日环境作业暂未同步',
    subtitle: '训练家，页面框架已经就位；刷新后会读取最新生成的环境文章。',
    updated_label: '每日自动生成',
    source_signals: [
      {
        label: '读取状态',
        value: '等待数据',
        note: '环境作业会优先选择近期已结束、大人数、有卡表的比赛样本。',
      },
    ],
    article: {
      hero: {
        title: '环境解读生成中',
        deck_name: '待选择样本',
        tournament: '本地预览',
        thesis: '这里会呈现当天最值得训练的构筑问题。',
      },
      sections: [
        {
          heading: '今天先看什么',
          body: '真正有训练价值的信息不是新闻列表，而是近期比赛里哪些构筑正在惩罚热门环境。',
          bullets: ['优先看已结束比赛。', '优先看人数多、有卡表、有构筑差异的样本。'],
        },
      ],
      deck_snapshot: {
        title: '卡组图片快照',
        source_url: '',
        cards: [],
      },
      links: [],
    },
    articles: [],
  },
  notices: ['当前显示的是本地 fallback 数据。'],
};

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function formatGenerated(value) {
  if (!value) return '未知';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
}

function renderHero(data) {
  const briefing = data.environment_briefing || fallbackData.environment_briefing;
  document.querySelector('#briefing-name').textContent = briefing.name || '环境解读';
  document.querySelector('#briefing-title').textContent = briefing.title || '今日环境作业';
  document.querySelector('#briefing-message').textContent = briefing.subtitle || '';
  document.querySelector('#updated-label').textContent = briefing.updated_label || '每日自动生成';
  document.querySelector('#generated-at').textContent = formatGenerated(data.generated_at);
  document.querySelector('#format-label').textContent = data.format || '未标注';
}

function renderSignals(signals) {
  const container = document.querySelector('#source-signals');
  const items = Array.isArray(signals) ? signals : [];
  if (items.length === 0) {
    container.innerHTML = '<div class="empty">今日环境信号暂未生成。</div>';
    return;
  }
  container.innerHTML = items
    .map(
      (item) => `
        <article class="signal-card">
          <span>${escapeHtml(item.label)}</span>
          <strong>${escapeHtml(item.value)}</strong>
          <p>${escapeHtml(item.note || '')}</p>
        </article>
      `
    )
    .join('');
}

function articleId(article, index) {
  const raw = String(article?.slug || `article-${index + 1}`);
  return `article-${raw.replace(/[^a-zA-Z0-9_-]/g, '-')}`;
}

function getEnvironmentArticles(briefing) {
  const articles = Array.isArray(briefing?.articles) && briefing.articles.length
    ? briefing.articles
    : briefing?.article
      ? [briefing.article]
      : [];
  return articles.filter((article) => article && article.hero);
}

function getFeaturedArticle(briefing) {
  const articles = getEnvironmentArticles(briefing);
  if (!articles.length) return null;
  return [...articles].sort((a, b) => {
    const dateA = String(a?.source?.date || '').replaceAll('.', '');
    const dateB = String(b?.source?.date || '').replaceAll('.', '');
    if (dateA !== dateB) return dateB.localeCompare(dateA);
    return Number(b?.source?.players || 0) - Number(a?.source?.players || 0);
  })[0];
}

function renderTopActions(article) {
  const container = document.querySelector('#briefing-links');
  const snapshot = article?.deck_snapshot || {};
  const importUrl = snapshot.import_url || snapshot.source_url || article?.links?.[0]?.url || '';
  if (!importUrl) {
    container.innerHTML = '';
    return;
  }
  container.innerHTML = `
    <button class="source-link action-button" type="button" data-copy="${escapeHtml(importUrl)}">
      复制导入链接
    </button>
    <a class="source-link primary-link" href="${escapeHtml(importUrl)}" target="_blank" rel="noreferrer">
      打开卡表
    </a>
  `;
  bindCopyButtons(container);
}

function renderEnvironmentArticle(article) {
  const container = document.querySelector('#environment-article');
  if (!article || !article.hero) {
    container.innerHTML = '<div class="empty">今日环境解读暂未生成。</div>';
    return;
  }
  container.innerHTML = renderEnvironmentArticleCard(article, 0);
  bindCopyButtons(container);
}

function renderEnvironmentArticleCard(article, index) {
  const sections = Array.isArray(article.sections) ? article.sections : [];
  return `
    <article id="${escapeHtml(articleId(article, index))}" class="article-card">
    <div class="article-hero">
      <div>
        <p class="eyebrow">Today's Homework</p>
        <h3>${escapeHtml(article.hero.title)}</h3>
        <p class="article-thesis">${escapeHtml(article.hero.thesis || '')}</p>
      </div>
      <dl class="deck-focus">
        <div>
          <dt>焦点构筑</dt>
          <dd>${escapeHtml(article.hero.deck_name || '未标注')}</dd>
        </div>
        <div>
          <dt>赛事样本</dt>
          <dd>${escapeHtml(article.hero.tournament || '未标注')}</dd>
        </div>
      </dl>
    </div>
    ${renderImportPanel(article)}
    <div class="article-body">
      ${sections.map(renderArticleSection).join('')}
    </div>
    ${renderDeckImageSnapshot(article.deck_snapshot)}
    ${renderArticleLinks(article.links)}
    </article>
  `;
}

function renderImportPanel(article) {
  const snapshot = article?.deck_snapshot || {};
  const importUrl = snapshot.import_url || snapshot.source_url || '';
  if (!importUrl) return '';
  const deckId = snapshot.deck_id || '';
  const deckCode = snapshot.deck_code || '';
  return `
    <aside class="import-panel">
      <div>
        <p class="eyebrow">Practice Loop</p>
        <h4>导入游戏，今天就练这套</h4>
        <p>游戏的卡组管理可以识别 tcg.mik.moe 卡表链接。先导入，再按上面的解读去测试它是否真的适合你的环境。</p>
      </div>
      <dl class="import-meta">
        ${deckId ? `<div><dt>卡组 ID</dt><dd>${escapeHtml(deckId)}</dd></div>` : ''}
        ${deckCode ? `<div><dt>小程序代码</dt><dd>${escapeHtml(deckCode)}</dd></div>` : ''}
      </dl>
      <div class="import-actions">
        <button class="source-link action-button primary-action" type="button" data-copy="${escapeHtml(importUrl)}">
          复制导入链接
        </button>
        <a class="source-link" href="${escapeHtml(importUrl)}" target="_blank" rel="noreferrer">打开 tcg 卡表</a>
        ${deckId ? `<button class="source-link action-button" type="button" data-copy="${escapeHtml(deckId)}">复制卡组 ID</button>` : ''}
      </div>
      <ol class="practice-steps">
        <li><strong>导入</strong><span>把链接粘到卡组管理。</span></li>
        <li><strong>练习</strong><span>先打热门对局，重点验证文章里的构筑取舍。</span></li>
        <li><strong>复盘</strong><span>保留有效单卡，删掉只在纸面上好看的部分。</span></li>
      </ol>
    </aside>
  `;
}

function renderDeckImageSnapshot(snapshot) {
  const snapshotObject = Array.isArray(snapshot) ? { cards: snapshot } : snapshot || {};
  const cards = Array.isArray(snapshotObject.cards)
    ? snapshotObject.cards.filter((card) => card?.image_url).slice(0, 80)
    : [];
  if (!cards.length) return '';
  const sourceUrl = snapshotObject.source_url || '';
  return `
    <aside class="deck-image-panel">
      <div class="deck-image-header">
        <div>
          <p class="eyebrow">Deck Image Snapshot</p>
          <h4>${escapeHtml(snapshotObject.title || '卡组图片快照')}</h4>
        </div>
        ${
          sourceUrl
            ? `<a class="source-link" href="${escapeHtml(sourceUrl)}" target="_blank" rel="noreferrer">原始卡表</a>`
            : ''
        }
      </div>
      <div class="card-image-grid">
        ${cards.map(renderDeckImageCard).join('')}
      </div>
    </aside>
  `;
}

function renderDeckImageCard(card) {
  const name = card.name || '未知卡牌';
  const count = Number(card.count || 0);
  return `
    <figure class="deck-card-image">
      <img
        src="${escapeHtml(card.image_url)}"
        alt="${escapeHtml(`${name} ×${count}`)}"
        loading="lazy"
        referrerpolicy="no-referrer"
      />
      <figcaption>
        <span>${escapeHtml(name)}</span>
        <strong>×${escapeHtml(count)}</strong>
      </figcaption>
    </figure>
  `;
}

function renderArticleLinks(links) {
  const items = Array.isArray(links) ? links.filter((link) => link?.url) : [];
  if (!items.length) return '';
  return `
    <div class="article-links">
      ${items
        .map(
          (link) => `
            <a class="source-link" href="${escapeHtml(link.url)}" target="_blank" rel="noreferrer">
              ${escapeHtml(link.label || '查看来源')}
            </a>
          `
        )
        .join('')}
    </div>
  `;
}

function bindCopyButtons(root) {
  root.querySelectorAll('[data-copy]').forEach((button) => {
    button.addEventListener('click', async () => {
      const value = button.getAttribute('data-copy') || '';
      const original = button.textContent;
      try {
        await navigator.clipboard.writeText(value);
        button.textContent = '已复制';
      } catch (error) {
        button.textContent = '复制失败';
      }
      window.setTimeout(() => {
        button.textContent = original;
      }, 1600);
    });
  });
}

function renderArticleSection(section, index) {
  const bullets = Array.isArray(section.bullets) ? section.bullets : [];
  return `
    <section class="article-section">
      <div class="section-number">${String(index + 1).padStart(2, '0')}</div>
      <div>
        <h3>${escapeHtml(section.heading || '')}</h3>
        <p>${escapeHtml(section.body || '')}</p>
        ${
          bullets.length
            ? `<ul>${bullets.map((item) => `<li>${escapeHtml(item)}</li>`).join('')}</ul>`
            : ''
        }
      </div>
    </section>
  `;
}

function render(data) {
  const briefing = data.environment_briefing || fallbackData.environment_briefing;
  const article = getFeaturedArticle(briefing);
  renderHero(data);
  renderSignals(briefing.source_signals);
  renderTopActions(article);
  renderEnvironmentArticle(article);
}

async function loadData() {
  try {
    const response = await fetch(DATA_URL, { cache: 'no-store' });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } catch (error) {
    return {
      ...fallbackData,
      notices: [...fallbackData.notices, `数据加载失败：${error.message}`],
    };
  }
}

loadData().then(render);
