import { useMemo, useState } from 'react';
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
  TextInput,
} from '@mantine/core';
import { DonutChart, BarChart } from '@mantine/charts';
import { IconArrowLeft } from '@tabler/icons-react';
import { db } from '../db/db';
import { computeStats, cost, setCityForDate } from '../db/repo';
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

// Colors for the before/during bars.
const PERIOD_COLORS = { antes: '#4c6ef5', durante: '#cc5de8' };

// Left-align the built-in (interactive) chart legend — Mantine defaults it to
// flex-end. Hovering a legend item still dims the other series.
const leftLegend = { legend: { justifyContent: 'flex-start' as const } };

// Editable city per day. A day = a city, so editing updates every transaction
// on that date. This is the manual input the user fills (a bill image won't have it).
function CityEditor({
  tripId,
  daysByCity,
}: {
  tripId: string;
  daysByCity: { date: string; city: string }[];
}) {
  const { t, date } = useI18n();
  const [edits, setEdits] = useState<Record<string, string>>({});

  return (
    <Stack gap="xs" mt="lg">
      <Text fw={600} size="sm">{t('city.perDay')}</Text>
      <SimpleGrid cols={{ base: 2, sm: 3, md: 4 }} spacing="xs">
        {daysByCity.map(({ date: d, city }) => (
          <Group key={d} gap="xs" wrap="nowrap">
            <Text size="sm" c="dimmed" w={56}>{date(d)}</Text>
            <TextInput
              size="xs"
              placeholder={t('city.placeholder')}
              value={edits[d] ?? city}
              onChange={(e) => setEdits((s) => ({ ...s, [d]: e.currentTarget.value }))}
              onBlur={(e) => setCityForDate(tripId, d, e.currentTarget.value)}
            />
          </Group>
        ))}
      </SimpleGrid>
    </Stack>
  );
}

export function Trip() {
  const { t, money, date } = useI18n();
  const { id = '' } = useParams();
  const trip = useLiveQuery(() => db.trips.get(id), [id]);
  const cats = useLiveQuery(() => db.categories.orderBy('sortOrder').toArray(), []);
  const txs = useLiveQuery(
    () => db.transactions.where('tripId').equals(id).toArray(),
    [id],
  );

  const stats = useMemo(
    () => (txs && cats ? computeStats(txs, cats) : null),
    [txs, cats],
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

  const donut = stats.byCategory.map((c) => ({
    name: c.name,
    value: c.amount,
    color: c.color,
  }));
  const cityDonut = stats.byCity.map((c) => ({
    name: c.city,
    value: c.amount,
    color: c.color,
  }));

  const dayKeys = new Set<string>();
  stats.dayData.forEach((r) =>
    Object.keys(r).forEach((k) => k !== 'date' && dayKeys.add(k)),
  );
  const daySeries = stats.usedCategories
    .filter((c) => dayKeys.has(c.name))
    .map((c) => ({ name: c.name, color: c.color }));

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
          <Title order={2}>{trip.name}</Title>
          {trip.destination && <Text c="dimmed">{trip.destination}</Text>}
          <Text c="dimmed" size="sm">
            {date(trip.startDate)} – {date(trip.endDate)}
          </Text>
        </div>
      </Group>

      {/* KPIs: two rows of three (net/gross/refunds, then before/during/avg) */}
      <SimpleGrid cols={{ base: 1, sm: 3 }} spacing="sm" mb="lg">
        <Kpi label={t('kpi.net')} value={money(stats.net, trip.currency)} />
        <Kpi label={t('kpi.gross')} value={money(stats.gross, trip.currency)} />
        <Kpi label={t('kpi.refunds')} value={money(stats.refunds, trip.currency)} color="teal" />
        <Kpi label={t('kpi.before')} value={money(stats.before, trip.currency)} />
        <Kpi label={t('kpi.during')} value={money(stats.during, trip.currency)} />
        <Kpi label={t('kpi.avgPerDay')} value={money(stats.avgPerDay, trip.currency)} />
      </SimpleGrid>

      <Tabs defaultValue="summary">
        <Tabs.List mb="md">
          <Tabs.Tab value="summary">{t('tab.summary')}</Tabs.Tab>
          <Tabs.Tab value="day">{t('tab.byDay')}</Tabs.Tab>
          <Tabs.Tab value="city">{t('tab.byCity')}</Tabs.Tab>
          <Tabs.Tab value="period">{t('tab.beforeDuring')}</Tabs.Tab>
          <Tabs.Tab value="tx">{t('tab.transactions')}</Tabs.Tab>
        </Tabs.List>

        {/* ---- Summary: donut by category ---- */}
        <Tabs.Panel value="summary">
          <Card withBorder padding="lg">
            <Group align="flex-start" justify="center" gap="xl" wrap="wrap">
              <DonutChart
                data={donut}
                size={240}
                thickness={34}
                withTooltip
                tooltipDataSource="segment"
                chartLabel={money(stats.gross, trip.currency)}
                valueFormatter={(v) => money(v, trip.currency)}
              />
              <Stack gap={6} miw={240}>
                {stats.byCategory.map((c) => (
                  <Group key={c.name} justify="space-between">
                    <Group gap={8}>
                      <Dot color={c.color} />
                      <Text size="sm">{c.name}</Text>
                    </Group>
                    <Text size="sm" fw={600}>{money(c.amount, trip.currency)}</Text>
                  </Group>
                ))}
              </Stack>
            </Group>
          </Card>
        </Tabs.Panel>

        {/* ---- By day: stacked bars by category + city editor ---- */}
        <Tabs.Panel value="day">
          <Card withBorder padding="lg">
            {stats.dayData.length ? (
              <BarChart
                h={360}
                data={stats.dayData}
                dataKey="date"
                type="stacked"
                series={daySeries}
                valueFormatter={(v) => money(v, trip.currency)}
                yAxisProps={{ width: 88 }}
                withLegend
                legendProps={{ verticalAlign: 'bottom' }}
                styles={leftLegend}
              />
            ) : (
              <Text c="dimmed">{t('chart.noDated')}</Text>
            )}
            {stats.daysByCity.length > 0 && (
              <CityEditor tripId={trip.id} daysByCity={stats.daysByCity} />
            )}
          </Card>
        </Tabs.Panel>

        {/* ---- By city: donut ---- */}
        <Tabs.Panel value="city">
          <Card withBorder padding="lg">
            {cityDonut.length ? (
              <Group align="flex-start" justify="center" gap="xl" wrap="wrap">
                <DonutChart
                  data={cityDonut}
                  size={240}
                  thickness={34}
                  withTooltip
                  tooltipDataSource="segment"
                  valueFormatter={(v) => money(v, trip.currency)}
                />
                <Stack gap={6} miw={240}>
                  {stats.byCity.map((c) => (
                    <Group key={c.city} justify="space-between">
                      <Group gap={8}>
                        <Dot color={c.color} />
                        <Text size="sm">{c.city}</Text>
                      </Group>
                      <Text size="sm" fw={600}>{money(c.amount, trip.currency)}</Text>
                    </Group>
                  ))}
                </Stack>
              </Group>
            ) : (
              <Text c="dimmed">{t('chart.noCity')}</Text>
            )}
          </Card>
        </Tabs.Panel>

        {/* ---- Before x During by category ---- */}
        <Tabs.Panel value="period">
          <Card withBorder padding="lg">
            <BarChart
              h={360}
              data={stats.beforeDuringData}
              dataKey="category"
              series={[
                { name: 'antes', label: t('chart.before'), color: PERIOD_COLORS.antes },
                { name: 'durante', label: t('chart.during'), color: PERIOD_COLORS.durante },
              ]}
              valueFormatter={(v) => money(v, trip.currency)}
              yAxisProps={{ width: 88 }}
              withLegend
              legendProps={{ verticalAlign: 'bottom' }}
              styles={leftLegend}
            />
          </Card>
        </Tabs.Panel>

        {/* ---- Transactions ---- */}
        <Tabs.Panel value="tx">
          <Card withBorder padding={0}>
            <ScrollArea h={520}>
              <Table stickyHeader highlightOnHover>
                <Table.Thead>
                  <Table.Tr>
                    <Table.Th>{t('table.date')}</Table.Th>
                    <Table.Th>{t('table.description')}</Table.Th>
                    <Table.Th>{t('table.category')}</Table.Th>
                    <Table.Th>{t('table.city')}</Table.Th>
                    <Table.Th>{t('table.period')}</Table.Th>
                    <Table.Th ta="right">{t('table.amount')}</Table.Th>
                  </Table.Tr>
                </Table.Thead>
                <Table.Tbody>
                  {sortedTx.map((tx) => {
                    const c = cost(tx);
                    const cat = tx.categoryId ? catById.get(tx.categoryId) : undefined;
                    return (
                      <Table.Tr key={tx.id}>
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
                            <Group gap={6} wrap="nowrap">
                              <Dot color={cat.color} />
                              <Text size="sm">{cat.name}</Text>
                            </Group>
                          ) : (
                            <Text size="sm" c="dimmed">—</Text>
                          )}
                        </Table.Td>
                        <Table.Td>
                          <Text size="sm" c="dimmed">{tx.city ?? '—'}</Text>
                        </Table.Td>
                        <Table.Td>
                          <Text size="xs" c="dimmed">
                            {tx.period === 'BEFORE' ? t('period.before') : t('period.during')}
                          </Text>
                        </Table.Td>
                        <Table.Td ta="right">
                          <Text c={c < 0 ? 'teal' : undefined}>{money(c, trip.currency)}</Text>
                          {tx.splitCount > 1 && (
                            <Text size="xs" c="dimmed">
                              {t('table.full')} {money(tx.amount, trip.currency)}
                            </Text>
                          )}
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
    </Container>
  );
}
