import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';

test('creates a trip, opens it, then deletes it end-to-end', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Nova viagem' }).click();
  await page.getByLabel('Nome').fill('Playwright Trip');
  await page.getByRole('button', { name: 'Criar' }).click();

  await page.getByText('Playwright Trip').first().click();
  await page.getByRole('heading', { name: 'Playwright Trip' }).waitFor();
  await expectNoHorizontalOverflow(page);

  await page.getByLabel('edit-trip').click();
  page.once('dialog', (d) => d.accept());
  await page.getByRole('button', { name: 'Excluir viagem' }).click();

  await page.waitForURL('/');
  await expect(page.getByText('Playwright Trip')).toHaveCount(0);
  await expectNoHorizontalOverflow(page);
});
