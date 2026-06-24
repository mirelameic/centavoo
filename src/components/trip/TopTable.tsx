import { Group, Table, Text } from '@mantine/core';
import type { Category, CityMap, Transaction } from '../../db/schema';
import { cost } from '../../db/stats';
import { useI18n } from '../../i18n';
import { Dot } from './primitives';

// Compact "top spends" table (description · category · city · date · amount).
export function TopTable({
  items,
  catById,
  cities,
  cur,
}: {
  items: Transaction[];
  catById: Map<string, Category>;
  cities: CityMap;
  cur: string;
}) {
  const { money, date } = useI18n();
  return (
    <Table>
      <Table.Tbody>
        {items.map((tx) => {
          const c = tx.categoryId ? catById.get(tx.categoryId) : undefined;
          return (
            <Table.Tr key={tx.id}>
              <Table.Td>
                {tx.description}
                {tx.splitCount > 1 && <Text span size="xs" c="dimmed"> (÷{tx.splitCount})</Text>}
              </Table.Td>
              <Table.Td>
                {c ? (
                  <Group gap={6} wrap="nowrap"><Dot color={c.color} /><Text size="sm">{c.name}</Text></Group>
                ) : '—'}
              </Table.Td>
              <Table.Td><Text size="sm" c="dimmed">{(tx.date && cities[tx.date]) || '—'}</Text></Table.Td>
              <Table.Td><Text size="sm" c="dimmed">{date(tx.date)}</Text></Table.Td>
              <Table.Td ta="right" fw={600}>{money(cost(tx), cur)}</Table.Td>
            </Table.Tr>
          );
        })}
      </Table.Tbody>
    </Table>
  );
}
