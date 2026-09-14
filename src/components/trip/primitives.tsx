import { Fragment, type ReactNode } from 'react';
import { Box, Card, Group, Text, UnstyledButton } from '@mantine/core';
import { CategoryIcon } from '../../lib/categoryIcons';
import { ROW_BREAK } from '../../lib/constants';
import { moneyParts } from '../../lib/format';

export function Kpi({ label, value, color }: { label: string; value: string; color?: string }) {
  return (
    <Card withBorder padding="md">
      <Text size="xs" c="dimmed" tt="uppercase" fw={600}>{label}</Text>
      <Text size="xl" fw={700} c={color}>{value}</Text>
    </Card>
  );
}

export function Dot({ color }: { color: string }) {
  return (
    <Box
      component="span"
      w={10}
      h={10}
      style={{ background: color, borderRadius: '50%', display: 'inline-block' }}
    />
  );
}

export function Section({ children, first }: { children: ReactNode; first?: boolean }) {
  return (
    <Text fw={600} size="sm" c="dimmed" mt={first ? 0 : 'xl'} mb="xs">
      {children}
    </Text>
  );
}

export function CategoryChip({
  color,
  name,
  icon,
  gap = 6,
}: {
  color: string;
  name: string;
  icon?: string;
  gap?: number;
}) {
  return (
    <Group gap={gap} wrap="nowrap">
      <Dot color={color} />
      {icon && <CategoryIcon name={icon} size={14} />}
      <Text size="sm">{name}</Text>
    </Group>
  );
}

export function LegendList({
  currency,
  locale,
  rows,
}: {
  currency: string;
  locale: string;
  rows: { key: string; color: string; label: string; icon?: string; amount: number }[];
}) {
  return (
    <Box
      miw={220}
      style={{
        display: 'grid',
        gridTemplateColumns: '1fr auto auto',
        columnGap: 12,
        rowGap: 6,
        alignItems: 'center',
      }}
    >
      {rows.map((r) => {
        const { symbol, value } = moneyParts(r.amount, currency, locale);
        return (
          <Fragment key={r.key}>
            <CategoryChip color={r.color} name={r.label} icon={r.icon} gap={8} />
            <Text size="sm" fw={600}>{symbol}</Text>
            <Text size="sm" fw={600} ta="right">{value}</Text>
          </Fragment>
        );
      })}
    </Box>
  );
}

export function ToggleLegend({
  series,
  hidden,
  onToggle,
}: {
  series: { name: string; color: string; label?: string }[];
  hidden: Set<string>;
  onToggle: (name: string) => void;
}) {
  return (
    <Group gap="md" mt="xs" mb={4}>
      {series.map((s) => {
        const isHidden = hidden.has(s.name);
        return (
          <UnstyledButton
            key={s.name}
            aria-label={`toggle-${s.name}`}
            data-hidden={isHidden || undefined}
            onClick={() => onToggle(s.name)}
            style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '4px 2px' }}
          >
            <Box style={{ opacity: isHidden ? 0.35 : 1 }}>
              <Dot color={s.color} />
            </Box>
            <Text size="sm" c={isHidden ? 'dimmed' : undefined} td={isHidden ? 'line-through' : undefined}>
              {s.label ?? s.name}
            </Text>
          </UnstyledButton>
        );
      })}
    </Group>
  );
}

export function SummaryRow({
  leading,
  meta,
  amount,
}: {
  leading: ReactNode;
  meta: (ReactNode | typeof ROW_BREAK)[];
  amount: ReactNode;
}) {
  return (
    <div className="list-row">
      <div className="list-row-main">
        <div className="list-row-title">{leading}</div>
        <div className="list-row-meta">
          {meta.map((m, i) => {
            if (m === ROW_BREAK) {
              return <span key={i} style={{ flexBasis: '100%', height: 0 }} />;
            }
            const showSep = i > 0 && meta[i - 1] !== ROW_BREAK;
            return (
              <Fragment key={i}>
                {showSep && <span className="list-row-meta-sep">·</span>}
                <span>{m}</span>
              </Fragment>
            );
          })}
        </div>
      </div>
      <Text className="list-row-amount">{amount}</Text>
    </div>
  );
}

export function SplitTag({ count }: { count: number }) {
  if (count <= 1) return null;
  return (
    <Text span size="xs" c="dimmed">
      {' '}(÷{count})
    </Text>
  );
}
