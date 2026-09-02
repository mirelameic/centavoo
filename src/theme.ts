import { createTheme } from '@mantine/core';

// Warm "glass" look: orange accent, translucent blurred panels (see .glass-panel
// in index.css, which supplies the actual background/border per color scheme).
export const theme = createTheme({
  primaryColor: 'orange',
  defaultRadius: 'lg',
  // Mantine's default `dark` shades lean cool/blue-gray, which reads as purple
  // once tinted by the orange glow behind the glass panels. Swap in a neutral
  // warm-gray scale instead (used for Tabs, Menu, Modal, Table, etc.).
  colors: {
    dark: [
      '#C9C7C3',
      '#ABA9A4',
      '#8F8D88',
      '#6B6965',
      '#4A4844',
      '#3A3835',
      '#2E2C2A',
      '#242220',
      '#1B1A18',
      '#131211',
    ],
  },
  fontFamily:
    '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
  components: {
    Card: {
      defaultProps: { className: 'glass-panel' },
    },
    AppShellHeader: {
      defaultProps: { className: 'glass-panel' },
    },
    Modal: {
      defaultProps: { overlayProps: { backgroundOpacity: 0.55, blur: 4 } },
    },
  },
});
