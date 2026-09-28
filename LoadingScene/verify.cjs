const { chromium } = require('@playwright/test');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../Resources/Loading');
const output = path.resolve(__dirname, '../outputs/loading-qa');
fs.mkdirSync(output, { recursive: true });
const server = http.createServer((req, res) => {
  const file = path.join(root, req.url === '/' ? 'index.html' : req.url.slice(1));
  if (!file.startsWith(root + path.sep) || !fs.existsSync(file)) { res.writeHead(404).end(); return; }
  res.setHeader('Content-Type', file.endsWith('.js') ? 'text/javascript' : 'text/html');
  res.end(fs.readFileSync(file));
});
async function sample(page) {
  return page.evaluate(() => {
    window.setLoadingAnimation(true);
    const canvas = document.querySelector('canvas');
    const gl = canvas.getContext('webgl2');
    const w = gl.drawingBufferWidth, h = gl.drawingBufferHeight;
    const pixels = new Uint8Array(w * h * 4);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
    let count = 0, left = w, right = 0, bottom = h, top = 0, checksum = 0;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const i = (y * w + x) * 4;
      if (pixels[i + 3] > 80) {
        count++; left = Math.min(left, x); right = Math.max(right, x);
        bottom = Math.min(bottom, y); top = Math.max(top, y);
        checksum = (checksum + (i % 997) * (pixels[i] + pixels[i + 1])) % 2147483647;
      }
    }
    return { count, left, right, bottom, top, w, h, checksum };
  });
}
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({ channel: 'chrome', headless: true });
    const page = await browser.newPage({ colorScheme: 'dark', deviceScaleFactor: 2 });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    for (const [width, height] of [[1040, 660], [1920, 1080], [390, 844]]) {
      await page.setViewportSize({ width, height });
      await page.goto(`http://127.0.0.1:${server.address().port}`);
      await page.waitForFunction(() => !!window.setLoadingAnimation);
      const first = await sample(page);
      assert.equal(first.w, width * 2, 'Retina-width canvas');
      assert.equal(first.h, height * 2, 'Retina-height canvas');
      assert(first.count > 1000, 'Scene is nonblank');
      assert(first.left > 0 && first.right < first.w - 1 && first.bottom > 0 && first.top < first.h - 1, 'Books fit in viewport');
      await page.screenshot({ path: path.join(output, `${width}x${height}.png`) });
      await page.waitForTimeout(450);
      const second = await sample(page);
      assert.notEqual(first.checksum, second.checksum, 'Scene is moving');
      await page.mouse.move(width * 0.8, height * 0.2);
      const pointer = await sample(page);
      assert.notEqual(pointer.checksum, second.checksum, 'Pointer changes the view');
      console.log(`PASS ${width}x${height}: visible, framed, moving, interactive`);
    }
    await page.emulateMedia({ reducedMotion: 'reduce' });
    const still = await sample(page);
    await page.waitForTimeout(200);
    assert.equal(still.checksum, (await sample(page)).checksum, 'Reduced motion stays still');
    assert.deepEqual(errors, []);
    console.log('PASS reduced motion and no browser errors');
  } finally {
    if (browser) await browser.close();
    server.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
