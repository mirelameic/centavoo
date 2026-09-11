import { describe, it, expect } from 'vitest';
import { suggestCategory } from './categorize';
import type { CategoryRule } from '../db/schema';

function rule(p: Partial<CategoryRule> & { keyword: string; categoryId: string }): CategoryRule {
  return { priority: 0, ...p };
}

describe('suggestCategory', () => {
  it('returns null when no rule matches', () => {
    expect(suggestCategory('Uber para o hotel', [])).toBeNull();
  });

  it('matches a keyword as a case-insensitive substring', () => {
    const rules = [rule({ keyword: 'uber', categoryId: 'cat-transport' })];
    expect(suggestCategory('UBER *TRIP', rules)).toBe('cat-transport');
  });

  it('picks the highest-priority match when two rules match', () => {
    const rules = [
      rule({ keyword: 'uber', categoryId: 'cat-transport', priority: 1 }),
      rule({ keyword: 'eats', categoryId: 'cat-food', priority: 5 }),
    ];
    expect(suggestCategory('UBER EATS *ORDER', rules)).toBe('cat-food');
  });

  it('breaks a priority tie with the longer (more specific) keyword', () => {
    const rules = [
      rule({ keyword: 'uber', categoryId: 'cat-transport', priority: 1 }),
      rule({ keyword: 'uber eats', categoryId: 'cat-food', priority: 1 }),
    ];
    expect(suggestCategory('UBER EATS *ORDER', rules)).toBe('cat-food');
  });

  it('matches a keyword appearing anywhere in the description, not just at word boundaries', () => {
    const rules = [rule({ keyword: 'ber', categoryId: 'cat-transport' })];
    expect(suggestCategory('Uber Trip', rules)).toBe('cat-transport');
  });

  it('ignores rules that do not match at all, even with higher priority', () => {
    const rules = [
      rule({ keyword: 'padaria', categoryId: 'cat-food', priority: 100 }),
      rule({ keyword: 'uber', categoryId: 'cat-transport', priority: 1 }),
    ];
    expect(suggestCategory('UBER *TRIP', rules)).toBe('cat-transport');
  });
});
