// Headless smoke test: loads the app, checks the Europa seed, opens the trip
// detail, validates KPIs, and captures screenshots of the charts.
// Note: the UI defaults to Portuguese, so assertions use PT labels.
import { chromium } from 'playwright';

const BASE = process.env.BASE_URL || 'http://localhost:5173';
const errors = [];

const browser = await chromium.launch();
const page = await browser.newPage();
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
page.on('pageerror', (e) => errors.push(String(e)));

await page.goto(BASE, { waitUntil: 'networkidle' });

// 1) Seed must have created the "Europa 2026" trip
await page.getByText('Europa 2026').first().waitFor({ timeout: 15000 });
await page.screenshot({ path: '/tmp/te-home.png', fullPage: true });

// 2) Open the detail
await page.getByText('Europa 2026').first().click();
await page.getByRole('heading', { name: 'Europa 2026' }).waitFor({ timeout: 10000 });
await page.waitForTimeout(700); // let the charts animate
const body = await page.textContent('body');

const checks = {
  'KPI Antes (14.874)': body.includes('14.874'),
  'KPI Durante (10.443)': body.includes('10.443'),
  'Has donut (svg)': (await page.locator('svg').count()) > 0,
};
await page.screenshot({ path: '/tmp/te-summary.png', fullPage: true });

// 3) "Por dia" tab (+ city editor)
await page.getByRole('tab', { name: 'Por dia' }).click();
await page.waitForTimeout(700);
await page.screenshot({ path: '/tmp/te-byday.png', fullPage: true });

// Hover a legend item: that series stays opaque, the others should dim.
try {
  await page
    .locator('.recharts-legend-wrapper:visible')
    .getByText('Compras', { exact: true })
    .hover({ timeout: 3000 });
  await page.waitForTimeout(500);
  await page.screenshot({ path: '/tmp/te-byday-hover.png', fullPage: true });
  checks['Legend item hoverable'] = true;
} catch (e) {
  console.log('hover skip:', e.message.split('\n')[0]);
  checks['Legend item hoverable'] = false;
}

// 4) "Por cidade" tab
await page.getByRole('tab', { name: 'Por cidade' }).click();
await page.waitForTimeout(700);
const cityBody = await page.textContent('body');
checks['By city shows Barcelona'] = cityBody.includes('Barcelona');
await page.screenshot({ path: '/tmp/te-bycity.png', fullPage: true });

// 5) Transactions tab (city column + full amount)
await page.getByRole('tab', { name: 'Transações' }).click();
await page.waitForTimeout(400);
await page.screenshot({ path: '/tmp/te-tx.png', fullPage: true });

// 6) Switch language to EN and confirm a label changed
await page.getByText('EN', { exact: true }).click();
await page.waitForTimeout(300);
checks['EN toggle works'] = (await page.textContent('body')).includes('Summary');

await browser.close();

console.log('\n=== SMOKE TEST ===');
for (const [k, v] of Object.entries(checks)) console.log(`  ${v ? '✅' : '❌'} ${k}`);
console.log(`  console errors: ${errors.length}`);
if (errors.length) console.log(errors.slice(0, 8).map((e) => '    · ' + e).join('\n'));
const ok = Object.values(checks).every(Boolean) && errors.length === 0;
console.log(ok ? '\nPASS ✅' : '\nFAIL ❌');
process.exit(ok ? 0 : 1);
