const path = require('path');
const { defineConfig, devices } = require('@playwright/test');

const exportDir = process.env.PTCG_WEB_E2E_EXPORT_DIR || path.resolve(__dirname, '../../.tmp/web_ui_e2e');
const artifactDir = process.env.PTCG_WEB_E2E_ARTIFACT_DIR || path.resolve(__dirname, '../../.tmp/web_ui_e2e_artifacts');

module.exports = defineConfig({
  testDir: __dirname,
  testMatch: /ui-stability\.spec\.cjs/,
  timeout: 120000,
  expect: { timeout: 20000 },
  fullyParallel: false,
  retries: 0,
  workers: 1,
  reporter: [['list'], ['html', { outputFolder: path.join(artifactDir, 'report'), open: 'never' }]],
  outputDir: path.join(artifactDir, 'results'),
  use: {
    actionTimeout: 15000,
    baseURL: 'http://127.0.0.1:8060',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
  webServer: {
    command: `python -m http.server 8060 --directory "${exportDir}"`,
    cwd: __dirname,
    url: 'http://127.0.0.1:8060/PtcgDeckAgent.html',
    reuseExistingServer: false,
    timeout: 30000
  },
  projects: [
    {
      name: 'webkit-desktop',
      use: { ...devices['Desktop Safari'] }
    },
    {
      name: 'webkit-tablet-touch',
      use: { ...devices['iPad Mini'] }
    },
    {
      name: 'chromium-desktop',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } }
    },
    {
      name: 'chromium-touch',
      use: { ...devices['Pixel 7'] }
    },
    {
      name: 'webkit-touch',
      use: { ...devices['iPhone 14'] }
    },
    {
      name: 'webkit-touch-landscape',
      use: { ...devices['iPhone 14 landscape'] }
    }
  ]
});
