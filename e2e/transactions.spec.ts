import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.getByText('Europa 2026').first().click();
  await page.getByRole('heading', { name: 'Europa 2026' }).waitFor();
  await page.getByRole('tab', { name: 'Transações' }).click();
});

test('adds, then deletes a single transaction', async ({ page }) => {
  await page.getByRole('button', { name: 'Nova transação' }).click();
  await page.getByLabel('Descrição').fill('Playwright Café');
  await page.getByLabel('Valor').fill('42');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Playwright Café')).toBeVisible();

  page.once('dialog', (d) => d.accept());
  await page.locator('tr', { hasText: 'Playwright Café' }).getByLabel('delete').click();
  await expect(page.getByText('Playwright Café')).toHaveCount(0);
});

test('edits an existing transaction description', async ({ page }) => {
  await page.getByRole('button', { name: 'Nova transação' }).click();
  await page.getByLabel('Descrição').fill('Playwright Original');
  await page.getByLabel('Valor').fill('10');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Playwright Original')).toBeVisible();

  await page.locator('tr', { hasText: 'Playwright Original' }).getByLabel('edit').click();
  await page.getByLabel('Descrição').fill('Playwright Edited');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Playwright Edited')).toBeVisible();
  await expect(page.getByText('Playwright Original')).toHaveCount(0);
});

test('selects two rows and bulk-deletes them', async ({ page }) => {
  const before = await page.getByLabel('select-row').count();
  await page.getByLabel('select-row').nth(0).check();
  await page.getByLabel('select-row').nth(1).check();
  page.once('dialog', (d) => d.accept());
  await page.getByRole('button', { name: 'Excluir selecionadas' }).click();
  await expect(page.getByLabel('select-row')).toHaveCount(before - 2);
});

test('filters the list by category', async ({ page }) => {
  // Scoped to the transactions tabpanel: 'todas as categorias' is also the
  // placeholder for the Cidades tab's category filter (src/pages/Trip.tsx),
  // and Mantine keeps a tab panel mounted once visited (Tabs.Panel uses
  // React's <Activity>), so an unscoped locator here would silently break
  // in any test that had visited Cidades first.
  const txPanel = page
    .getByRole('tabpanel')
    .filter({ has: page.getByRole('columnheader', { name: 'Descrição' }) });
  await txPanel.getByPlaceholder('todas as categorias').click();
  await page.getByRole('option', { name: 'Alimentação' }).click();
  await expect(page.getByText('Limpar filtros')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});
