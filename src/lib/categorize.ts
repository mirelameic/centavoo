import type { CategoryRule } from '../db/schema';

export function suggestCategory(
  description: string,
  rules: CategoryRule[],
): string | null {
  const d = description.toLowerCase();
  let best: CategoryRule | null = null;
  for (const r of rules) {
    if (!d.includes(r.keyword.toLowerCase())) continue;
    if (
      !best ||
      r.priority > best.priority ||
      (r.priority === best.priority && r.keyword.length > best.keyword.length)
    ) {
      best = r;
    }
  }
  return best?.categoryId ?? null;
}
