// Shared UI constants (curated palettes — no arbitrary values).

// Category color choices offered in the Categories editor. A deep, moody
// sunset-leaning palette (rust/gold/berry/wine, grounded by a couple of
// darker greens and neutrals) — never blue-leaning, to match the app's dark
// glass aesthetic (see the `dark` shades note in theme.ts).
export const COLOR_OPTIONS = [
  '#0E8C6B', '#3D8B4C', '#6B8A1E', '#8A7220', '#B8860B', '#C2540D',
  '#C1352E', '#B23368', '#7D1F44', '#9C4221', '#7A4A2A', '#4F7942',
  '#0F7A82', '#5C5650', '#3A3733', '#A8481F',
];

// Colors for the before/during comparison bars.
export const PERIOD_COLORS = { before: '#B8860B', during: '#7A3B12' };

// Minimalist line-icon choices offered in the Categories editor. Rendered via CategoryIcon.
export const ICON_OPTIONS = [
  'plane', 'bed', 'home', 'car', 'train', 'bus', 'bike', 'fuel',
  'food', 'coffee', 'wine', 'shopping', 'gift', 'ticket', 'landmark', 'luggage',
  'backpack', 'beach', 'mountain', 'map', 'phone', 'pill', 'leaf', 'bookmark',
];
