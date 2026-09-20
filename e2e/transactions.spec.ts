import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';
import { openTab } from './support/nav';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.getByText('Europa 2026').first().click();
  await page.getByRole('heading', { name: 'Europa 2026' }).waitFor();
  await openTab(page, 'Transações');
});

test('adds, then deletes a single transaction', async ({ page }) => {
  await page.getByRole('button', { name: 'Nova transação' }).click();
  await page.getByLabel('Descrição').fill('Playwright Café');
  await page.getByLabel('Valor').fill('42');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Playwright Café')).toBeVisible();

  const row = page.locator('.list-row', { hasText: 'Playwright Café' });
  await row.getByLabel('more-actions').click();
  await page.getByRole('menuitem', { name: 'Excluir' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'Excluir' }).click();
  await expect(page.getByText('Playwright Café')).toHaveCount(0);
});

test('edits an existing transaction description', async ({ page }) => {
  await page.getByRole('button', { name: 'Nova transação' }).click();
  await page.getByLabel('Descrição').fill('Playwright Original');
  await page.getByLabel('Valor').fill('10');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Playwright Original')).toBeVisible();

  const row = page.locator('.list-row', { hasText: 'Playwright Original' });
  await row.getByLabel('more-actions').click();
  await page.getByRole('menuitem', { name: 'Editar' }).click();
  await page.getByLabel('Descrição').fill('Playwright Edited');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Playwright Edited')).toBeVisible();
  await expect(page.getByText('Playwright Original')).toHaveCount(0);
});

test('selects two rows and bulk-deletes them', async ({ page }) => {
  await page.getByRole('button', { name: 'Selecionar' }).click();
  const before = await page.getByLabel('select-row').count();
  await page.getByLabel('select-row').nth(0).check({ force: true });
  await page.getByLabel('select-row').nth(1).check({ force: true });
  await page.getByRole('button', { name: 'Excluir selecionadas' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'Excluir' }).click();
  await expect(page.getByLabel('select-row')).toHaveCount(before - 2);
});

test('filters the list by category', async ({ page }) => {
  const txPanel = page
    .getByRole('tabpanel')
    .filter({ has: page.getByPlaceholder('Buscar por descrição') });
  await txPanel.getByPlaceholder('todas as categorias').click();
  await page.getByRole('option', { name: 'Alimentação' }).click();
  await expect(page.getByText('Limpar filtros')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('filters the list by description search', async ({ page }) => {
  await page.getByPlaceholder('Buscar por descrição').fill('uber');
  await expect(page.getByText(/^\d+ resultado/)).toBeVisible();
  for (const desc of await page.locator('.list-row-title').allTextContents()) {
    expect(desc.toLowerCase()).toContain('uber');
  }
  await expectNoHorizontalOverflow(page);
});
