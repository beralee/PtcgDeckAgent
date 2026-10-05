const base = require('./playwright.config.cjs');
module.exports = { ...base, testMatch: /arena-platform\.spec\.cjs/, timeout: 180000,
  // Frame sampling must not include Playwright's continuous video encoding or
  // trace screenshots. Explicit before/after screenshots and raw samples remain.
  use: { ...base.use, video: 'off', trace: 'off' },
  // The legacy headless shell uses SwiftShader on this Windows host. Use the
  // full Chromium headless implementation for hardware-rendered parity tests.
  projects: base.projects.map(project => project.name.startsWith('chromium')
    ? { ...project, use: { ...project.use, channel: 'chromium' } } : project)
};
