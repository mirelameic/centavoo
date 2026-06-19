// Headless smoke test. UI defaults to Portuguese.
import { chromium } from 'playwright';

const BASE = process.env.BASE_URL || 'http://localhost:5173';
const errors = [];
const checks = {};

const browser = await chromium.launch();
const page = await browser.newPage();
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
page.on('pageerror', (e) => errors.push(String(e)));
page.on('dialog', (d) => d.accept());

await page.goto(BASE, { waitUntil: 'networkidle' });

await page.getByText('Europa 2026').first().waitFor({ timeout: 15000 });
await page.getByText('Europa 2026').first().click();
await page.getByRole('heading', { name: 'Europa 2026' }).waitFor({ timeout: 10000 });
await page.waitForTimeout(700);
let body = await page.textContent('body');
checks['KPI Antes (14.874)'] = body.includes('14.874');
checks['Split savings card'] = body.includes('economizou');

// Tempo
await page.getByRole('tab', { name: 'Tempo' }).click();
await page.waitForTimeout(600);
body = await page.textContent('body');
checks['Weekday section'] = body.includes('Por dia da semana');
checks['No calendar'] = !body.includes('Calendário');

// Cidades: all days listed, add+select a city, filter by category
await page.getByRole('tab', { name: 'Cidades' }).click();
await page.waitForTimeout(600);
checks['All days listed'] = (await page.locator('input[placeholder="cidade"]').count()) === 18;
const errsBefore = errors.length;
const tags = page.getByRole('combobox', { name: 'Cidades da viagem' });
await tags.click();
await tags.fill('Madrid');
await page.keyboard.press('Enter');
await page.waitForTimeout(300);
await page.locator('input[placeholder="cidade"]').first().click();
await page.getByRole('option', { name: 'Madrid' }).first().click();
await page.waitForTimeout(500);
checks['City select (no crash)'] =
  errors.length === errsBefore && (await page.textContent('body')).includes('Madrid');
// category filter on city summary
await page.getByPlaceholder('todas as categorias').click();
await page.getByRole('option', { name: 'Compras' }).first().click();
await page.waitForTimeout(500);
checks['City filter'] = errors.length === errsBefore && (await page.textContent('body')).includes('Amsterdam');
await page.keyboard.press('Escape');
await page.screenshot({ path: '/tmp/te-cities.png', fullPage: true });

// Categorias tab
await page.getByRole('tab', { name: 'Categorias' }).click();
await page.waitForTimeout(500);
checks['Category table'] = (await page.textContent('body')).includes('Ticket médio');

// Edit trip modal: has delete button
await page.getByLabel('edit-trip').click();
await page.waitForTimeout(300);
body = await page.textContent('body');
checks['Edit trip modal'] = body.includes('Editar viagem');
checks['Delete trip button'] = body.includes('Excluir viagem');
await page.getByRole('button', { name: 'Cancelar' }).click();
await page.waitForTimeout(200);

// Add + single delete + bulk delete
await page.getByRole('button', { name: 'Nova transação' }).click();
await page.getByLabel('Descrição').fill('Smoke Café');
await page.getByLabel('Valor').fill('42');
await page.getByRole('button', { name: 'Salvar' }).click();
await page.waitForTimeout(400);
await page.getByRole('tab', { name: 'Transações' }).click();
await page.waitForTimeout(400);
checks['Add transaction'] = (await page.textContent('body')).includes('Smoke Café');
await page.locator('tr', { hasText: 'Smoke Café' }).getByLabel('delete').click();
await page.waitForTimeout(400);
checks['Delete transaction'] = !(await page.textContent('body')).includes('Smoke Café');
const rowsBefore = await page.getByLabel('select-row').count();
await page.getByLabel('select-row').nth(0).check();
await page.getByLabel('select-row').nth(1).check();
await page.getByRole('button', { name: 'Excluir selecionadas' }).click();
await page.waitForTimeout(500);
checks['Bulk delete'] = (await page.getByLabel('select-row').count()) === rowsBefore - 2;

// Categories page + emoji/color picker
await page.getByRole('link', { name: 'Categorias' }).click();
await page.waitForURL('**/categories');
await page.waitForTimeout(400);
checks['Categories page'] = (await page.textContent('body')).includes('Hospedagem');
await page.getByRole('button', { name: 'Nova categoria' }).click();
await page.waitForTimeout(300);
checks['Emoji picker'] = (await page.getByText('🗺️').count()) > 0;
await page.getByRole('button', { name: 'Cancelar' }).click();

// Export
try {
  const [download] = await Promise.all([
    page.waitForEvent('download', { timeout: 5000 }),
    (async () => {
      await page.getByLabel('menu').click();
      await page.getByRole('menuitem', { name: 'Exportar dados' }).click();
    })(),
  ]);
  checks['Export download'] = /centavoo-backup-.*\.json/.test(download.suggestedFilename());
} catch (e) { checks['Export download'] = false; console.log('export skip:', e.message.split('\n')[0]); }

// Delete trip end-to-end (throwaway trip)
await page.goto(BASE, { waitUntil: 'networkidle' });
await page.getByRole('button', { name: 'Nova viagem' }).click();
await page.getByLabel('Nome').fill('Smoke Trip');
await page.getByRole('button', { name: 'Criar' }).click();
await page.waitForTimeout(400);
await page.getByText('Smoke Trip').first().click();
await page.getByRole('heading', { name: 'Smoke Trip' }).waitFor({ timeout: 8000 });
await page.getByLabel('edit-trip').click();
await page.waitForTimeout(200);
await page.getByRole('button', { name: 'Excluir viagem' }).click();
await page.waitForURL(`${BASE}/`);
await page.waitForTimeout(400);
checks['Delete trip e2e'] = !(await page.textContent('body')).includes('Smoke Trip');

// language toggle (on home)
await page.getByText('EN', { exact: true }).click();
await page.waitForTimeout(300);
checks['EN toggle works'] = (await page.textContent('body')).includes('My trips');

await browser.close();

console.log('\n=== SMOKE TEST ===');
for (const [k, v] of Object.entries(checks)) console.log(`  ${v ? '✅' : '❌'} ${k}`);
console.log(`  console errors: ${errors.length}`);
if (errors.length) console.log(errors.slice(0, 8).map((e) => '    · ' + e).join('\n'));
const ok = Object.values(checks).every(Boolean) && errors.length === 0;
console.log(ok ? '\nPASS ✅' : '\nFAIL ❌');
process.exit(ok ? 0 : 1);
