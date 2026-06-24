import { defineConfig } from 'vitest/config';

// Unit tests run in plain Node — the tested code (src/db/stats.ts) is pure
// TypeScript with no DOM or Vite-plugin dependency.
export default defineConfig({
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
});
