import { expect, type Page } from '@playwright/test';

// Fails the test if the page is wider than the viewport — the exact bug
// class found and fixed in this app (tables/tabs pushing the whole page
// sideways on narrow screens). Cheap to call after every navigation.
//
// NOTE: this deliberately reads `document.body.scrollWidth`, NOT
// `document.documentElement.scrollWidth`. `src/index.css` sets
// `overflow-x: hidden` on `html`/`body`/`#root`, which clamps
// `document.documentElement.scrollWidth` to the viewport width no matter how
// wide the content actually is — that would make this assertion vacuously
// true on every page. `document.body.scrollWidth` is not clamped the same
// way and reflects the real layout width of the content inside `<body>`,
// which is what we actually want to catch. See e2e/support/overflow.spec.ts
// for a regression test proving this can still fail.
export async function expectNoHorizontalOverflow(page: Page) {
  const { content, viewport } = await page.evaluate(() => ({
    content: document.body.scrollWidth,
    viewport: document.documentElement.clientWidth,
  }));
  expect(content, 'page content should not be wider than the viewport')
    .toBeLessThanOrEqual(viewport + 1);
}
