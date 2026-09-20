import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';
import { openTab } from './support/nav';

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
  await openTab(page, 'Resumo');
  await expect(page.getByText('Você economizou')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('ranking tab shows the before/during sections', async ({ page }) => {
  await openTab(page, 'Ranking');
  await expect(page.getByText('Maiores gastos · antes')).toBeVisible();
  await expect(page.getByText('Maiores gastos · durante')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('tempo tab shows the weekday chart', async ({ page }) => {
  await openTab(page, 'Tempo');
  await expect(page.getByText('Por dia da semana')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('tempo tab: tapping a "Por dia" legend item toggles it off and back on', async ({ page }) => {
  await openTab(page, 'Tempo');
  const item = page.getByRole('button', { name: 'toggle-Alimentação' });
  await item.waitFor();
  await expect(item).not.toHaveAttribute('data-hidden');
  await item.click();
  await expect(item).toHaveAttribute('data-hidden', 'true');
  await item.click();
  await expect(item).not.toHaveAttribute('data-hidden');
});

test('cidades tab is reachable and shows the city table', async ({ page }) => {
  await openTab(page, 'Cidades');
  await expect(page.getByText('Resumo por cidade')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('categorias tab shows the category table and the before/during legend toggle', async ({ page }) => {
  await openTab(page, 'Categorias');
  await expect(page.getByText('Ticket médio').first()).toBeVisible();
  const item = page.getByRole('button', { name: 'toggle-during' });
  await item.waitFor();
  await item.click();
  await expect(item).toHaveAttribute('data-hidden', 'true');
  await expectNoHorizontalOverflow(page);
});

test('transações tab is reachable', async ({ page }) => {
  await openTab(page, 'Transações');
  await expect(page.getByPlaceholder('Buscar por descrição')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});
