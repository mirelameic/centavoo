import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';

test('the PT/EN toggle switches the visible language', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByText('Minhas viagens')).toBeVisible();
  await page.getByText('EN', { exact: true }).click();
  await expect(page.getByText('My trips')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});
