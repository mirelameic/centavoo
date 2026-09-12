import { createTheme } from '@mantine/core';

export const theme = createTheme({
  primaryColor: 'orange',
  defaultRadius: 'lg',
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
    Table: {
      defaultProps: { highlightOnHover: true, verticalSpacing: 'sm' },
    },
    BarChart: {
      defaultProps: {
        gridColor: 'var(--mantine-color-default-border)',
        textColor: 'var(--mantine-color-dimmed)',
      },
    },
    DonutChart: {
      defaultProps: { paddingAngle: 2 },
    },
  },
});
