import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.getByText('Europa 2026').first().click();
  await page.getByRole('heading', { name: 'Europa 2026' }).waitFor();
  await page.getByRole('link', { name: 'Categorias' }).click();
  await page.waitForURL('**/categories');
});

test('lists the default categories', async ({ page }) => {
  await expect(page.getByText('Hospedagem')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('creates a category with a name, color and icon', async ({ page }) => {
  await page.getByRole('button', { name: 'Nova categoria' }).click();
  await page.getByLabel('Nome').fill('Playwright Cat');
  await page.locator('svg.tabler-icon-map').click();
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Playwright Cat')).toBeVisible();

  // Confirm the icon actually persisted — Categories.tsx renders each row's
  // icon via <CategoryIcon name={c.icon} .../>, so a broken icon-select
  // write path would still leave this test green if only the name is
  // checked.
  const row = page.locator('div', { hasText: 'Playwright Cat' }).filter({ has: page.getByLabel('edit') }).last();
  await expect(row.locator('svg.tabler-icon-map')).toBeVisible();
});

test('edits an existing category name', async ({ page }) => {
  const row = page
    .locator('div', { hasText: 'Hospedagem' })
    .filter({ has: page.getByLabel('edit') })
    .last();
  await row.getByLabel('edit').click();
  await page.getByLabel('Nome').fill('Hospedagem 2');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Hospedagem 2')).toBeVisible();
});

test('deletes a category after confirming', async ({ page }) => {
  await page.getByRole('button', { name: 'Nova categoria' }).click();
  await page.getByLabel('Nome').fill('Delete Me');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Delete Me')).toBeVisible();

  const row = page
    .locator('div', { hasText: 'Delete Me' })
    .filter({ has: page.getByLabel('delete') })
    .last();
  page.once('dialog', (d) => d.accept());
  await row.getByLabel('delete').click();
  await expect(page.getByText('Delete Me')).toHaveCount(0);
});
