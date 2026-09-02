import type { ReactNode } from 'react';
import { Box, Card, Group, Text } from '@mantine/core';

// Small presentational pieces shared across the Trip dashboard.

export function Kpi({ label, value, color }: { label: string; value: string; color?: string }) {
  return (
    <Card withBorder padding="md">
      <Text size="xs" c="dimmed" tt="uppercase" fw={600}>{label}</Text>
      <Text size="xl" fw={700} c={color}>{value}</Text>
    </Card>
  );
}

// Colored square used as a legend marker next to a category/city name.
function Dot({ color }: { color: string }) {
  return (
    <Box
      component="span"
      w={10}
      h={10}
      style={{ background: color, borderRadius: 3, display: 'inline-block' }}
    />
  );
}

// Section heading inside a tab (each tab groups a few related views).
export function Section({ children, first }: { children: ReactNode; first?: boolean }) {
  return (
    <Text fw={600} size="sm" c="dimmed" mt={first ? 0 : 'xl'} mb="xs">
      {children}
    </Text>
  );
}

// Category/city label with its color dot — the recurring "legend row" look
// used in charts, tables and lists across the Trip dashboard.
export function CategoryChip({ color, name, gap = 6 }: { color: string; name: string; gap?: number }) {
  return (
    <Group gap={gap} wrap="nowrap">
      <Dot color={color} />
      <Text size="sm">{name}</Text>
    </Group>
  );
}

// "(÷n)" note next to a description, shown when a transaction is split.
export function SplitTag({ count }: { count: number }) {
  if (count <= 1) return null;
  return (
    <Text span size="xs" c="dimmed">
      {' '}(÷{count})
    </Text>
  );
}
