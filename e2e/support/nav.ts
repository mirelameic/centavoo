import type { Page } from '@playwright/test';

export async function openTab(page: Page, name: string) {
  const desktopTab = page.getByRole('tab', { name });
  if (await desktopTab.isVisible()) {
    await desktopTab.click();
  } else {
    await page.getByRole('button', { name }).click();
  }
}
