import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';
import { openTab } from './support/nav';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.getByText('Europa 2026').first().click();
  await page.getByRole('heading', { name: 'Europa 2026' }).waitFor();
  await openTab(page, 'Cidades');
});

test('lists the seeded cities and every day covered by a block', async ({ page }) => {
  for (const city of ['Amsterdam', 'Atenas', 'Barcelona', 'Santorini', 'SP']) {
    // Within the Cidades panel itself, a city name legitimately appears more
    // than once at the same time: the donut chart legend, the city summary
    // table, the city pills in "Cidades da viagem", and the date-range block
    // cards in the per-day editor can all name the same city. (This is NOT
    // about other tab panels staying mounted — the "Maiores Gastos" tab is
    // never visited in this spec, so it isn't mounted at all here; Mantine's
    // Tabs.Panel only stays mounted in the DOM once a panel has actually been
    // shown.) `.visible()` restricts the match to on-screen elements before
    // taking the first, which is what actually resolves the ambiguity here.
    await expect(page.getByText(city, { exact: true }).visible().first()).toBeVisible();
  }
  // 7 contiguous date-range blocks cover all 18 trip days — none left over.
  await expect(page.getByText(/dia\(s\) sem cidade/)).toHaveCount(0);
  await expectNoHorizontalOverflow(page);
});

test('adds a city, then removes it with no confirmation since it has no days assigned', async ({ page }) => {
  await page.getByRole('button', { name: 'Adicionar cidade' }).click();
  // Two "cidade"-placeholder fields exist in this panel: the add-city
  // TextInput (first, just revealed) and the block-form's city Select
  // (second) — `.first()` targets the TextInput.
  await page.getByPlaceholder('cidade').first().fill('Madrid');
  await page.getByLabel('confirm-add-city').click();
  // Once "Madrid" is in the city list it also becomes a (closed, hidden)
  // option in the block-form Select's dropdown, so the exact-text locator
  // now resolves to 2 elements — `.first()` keeps this to the visible pill.
  await expect(page.getByText('Madrid', { exact: true }).first()).toBeVisible();

  await page.getByLabel('Remover Madrid').click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page.getByText('Madrid', { exact: true })).toHaveCount(0);
});

test('removing a city that is still assigned to days asks for confirmation, then clears them', async ({ page }) => {
  await page.getByLabel('Remover SP').click();
  await page.getByRole('dialog').getByRole('button', { name: 'Excluir' }).click();
  await expect(page.getByText('SP', { exact: true })).toHaveCount(0);
  // SP covered 2 separate single days (17th and 3rd) — both become unassigned.
  await expect(page.getByText(/2 dia\(s\) sem cidade/)).toBeVisible();
});

test('editing a block switches the form into edit mode', async ({ page }) => {
  await page.getByLabel('edit-city-block').first().click();
  await expect(page.getByRole('button', { name: 'Salvar' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Cancelar' })).toBeVisible();
});

test('removing a block clears just those days', async ({ page }) => {
  await page.getByLabel('delete-city-block').first().click();
  await page.getByRole('dialog').getByRole('button', { name: 'Excluir' }).click();
  // The first block in date order is SP's single day (May 17th).
  await expect(page.getByText(/1 dia\(s\) sem cidade/)).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

// Exercises CityEditor's submit() add path end-to-end: pick a city in the
// block-form Select, pick a date range in the DatePickerInput calendar, click
// "Adicionar período", and confirm the new block actually shows up. Nothing
// else in this suite ever clicks that button, so this is the only E2E
// coverage of setTripCityRange's write path via the real UI.
test('adding a new block picks a city and date range, then it appears in the block list', async ({ page }) => {
  await page.getByRole('button', { name: 'Adicionar cidade' }).click();
  await page.getByPlaceholder('cidade').first().fill('Playwright City');
  await page.getByLabel('confirm-add-city').click();
  await expect(page.getByText('Playwright City', { exact: true }).first()).toBeVisible();

  // Pick it in the block-add form's city Select (label "Cidade"). Scoped by
  // role + exact name: a plain `getByLabel('Cidade')` substring-matches the
  // "Cidades" tabpanel's own accessible name too (from the tab's label),
  // and matches the Select's own listbox in addition to its combobox input.
  await page.getByRole('combobox', { name: 'Cidade', exact: true }).click();
  await page.getByRole('option', { name: 'Playwright City', exact: true }).click();

  // Open the block-form's range DatePickerInput (label "Período"). It opens
  // on the real current month, not the Europa trip's month, since no
  // `defaultDate` is set — so navigate the calendar to May 2026 first, using
  // the header's month/year label (rendered as plain text, no aria-label) and
  // the previous/next controls (identified by their `data-direction`
  // attribute — Mantine doesn't give them a default aria-label either).
  await page.getByLabel('Período').click();
  const monthLabel = page.getByRole('button', { name: /^[A-Za-z]+ \d{4}$/ });
  const MONTHS = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  const targetIndex = 2026 * 12 + MONTHS.indexOf('May');
  for (let i = 0; i < 48; i++) {
    const text = (await monthLabel.textContent())?.trim() ?? '';
    const [name, yearStr] = text.split(' ');
    const currentIndex = Number(yearStr) * 12 + MONTHS.indexOf(name);
    if (currentIndex === targetIndex) break;
    const direction = currentIndex > targetIndex ? 'previous' : 'next';
    await page.locator(`button[data-direction="${direction}"]`).click();
  }
  await expect(monthLabel).toHaveText('May 2026');

  // 20-21 May currently belong to Atenas (see public/europa.json) — both
  // days stay within the trip's range, so the new block renders immediately
  // (CityEditor's block list only shows blocks for days in the trip's own
  // range/transaction dates; see src/lib/format.ts's groupCityBlocks).
  await page.getByRole('button', { name: '20 May 2026', exact: true }).click();
  await page.getByRole('button', { name: '21 May 2026', exact: true }).click();

  await page.getByRole('button', { name: 'Adicionar período' }).click();

  const newBlock = page
    .locator('div', { hasText: 'Playwright City' })
    .filter({ has: page.getByLabel('edit-city-block') })
    .last();
  await expect(newBlock).toBeVisible();
  await expect(newBlock.getByText('2 dia(s)')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});
