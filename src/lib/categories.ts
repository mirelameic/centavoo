import type { Category } from '../db/schema';

export function toCatById(categories: Category[]): Map<string, Category> {
  return new Map(categories.map((c) => [c.id, c] as const));
}
