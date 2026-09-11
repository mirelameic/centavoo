import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './overflow';

// Regression guard for the bug this helper exists to catch: with
// `overflow-x: hidden` on html/body (src/index.css),
// `document.documentElement.scrollWidth` is clamped to the viewport width and
// can NEVER exceed it, which would make `expectNoHorizontalOverflow` pass on
// every page regardless of actual overflow. These two tests prove the helper
// (a) still passes on a healthy page and (b) actually fails when the page
// really does overflow horizontally.
test('passes on a normal page with no overflow', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByText('Minhas viagens')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('fails when the page content is wider than the viewport', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByText('Minhas viagens')).toBeVisible();
  await page.evaluate(() => {
    const d = document.createElement('div');
    d.style.width = '3000px';
    d.style.height = '1px';
    document.body.appendChild(d);
  });
  await expect(expectNoHorizontalOverflow(page)).rejects.toThrow();
});
