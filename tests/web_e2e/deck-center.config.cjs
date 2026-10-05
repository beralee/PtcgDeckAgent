const path = require('path');
const { defineConfig } = require('@playwright/test');
const exportDir = process.env.PTCG_WEB_E2E_EXPORT_DIR || path.resolve(__dirname, '../../.tmp/deck-center-redesign/web');
const outputDir = process.env.PTCG_WEB_E2E_ARTIFACT_DIR || path.resolve(__dirname, '../../.tmp/deck-center-redesign/browser');
const port = Number(process.env.PTCG_WEB_E2E_PORT || 8072);
module.exports = defineConfig({
  testDir: __dirname, testMatch: /deck-center\.spec\.cjs/, timeout: 120000, workers: 1, retries: 0,
  expect: { timeout: 20000 }, outputDir: path.join(outputDir, 'results'),
  reporter: [['list'], ['json', { outputFile: path.join(outputDir, 'results.json') }]],
  use: { baseURL: `http://127.0.0.1:${port}`, trace: 'retain-on-failure', screenshot: 'only-on-failure' },
  webServer: { command: `python -m http.server ${port} --directory "${exportDir}"`, url: `http://127.0.0.1:${port}/PtcgDeckAgent.html`, reuseExistingServer: false },
  projects: [
    { name: 'desktop', use: { browserName: 'chromium', channel: 'msedge', viewport: { width: 1360, height: 860 } } },
    { name: 'portrait-touch', use: { browserName: 'chromium', channel: 'msedge', viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true } },
    { name: 'landscape-touch', use: { browserName: 'chromium', channel: 'msedge', viewport: { width: 844, height: 390 }, hasTouch: true, isMobile: true } },
  ],
});
