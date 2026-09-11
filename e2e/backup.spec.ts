import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';

test('exports a backup file, then imports it back in', async ({ page }) => {
  await page.goto('/');
  await page.getByText('Europa 2026').first().click();
  await page.getByRole('heading', { name: 'Europa 2026' }).waitFor();

  // Ground truth captured before the round trip: the KPI total and the full
  // transaction count (217 rows, from public/europa.json). An `importBackup`
  // that silently no-ops, errors, or corrupts data would fail to reproduce
  // these afterwards — a bare "toast is visible" assertion would not catch
  // any of that.
  await expect(page.getByText('14.874', { exact: false })).toBeVisible();
  await page.getByRole('tab', { name: 'Transações' }).click();
  await expect(page.getByText('217 resultado(s)')).toBeVisible();

  await page.getByLabel('menu').click();
  await expectNoHorizontalOverflow(page);
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.getByRole('menuitem', { name: 'Exportar dados' }).click(),
  ]);
  expect(download.suggestedFilename()).toMatch(/^centavoo-backup-.*\.json$/);
  const filePath = await download.path();
  expect(filePath).toBeTruthy();

  await page.getByLabel('menu').click();
  // Scoped to the settings Menu.Dropdown (role="menu"): this spec visits the
  // Transações tab above to capture ground truth, and that tab's
  // ImportTransactions component also renders a `input[type="file"]` via its
  // own FileButton. Mantine keeps a tab panel mounted once it's been shown
  // (Tabs.Panel uses React's <Activity>), so by this point an unscoped
  // `page.locator('input[type="file"]')` would match 2 elements instead of 1.
  await page.getByRole('menu').locator('input[type="file"]').setInputFiles(filePath!);
  await expect(page.getByText('Backup importado com sucesso.')).toBeVisible();
  await expectNoHorizontalOverflow(page);

  // Reimporting the same export is a safe upsert-by-id no-op (importBackup
  // does a bulkPut keyed by id) — confirm the real data actually survived
  // the round trip, not just the success toast firing.
  await expect(page.getByText('217 resultado(s)')).toBeVisible();
  await expect(page.getByText('14.874', { exact: false })).toBeVisible();
});
