import { useMemo, useState, type ReactNode } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  Container,
  Title,
  Text,
  Group,
  Stack,
  SimpleGrid,
  Card,
  Tabs,
  Table,
  Badge,
  Anchor,
  Center,
  Loader,
  ScrollArea,
  Box,
  Button,
  ActionIcon,
  Checkbox,
  Select,
  TagsInput,
} from '@mantine/core';
import { useDisclosure } from '@mantine/hooks';
import { DonutChart, BarChart } from '@mantine/charts';
import { IconArrowLeft, IconPlus, IconPencil, IconTrash, IconCategory } from '@tabler/icons-react';
import { db } from '../db/db';
import {
  computeStats,
  cost,
  setTripCity,
  updateTrip,
  deleteTransaction,
  deleteTransactions,
} from '../db/repo';
import type { Transaction, Category } from '../db/schema';
import { TransactionForm } from '../components/TransactionForm';
import { TripForm } from '../components/TripForm';
import { useI18n } from '../i18n';

function Kpi({ label, value, color }: { label: string; value: string; color?: string }) {
  return (
    <Card withBorder padding="md">
      <Text size="xs" c="dimmed" tt="uppercase" fw={600}>{label}</Text>
      <Text size="xl" fw={700} c={color}>{value}</Text>
    </Card>
  );
}

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
function Section({ children, first }: { children: ReactNode; first?: boolean }) {
  return (
    <Text fw={600} size="sm" c="dimmed" mt={first ? 0 : 'xl'} mb="xs">
      {children}
    </Text>
  );
}

// Compact "top spends" table (description · category · city · date · amount).
function TopTable({
  items,
  catById,
  cities,
  cur,
}: {
  items: Transaction[];
  catById: Map<string, Category>;
  cities: Record<string, string>;
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

const PERIOD_COLORS = { antes: '#4c6ef5', durante: '#cc5de8' };

// Left-align the built-in (interactive) chart legend — Mantine defaults it to flex-end.
const leftLegend = { legend: { justifyContent: 'flex-start' as const } };

// Editable city per day. First you list the trip's cities (TagsInput), then pick
// one per day from a dropdown. Stored on the trip (a day = a city); days flow
// top-to-bottom in date order via CSS columns.
function CityEditor({
  tripId,
  days,
  cities,
  cityList,
}: {
  tripId: string;
  days: string[];
  cities: Record<string, string>;
  cityList?: string[];
}) {
  const { t, date } = useI18n();
  const distinct = [...new Set(Object.values(cities).filter(Boolean))].sort();
  const listValue = cityList ?? distinct;
  const options = [...new Set([...listValue, ...distinct])].sort();
  return (
    <Stack gap="sm">
      <TagsInput
        label={t('city.list')}
        placeholder={t('city.listPlaceholder')}
        value={listValue}
        onChange={(vals) => updateTrip(tripId, { cityList: vals })}
        clearable
      />
      <Box style={{ columnWidth: 240, columnGap: 16 }}>
        {days.map((d) => (
          <Group key={d} gap="xs" wrap="nowrap" style={{ breakInside: 'avoid', marginBottom: 8 }}>
            <Text size="sm" c="dimmed" w={56}>{date(d)}</Text>
            <Select
              size="xs"
              placeholder={t('city.placeholder')}
              data={options}
              value={cities[d] ?? null}
              onChange={(v) => setTripCity(tripId, d, v ?? '')}
              searchable
              clearable
              style={{ flex: 1 }}
            />
          </Group>
        ))}
      </Box>
    </Stack>
  );
}

// Inclusive list of 'YYYY-MM-DD' dates between start and end.
function dateRange(start: string, end: string): string[] {
  const out: string[] = [];
  const p = (n: number) => String(n).padStart(2, '0');
  const e = new Date(end + 'T00:00:00');
  for (let d = new Date(start + 'T00:00:00'); d <= e; d.setDate(d.getDate() + 1)) {
    out.push(`${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`);
  }
  return out;
}

export function Trip() {
  const { t, money, date, locale } = useI18n();
  const { id = '' } = useParams();
  const trip = useLiveQuery(() => db.trips.get(id), [id]);
  const cats = useLiveQuery(
    () => db.categories.where('tripId').equals(id).sortBy('sortOrder'),
    [id],
  );
  const txs = useLiveQuery(
    () => db.transactions.where('tripId').equals(id).toArray(),
    [id],
  );
  const rules = useLiveQuery(() => db.rules.toArray(), []) ?? [];

  const [formOpened, { open: openForm, close: closeForm }] = useDisclosure(false);
  const [tripFormOpened, { open: openTripForm, close: closeTripForm }] = useDisclosure(false);
  const [editingTx, setEditingTx] = useState<Transaction | null>(null);
  const openAdd = () => { setEditingTx(null); openForm(); };
  const openEdit = (tx: Transaction) => { setEditingTx(tx); openForm(); };
  const removeTx = async (tx: Transaction) => {
    if (window.confirm(t('tx.deleteConfirm'))) await deleteTransaction(tx.id);
  };

  const [selected, setSelected] = useState<Set<string>>(new Set());
  const toggleSel = (txId: string) =>
    setSelected((s) => {
      const n = new Set(s);
      if (n.has(txId)) n.delete(txId);
      else n.add(txId);
      return n;
    });
  const bulkDelete = async () => {
    if (selected.size && window.confirm(t('tx.deleteSelectedConfirm'))) {
      await deleteTransactions([...selected]);
      setSelected(new Set());
    }
  };

  const stats = useMemo(
    () => (txs && cats && trip ? computeStats(txs, cats, trip.cities ?? {}) : null),
    [txs, cats, trip],
  );
  const catById = useMemo(
    () => new Map((cats ?? []).map((c) => [c.id, c] as const)),
    [cats],
  );

  if (trip === undefined || !stats) {
    return <Center mih="50vh"><Loader /></Center>;
  }
  if (trip === null) {
    return (
      <Container size="lg" px={0}>
        <Text>{t('trip.notFound')}</Text>
        <Anchor component={Link} to="/">{t('common.back')}</Anchor>
      </Container>
    );
  }

  const cur = trip.currency;
  const cities = trip.cities ?? {};
  // Days shown in the city editor: the trip's date range UNION every day that
  // already has a transaction (so changing the trip dates never orphans a day).
  const txDates = (txs ?? []).filter((tx) => tx.date).map((tx) => tx.date as string);
  const rangeDays = trip.startDate && trip.endDate ? dateRange(trip.startDate, trip.endDate) : [];
  const tripDays = [...new Set([...rangeDays, ...txDates])].sort();
  const donut = stats.byCategory.map((c) => ({ name: c.name, value: c.amount, color: c.color }));
  const cityDonut = stats.byCity.map((c) => ({ name: c.city, value: c.amount, color: c.color }));

  const dayKeys = new Set<string>();
  stats.dayData.forEach((r) => Object.keys(r).forEach((k) => k !== 'date' && dayKeys.add(k)));
  const daySeries = stats.usedCategories
    .filter((c) => dayKeys.has(c.name))
    .map((c) => ({ name: c.name, color: c.color }));

  // Spending by weekday (Mon → Sun), labels localized.
  const wdFmt = new Intl.DateTimeFormat(locale, { weekday: 'short' });
  const weekdayData = [1, 2, 3, 4, 5, 6, 0].map((wd) => ({
    day: wdFmt.format(new Date(2023, 0, 1 + wd)),
    amount: stats.weekdayAmounts[wd],
  }));

  const hasSplit = (txs ?? []).some((tx) => tx.splitCount > 1);
  const topBy = (period: 'BEFORE' | 'DURING') =>
    [...(txs ?? [])]
      .filter((tx) => tx.period === period && cost(tx) > 0)
      .sort((a, b) => cost(b) - cost(a))
      .slice(0, 10);
  const topBefore = topBy('BEFORE');
  const topDuring = topBy('DURING');

  const sortedTx = [...(txs ?? [])].sort((a, b) => {
    if (a.period !== b.period) return a.period === 'BEFORE' ? -1 : 1;
    return (a.date ?? '').localeCompare(b.date ?? '');
  });

  return (
    <Container size="lg" px={0}>
      <Anchor component={Link} to="/" mb="sm" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
        <IconArrowLeft size={16} /> {t('nav.trips')}
      </Anchor>
      <Group justify="space-between" align="flex-end" mb="md">
        <div>
          <Group gap={6}>
            <Title order={2}>{trip.name}</Title>
            <ActionIcon variant="subtle" color="gray" onClick={openTripForm} aria-label="edit-trip">
              <IconPencil size={18} />
            </ActionIcon>
          </Group>
          {trip.destination && <Text c="dimmed">{trip.destination}</Text>}
          <Text c="dimmed" size="sm">{date(trip.startDate)} – {date(trip.endDate)}</Text>
        </div>
        <Group gap="xs">
          <Button
            variant="default"
            leftSection={<IconCategory size={18} />}
            renderRoot={(props) => <Link to={`/trip/${trip.id}/categories`} {...props} />}
          >
            {t('menu.categories')}
          </Button>
          <Button leftSection={<IconPlus size={18} />} onClick={openAdd}>{t('tx.new')}</Button>
        </Group>
      </Group>

      <SimpleGrid cols={{ base: 1, sm: 3 }} spacing="sm" mb="lg">
        <Kpi label={t('kpi.net')} value={money(stats.net, cur)} />
        <Kpi label={t('kpi.gross')} value={money(stats.gross, cur)} />
        <Kpi label={t('kpi.refunds')} value={money(stats.refunds, cur)} color="teal" />
        <Kpi label={t('kpi.before')} value={money(stats.before, cur)} />
        <Kpi label={t('kpi.during')} value={money(stats.during, cur)} />
        <Kpi label={t('kpi.avgPerDay')} value={money(stats.avgPerDay, cur)} />
      </SimpleGrid>

      <Tabs defaultValue="summary">
        <Tabs.List mb="md">
          <Tabs.Tab value="summary">{t('tab.summary')}</Tabs.Tab>
          <Tabs.Tab value="time">{t('tab.time')}</Tabs.Tab>
          <Tabs.Tab value="cities">{t('tab.cities')}</Tabs.Tab>
          <Tabs.Tab value="cats">{t('tab.cats')}</Tabs.Tab>
          <Tabs.Tab value="tx">{t('tab.transactions')}</Tabs.Tab>
        </Tabs.List>

        {/* ============ RESUMO ============ */}
        <Tabs.Panel value="summary">
          <Card withBorder padding="lg">
            <Group align="flex-start" justify="center" gap="xl" wrap="wrap">
              <DonutChart
                data={donut}
                size={240}
                thickness={34}
                withTooltip
                tooltipDataSource="segment"
                chartLabel={money(stats.gross, cur)}
                valueFormatter={(v) => money(v, cur)}
              />
              <Stack gap={6} miw={240}>
                {stats.byCategory.map((c) => (
                  <Group key={c.name} justify="space-between">
                    <Group gap={8}><Dot color={c.color} /><Text size="sm">{c.name}</Text></Group>
                    <Text size="sm" fw={600}>{money(c.amount, cur)}</Text>
                  </Group>
                ))}
              </Stack>
            </Group>

            {hasSplit && (
              <>
                <Section>{t('sec.split')}</Section>
                <SimpleGrid cols={{ base: 3 }} spacing="sm">
                  <Card withBorder padding="sm">
                    <Text size="xs" c="dimmed" tt="uppercase">{t('split.integral')}</Text>
                    <Text fw={700}>{money(stats.split.integral, cur)}</Text>
                  </Card>
                  <Card withBorder padding="sm">
                    <Text size="xs" c="dimmed" tt="uppercase">{t('split.share')}</Text>
                    <Text fw={700}>{money(stats.split.share, cur)}</Text>
                  </Card>
                  <Card withBorder padding="sm">
                    <Text size="xs" c="dimmed" tt="uppercase">{t('split.savings')}</Text>
                    <Text fw={700} c="teal">{money(stats.split.savings, cur)}</Text>
                  </Card>
                </SimpleGrid>
              </>
            )}

            {topBefore.length > 0 && (
              <>
                <Section>{t('sec.topBefore')}</Section>
                <TopTable items={topBefore} catById={catById} cities={cities} cur={cur} />
              </>
            )}
            {topDuring.length > 0 && (
              <>
                <Section>{t('sec.topDuring')}</Section>
                <TopTable items={topDuring} catById={catById} cities={cities} cur={cur} />
              </>
            )}
          </Card>
        </Tabs.Panel>

        {/* ============ TEMPO ============ */}
        <Tabs.Panel value="time">
          <Card withBorder padding="lg">
            <Section first>{t('sec.byDay')}</Section>
            {stats.dayData.length ? (
              <BarChart
                h={340}
                data={stats.dayData}
                dataKey="date"
                type="stacked"
                series={daySeries}
                valueFormatter={(v) => money(v, cur)}
                yAxisProps={{ width: 88 }}
                withLegend
                legendProps={{ verticalAlign: 'bottom' }}
                styles={leftLegend}
              />
            ) : (
              <Text c="dimmed">{t('chart.noDated')}</Text>
            )}

            <Section>{t('sec.weekday')}</Section>
            <BarChart
              h={280}
              data={weekdayData}
              dataKey="day"
              series={[{ name: 'amount', color: 'grape.5', label: t('table.amount') }]}
              valueFormatter={(v) => money(v, cur)}
              barProps={{ radius: 8 }}
              gridAxis="none"
              withYAxis={false}
              withBarValueLabel
            />
          </Card>
        </Tabs.Panel>

        {/* ============ CIDADES ============ */}
        <Tabs.Panel value="cities">
          <Card withBorder padding="lg">
            {cityDonut.length ? (
              <>
                <Section first>{t('sec.byCity')}</Section>
                <Group align="flex-start" justify="center" gap="xl" wrap="wrap">
                  <DonutChart
                    data={cityDonut}
                    size={220}
                    thickness={32}
                    withTooltip
                    tooltipDataSource="segment"
                    valueFormatter={(v) => money(v, cur)}
                  />
                  <Stack gap={6} miw={220}>
                    {stats.byCity.map((c) => (
                      <Group key={c.city} justify="space-between">
                        <Group gap={8}><Dot color={c.color} /><Text size="sm">{c.city}</Text></Group>
                        <Text size="sm" fw={600}>{money(c.amount, cur)}</Text>
                      </Group>
                    ))}
                  </Stack>
                </Group>

                <Section>{t('sec.cityTable')}</Section>
                <Table>
                  <Table.Thead>
                    <Table.Tr>
                      <Table.Th>{t('table.city')}</Table.Th>
                      <Table.Th ta="right">{t('col.days')}</Table.Th>
                      <Table.Th ta="right">{t('col.total')}</Table.Th>
                      <Table.Th ta="right">{t('col.avgDay')}</Table.Th>
                      <Table.Th>{t('col.topCat')}</Table.Th>
                    </Table.Tr>
                  </Table.Thead>
                  <Table.Tbody>
                    {stats.cityTable.map((c) => (
                      <Table.Tr key={c.city}>
                        <Table.Td>{c.city}</Table.Td>
                        <Table.Td ta="right">{c.days}</Table.Td>
                        <Table.Td ta="right">{money(c.total, cur)}</Table.Td>
                        <Table.Td ta="right">{money(c.avgPerDay, cur)}</Table.Td>
                        <Table.Td><Text size="sm" c="dimmed">{c.topCategory}</Text></Table.Td>
                      </Table.Tr>
                    ))}
                  </Table.Tbody>
                </Table>
              </>
            ) : (
              <Text c="dimmed">{t('chart.noCity')}</Text>
            )}

            {tripDays.length > 0 && (
              <>
                <Section>{t('city.perDay')}</Section>
                <CityEditor tripId={trip.id} days={tripDays} cities={cities} cityList={trip.cityList} />
              </>
            )}
          </Card>
        </Tabs.Panel>

        {/* ============ CATEGORIAS ============ */}
        <Tabs.Panel value="cats">
          <Card withBorder padding="lg">
            <Section first>{t('sec.catTable')}</Section>
            <Table>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>{t('table.category')}</Table.Th>
                  <Table.Th ta="right">{t('col.total')}</Table.Th>
                  <Table.Th ta="right">%</Table.Th>
                  <Table.Th ta="right">{t('col.count')}</Table.Th>
                  <Table.Th ta="right">{t('col.avgTicket')}</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>
                {stats.categoryTable.map((c) => (
                  <Table.Tr key={c.name}>
                    <Table.Td><Group gap={6} wrap="nowrap"><Dot color={c.color} /><Text size="sm">{c.name}</Text></Group></Table.Td>
                    <Table.Td ta="right">{money(c.total, cur)}</Table.Td>
                    <Table.Td ta="right"><Text size="sm" c="dimmed">{c.pct}%</Text></Table.Td>
                    <Table.Td ta="right">{c.count}</Table.Td>
                    <Table.Td ta="right">{money(c.avgTicket, cur)}</Table.Td>
                  </Table.Tr>
                ))}
              </Table.Tbody>
            </Table>

            <Section>{t('sec.beforeDuring')}</Section>
            <BarChart
              h={340}
              data={stats.beforeDuringData}
              dataKey="category"
              series={[
                { name: 'antes', label: t('chart.before'), color: PERIOD_COLORS.antes },
                { name: 'durante', label: t('chart.during'), color: PERIOD_COLORS.durante },
              ]}
              valueFormatter={(v) => money(v, cur)}
              yAxisProps={{ width: 88 }}
              withLegend
              legendProps={{ verticalAlign: 'bottom' }}
              styles={leftLegend}
            />
          </Card>
        </Tabs.Panel>

        {/* ============ TRANSAÇÕES ============ */}
        <Tabs.Panel value="tx">
          <Card withBorder padding={0}>
            {selected.size > 0 && (
              <Group justify="space-between" px="md" py="xs">
                <Text size="sm" fw={600}>{selected.size} {t('tx.selectedN')}</Text>
                <Button
                  size="xs"
                  color="red"
                  variant="light"
                  leftSection={<IconTrash size={16} />}
                  onClick={bulkDelete}
                >
                  {t('tx.deleteSelected')}
                </Button>
              </Group>
            )}
            <ScrollArea h={520}>
              <Table stickyHeader highlightOnHover>
                <Table.Thead>
                  <Table.Tr>
                    <Table.Th w={36}>
                      <Checkbox
                        aria-label="select-all"
                        checked={sortedTx.length > 0 && selected.size === sortedTx.length}
                        indeterminate={selected.size > 0 && selected.size < sortedTx.length}
                        onChange={(e) =>
                          setSelected(
                            e.currentTarget.checked ? new Set(sortedTx.map((x) => x.id)) : new Set(),
                          )
                        }
                      />
                    </Table.Th>
                    <Table.Th>{t('table.date')}</Table.Th>
                    <Table.Th>{t('table.description')}</Table.Th>
                    <Table.Th>{t('table.category')}</Table.Th>
                    <Table.Th>{t('table.city')}</Table.Th>
                    <Table.Th>{t('table.period')}</Table.Th>
                    <Table.Th ta="right">{t('table.amount')}</Table.Th>
                    <Table.Th />
                  </Table.Tr>
                </Table.Thead>
                <Table.Tbody>
                  {sortedTx.map((tx) => {
                    const c = cost(tx);
                    const cat = tx.categoryId ? catById.get(tx.categoryId) : undefined;
                    return (
                      <Table.Tr key={tx.id} bg={selected.has(tx.id) ? 'var(--mantine-color-grape-0)' : undefined}>
                        <Table.Td>
                          <Checkbox
                            aria-label="select-row"
                            checked={selected.has(tx.id)}
                            onChange={() => toggleSel(tx.id)}
                          />
                        </Table.Td>
                        <Table.Td>{date(tx.date)}</Table.Td>
                        <Table.Td>
                          {tx.description}
                          {tx.splitCount > 1 && (
                            <Text span size="xs" c="dimmed"> (÷{tx.splitCount})</Text>
                          )}
                        </Table.Td>
                        <Table.Td>
                          {tx.kind === 'IOF_REFUND' ? (
                            <Badge variant="light" color="gray" size="sm">IOF</Badge>
                          ) : cat ? (
                            <Group gap={6} wrap="nowrap"><Dot color={cat.color} /><Text size="sm">{cat.name}</Text></Group>
                          ) : (
                            <Text size="sm" c="dimmed">—</Text>
                          )}
                        </Table.Td>
                        <Table.Td><Text size="sm" c="dimmed">{(tx.date && cities[tx.date]) || '—'}</Text></Table.Td>
                        <Table.Td>
                          <Text size="xs" c="dimmed">
                            {tx.period === 'BEFORE' ? t('period.before') : t('period.during')}
                          </Text>
                        </Table.Td>
                        <Table.Td ta="right">
                          <Text c={c < 0 ? 'teal' : undefined}>{money(c, cur)}</Text>
                          {tx.splitCount > 1 && (
                            <Text size="xs" c="dimmed">{t('table.full')} {money(tx.amount, cur)}</Text>
                          )}
                        </Table.Td>
                        <Table.Td>
                          <Group gap={2} wrap="nowrap" justify="flex-end">
                            <ActionIcon variant="subtle" color="gray" onClick={() => openEdit(tx)} aria-label="edit">
                              <IconPencil size={16} />
                            </ActionIcon>
                            <ActionIcon variant="subtle" color="red" onClick={() => removeTx(tx)} aria-label="delete">
                              <IconTrash size={16} />
                            </ActionIcon>
                          </Group>
                        </Table.Td>
                      </Table.Tr>
                    );
                  })}
                </Table.Tbody>
              </Table>
            </ScrollArea>
          </Card>
        </Tabs.Panel>
      </Tabs>

      <TransactionForm
        opened={formOpened}
        onClose={closeForm}
        trip={trip}
        categories={cats ?? []}
        rules={rules}
        editing={editingTx}
      />
      <TripForm opened={tripFormOpened} onClose={closeTripForm} trip={trip} />
    </Container>
  );
}
