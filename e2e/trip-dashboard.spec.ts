import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.getByText('Europa 2026').first().click();
  await page.getByRole('heading', { name: 'Europa 2026' }).waitFor();
});

test('shows the trip KPIs', async ({ page }) => {
  await expect(page.getByText('14.874', { exact: false })).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('resumo tab shows the split savings card', async ({ page }) => {
  await expect(page.getByText('Você economizou')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('maiores gastos tab shows the before/during sections', async ({ page }) => {
  await page.getByRole('tab', { name: 'Maiores Gastos' }).click();
  await expect(page.getByText('Maiores gastos · antes')).toBeVisible();
  await expect(page.getByText('Maiores gastos · durante')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('tempo tab shows the weekday chart', async ({ page }) => {
  await page.getByRole('tab', { name: 'Tempo' }).click();
  await expect(page.getByText('Por dia da semana')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('tempo tab: tapping a "Por dia" legend item toggles it off and back on', async ({ page }) => {
  await page.getByRole('tab', { name: 'Tempo' }).click();
  const item = page.getByRole('button', { name: 'toggle-Alimentação' });
  await item.waitFor();
  await expect(item).not.toHaveAttribute('data-hidden');
  await item.click();
  await expect(item).toHaveAttribute('data-hidden', 'true');
  await item.click();
  await expect(item).not.toHaveAttribute('data-hidden');
});

test('cidades tab is reachable and shows the city table', async ({ page }) => {
  await page.getByRole('tab', { name: 'Cidades' }).click();
  await expect(page.getByText('Resumo por cidade')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('categorias tab shows the category table and the before/during legend toggle', async ({ page }) => {
  await page.getByRole('tab', { name: 'Categorias' }).click();
  await expect(page.getByText('Ticket médio')).toBeVisible();
  const item = page.getByRole('button', { name: 'toggle-during' });
  await item.waitFor();
  await item.click();
  await expect(item).toHaveAttribute('data-hidden', 'true');
  await expectNoHorizontalOverflow(page);
});

test('transações tab is reachable', async ({ page }) => {
  await page.getByRole('tab', { name: 'Transações' }).click();
  await expect(page.getByRole('columnheader', { name: 'Descrição' })).toBeVisible();
  await expectNoHorizontalOverflow(page);
});
