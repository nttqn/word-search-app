// Store screenshots for every device class, written to store/<device>/.
//
//   flutter create --platforms=web .   (web/ isn't committed; delete the
//                                        test/widget_test.dart it adds)
//   flutter build web --release -t lib/shots.dart -o build/shots
//   node tool/store_shots.js [device ...]
//
// Set WEB to serve a build from somewhere else. Needs `playwright` and
// `pngjs` resolvable (not project dependencies — install in a scratch
// folder and point NODE_PATH at it). Viewports are logical points × the
// device's pixel density, so the UI is the size it really is on that device.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const { PNG } = require('pngjs');

const ROOT = path.join(__dirname, '..');
const WEB = process.env.WEB || path.join(ROOT, 'build', 'shots');
const STORE = path.join(ROOT, 'store');

const DEVICES = {
  phone: { w: 360, h: 720, scale: 3 }, // 1080 x 2160 — Google Play phone
  'tablet-7in': { w: 600, h: 960, scale: 2 }, // 1200 x 1920
  'tablet-10in': { w: 800, h: 1280, scale: 2 }, // 1600 x 2560
  'iphone-6.3in': { w: 402, h: 874, scale: 3 }, // 1206 x 2622 — App Store
  'ipad-13in': { w: 1032, h: 1376, scale: 2 }, // 2064 x 2752
};

// Scenes are defined in lib/shots.dart. Play allows 8 per device type.
const SCENES = {
  '01': 'home',
  '02': 'gameplay',
  '03': 'hint',
  '04': 'complete',
  '05': 'review',
  '06': 'daily-streak',
  '07': 'word-book',
  '08': 'expert',
};
// Completion dialogs open a frame after the grid; give them a moment more.
const SETTLE = { '04': 3500, '06': 3500 };

const TYPES = { '.html': 'text/html', '.js': 'application/javascript', '.mjs': 'application/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.otf': 'font/otf', '.ttf': 'font/ttf', '.wav': 'audio/wav', '.mp3': 'audio/mpeg' };

const server = http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p === '/') p = '/index.html';
  const f = path.join(WEB, p);
  if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
});

// App Store Connect rejects screenshots with an alpha channel.
function saveRgb(buffer, dest) {
  const png = PNG.sync.read(buffer);
  fs.writeFileSync(dest, PNG.sync.write(png, { colorType: 2, inputHasAlpha: true }));
}

server.listen(8799, async () => {
  const only = process.argv.slice(2);
  const browser = await chromium.launch(process.env.CHROME ? { executablePath: process.env.CHROME } : {});
  for (const [device, d] of Object.entries(DEVICES)) {
    if (only.length && !only.includes(device)) continue;
    const dir = path.join(STORE, device);
    fs.mkdirSync(dir, { recursive: true });
    for (const [scene, name] of Object.entries(SCENES)) {
      // Fresh context per scene: each one seeds its own prefs at startup.
      const ctx = await browser.newContext({ viewport: { width: d.w, height: d.h }, deviceScaleFactor: d.scale });
      const page = await ctx.newPage();
      page.on('pageerror', (e) => console.log(device, scene, 'pageerror:', e.message));
      await page.goto(`http://localhost:8799/?s=${scene}`);
      await page.waitForFunction(() => document.querySelector('flt-glass-pane, flutter-view'));
      await page.waitForTimeout(SETTLE[scene] ?? 2500);
      saveRgb(await page.screenshot(), path.join(dir, `${scene}-${name}.png`));
      await ctx.close();
      console.log(device, scene, name);
    }
  }
  await browser.close();
  server.close();
});
