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
  Button,
  ActionIcon,
  Checkbox,
  MultiSelect,
  Box,
  SegmentedControl,
  Pill,
  type ComboboxRenderPillInput,
} from '@mantine/core';
import { DatePickerInput } from '@mantine/dates';
import { useDisclosure } from '@mantine/hooks';
import { DonutChart, BarChart } from '@mantine/charts';
import {
  IconArrowLeft,
  IconPlus,
  IconPencil,
  IconTrash,
  IconCategory,
  IconFileImport,
  IconChevronUp,
  IconChevronDown,
  IconSelector,
} from '@tabler/icons-react';
import { db } from '../db/db';
import { computeStats, cityBreakdown, cost } from '../db/stats';
import { deleteTransaction, deleteTransactions } from '../db/repo';
import type { Period, Transaction } from '../db/schema';
import { dateRange, toISO } from '../lib/format';
import { PERIOD_COLORS } from '../lib/constants';
import { toCatById } from '../lib/categories';
import { TransactionForm } from '../components/trip/TransactionForm';
import { TripForm } from '../components/trip/TripForm';
import { ImportTransactions } from '../components/trip/ImportTransactions';
import { CategoryChip, Kpi, Section, SplitTag } from '../components/trip/primitives';
import { CategoryOption } from '../components/trip/CategoryOption';
import { TopTable } from '../components/trip/TopTable';
import { CityEditor } from '../components/trip/CityEditor';
import { useI18n } from '../i18n';

// Left-align the built-in (interactive) chart legend — Mantine defaults it to flex-end.
const leftLegend = { legend: { justifyContent: 'flex-start' as const } };

// MultiSelect pill renderer that caps visible pills at 2 and summarizes the rest as "+N".
function renderCappedPill(selected: string[]) {
  return ({ option, onRemove }: ComboboxRenderPillInput<string>) => {
    const idx = selected.indexOf(String(option.value));
    if (idx > 1) {
      return idx === 2 ? <Pill key="more" size="sm">{`+${selected.length - 2}`}</Pill> : null;
    }
    return (
      <Pill key={String(option.value)} size="sm" withRemoveButton onRemove={onRemove}>
        {option.label}
      </Pill>
    );
  };
}

type TxSortField = 'date' | 'category' | 'city' | 'period' | 'amount';

function SortableTh<F extends string>({
  field,
  label,
  sortField,
  sortDir,
  onSort,
  align = 'left',
}: {
  field: F;
  label: string;
  sortField: F | null;
  sortDir: 'asc' | 'desc';
  onSort: (field: F) => void;
  align?: 'left' | 'right';
}) {
  const active = sortField === field;
  const Icon = active ? (sortDir === 'asc' ? IconChevronUp : IconChevronDown) : IconSelector;
  return (
    <Table.Th
      ta={align}
      onClick={() => onSort(field)}
      style={{ cursor: 'pointer', userSelect: 'none' }}
    >
      <Group gap={4} wrap="nowrap" justify={align === 'right' ? 'flex-end' : 'flex-start'}>
        {label}
        <Icon size={14} style={{ opacity: active ? 1 : 0.45, flexShrink: 0 }} />
      </Group>
    </Table.Th>
  );
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
  const [importOpened, { open: openImport, close: closeImport }] = useDisclosure(false);
  const [editingTx, setEditingTx] = useState<Transaction | null>(null);
  const openAdd = () => { setEditingTx(null); openForm(); };
  const openEdit = (tx: Transaction) => { setEditingTx(tx); openForm(); };
  const removeTx = async (tx: Transaction) => {
    if (window.confirm(t('tx.deleteConfirm'))) await deleteTransaction(tx.id);
  };

  const [cityCatFilter, setCityCatFilter] = useState<string[]>([]);
  const [txCatFilter, setTxCatFilter] = useState<string[]>([]);
  const [txCityFilter, setTxCityFilter] = useState<string[]>([]);
  const [txPeriodFilter, setTxPeriodFilter] = useState<'ALL' | Period>('ALL');
  const [txDateMode, setTxDateMode] = useState<'day' | 'range'>('range');
  const [txDate, setTxDate] = useState<string | null>(null);
  const [txDateRange, setTxDateRange] = useState<[string | null, string | null]>([null, null]);
  const [txSortField, setTxSortField] = useState<TxSortField | null>(null);
  const [txSortDir, setTxSortDir] = useState<'asc' | 'desc'>('asc');
  const txFiltersActive =
    txCatFilter.length > 0 ||
    txCityFilter.length > 0 ||
    txPeriodFilter !== 'ALL' ||
    txDate !== null ||
    txDateRange[0] !== null ||
    txDateRange[1] !== null;
  const clearTxFilters = () => {
    setTxCatFilter([]);
    setTxCityFilter([]);
    setTxPeriodFilter('ALL');
    setTxDate(null);
    setTxDateRange([null, null]);
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
  const catById = useMemo(() => toCatById(cats ?? []), [cats]);

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
  // City summary, restricted to the chosen categories (empty = all).
  const cityBd = cityBreakdown(
    txs ?? [],
    cats ?? [],
    cities,
    cityCatFilter.length ? new Set(cityCatFilter) : undefined,
  );
  const cityDonut = cityBd.byCity.map((c) => ({ name: c.city, value: c.amount, color: c.color }));

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

  const txCityOptions = [...new Set([...(trip.cityList ?? []), ...Object.values(cities)])]
    .filter(Boolean)
    .sort((a, b) => a.localeCompare(b));
  const txCityOf = (tx: Transaction) => (tx.date && cities[tx.date]) || '';
  const txSortCompare: Record<TxSortField, (a: Transaction, b: Transaction) => number> = {
    date: (a, b) => (a.date ?? '').localeCompare(b.date ?? ''),
    category: (a, b) =>
      (catById.get(a.categoryId ?? '')?.name ?? '').localeCompare(catById.get(b.categoryId ?? '')?.name ?? ''),
    city: (a, b) => txCityOf(a).localeCompare(txCityOf(b)),
    period: (a, b) => (a.period === b.period ? 0 : a.period === 'BEFORE' ? -1 : 1),
    amount: (a, b) => cost(a) - cost(b),
  };
  // 3-state cycle per column: unsorted -> asc -> desc -> unsorted (back to default order).
  const toggleTxSort = (field: TxSortField) => {
    if (txSortField !== field) {
      setTxSortField(field);
      setTxSortDir('asc');
    } else if (txSortDir === 'asc') {
      setTxSortDir('desc');
    } else {
      setTxSortField(null);
    }
  };
  const filteredTx = (txs ?? [])
    .filter((tx) => {
      if (txPeriodFilter !== 'ALL' && tx.period !== txPeriodFilter) return false;
      if (txCatFilter.length && !(tx.categoryId && txCatFilter.includes(tx.categoryId))) return false;
      const txCity = tx.date ? cities[tx.date] : undefined;
      if (txCityFilter.length && !(txCity && txCityFilter.includes(txCity))) return false;
      if (txDateMode === 'day') {
        if (txDate && tx.date !== txDate) return false;
      } else {
        if (txDateRange[0] && (!tx.date || tx.date < txDateRange[0])) return false;
        if (txDateRange[1] && (!tx.date || tx.date > txDateRange[1])) return false;
      }
      return true;
    })
    .sort((a, b) => {
      if (txSortField) {
        const dir = txSortDir === 'asc' ? 1 : -1;
        const primary = txSortCompare[txSortField](a, b) * dir;
        if (primary !== 0) return primary;
      }
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
          <Button variant="default" leftSection={<IconFileImport size={18} />} onClick={openImport}>
            {t('import.button')}
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

        {/* Summary */}
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
                    <CategoryChip color={c.color} name={c.name} icon={c.icon} gap={8} />
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

        {/* Time */}
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
                barProps={{ radius: [4, 4, 0, 0] }}
              />
            ) : (
              <Text c="dimmed">{t('chart.noDated')}</Text>
            )}

            <Section>{t('sec.weekday')}</Section>
            <BarChart
              h={200}
              data={weekdayData}
              dataKey="day"
              series={[{ name: 'amount', color: 'orange.5', label: t('table.amount') }]}
              valueFormatter={(v) => money(v, cur)}
              barProps={{ radius: [6, 6, 0, 0] }}
              barChartProps={{ barCategoryGap: '12%' }}
              gridAxis="none"
              withYAxis={false}
              withBarValueLabel
            />
          </Card>
        </Tabs.Panel>

        {/* Cities */}
        <Tabs.Panel value="cities">
          <Card withBorder padding="lg">
            <MultiSelect
              label={t('city.filter')}
              placeholder={cityCatFilter.length ? undefined : t('city.filterPlaceholder')}
              data={(cats ?? []).map((c) => ({ value: c.id, label: c.name }))}
              value={cityCatFilter}
              onChange={setCityCatFilter}
              clearable
              mb="md"
              renderOption={({ option }) => (
                <CategoryOption category={catById.get(option.value)} label={option.label} />
              )}
            />
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
                    {cityBd.byCity.map((c) => (
                      <Group key={c.city} justify="space-between">
                        <CategoryChip color={c.color} name={c.city} gap={8} />
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
                    {cityBd.cityTable.map((c) => (
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

        {/* Categories */}
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
                    <Table.Td><CategoryChip color={c.color} name={c.name} icon={c.icon} /></Table.Td>
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
                { name: 'before', label: t('chart.before'), color: PERIOD_COLORS.before },
                { name: 'during', label: t('chart.during'), color: PERIOD_COLORS.during },
              ]}
              valueFormatter={(v) => money(v, cur)}
              yAxisProps={{ width: 88 }}
              barProps={{ radius: 4 }}
              withLegend
              legendProps={{ verticalAlign: 'bottom' }}
              styles={leftLegend}
            />
          </Card>
        </Tabs.Panel>

        {/* Transactions */}
        <Tabs.Panel value="tx">
          <Card withBorder padding={0}>
            <Box px="md" pt="md">
              <SimpleGrid cols={{ base: 1, sm: 2, md: 4 }} spacing="sm" mb="xs">
                <div>
                  <Text size="sm" fw={500} mb={4}>{t('tx.filterDate')}</Text>
                  <Group gap={6} wrap="nowrap" align="flex-start">
                    <Box style={{ flex: 1, minWidth: 0 }}>
                      {txDateMode === 'day' ? (
                        <DatePickerInput
                          valueFormat="DD/MM/YYYY"
                          placeholder={t('tx.filterDatePlaceholder')}
                          value={txDate}
                          onChange={(v) => setTxDate(toISO(v))}
                          clearable
                        />
                      ) : (
                        <DatePickerInput
                          type="range"
                          valueFormat="DD/MM/YY"
                          placeholder={t('tx.filterDatePlaceholder')}
                          value={txDateRange}
                          onChange={(v) => setTxDateRange([toISO(v[0]), toISO(v[1])])}
                          clearable
                        />
                      )}
                    </Box>
                    <SegmentedControl
                      size="xs"
                      value={txDateMode}
                      onChange={(v) => setTxDateMode(v as 'day' | 'range')}
                      data={[
                        { label: t('tx.dateModeDay'), value: 'day' },
                        { label: t('tx.dateModeRange'), value: 'range' },
                      ]}
                    />
                  </Group>
                </div>
                <MultiSelect
                  label={t('tx.filterCategory')}
                  placeholder={txCatFilter.length ? undefined : t('tx.filterCategoryPlaceholder')}
                  data={(cats ?? []).map((c) => ({ value: c.id, label: c.name }))}
                  value={txCatFilter}
                  onChange={setTxCatFilter}
                  clearable
                  renderPill={renderCappedPill(txCatFilter)}
                  renderOption={({ option }) => (
                    <CategoryOption category={catById.get(option.value)} label={option.label} />
                  )}
                />
                <MultiSelect
                  label={t('tx.filterCity')}
                  placeholder={txCityFilter.length ? undefined : t('tx.filterCityPlaceholder')}
                  data={txCityOptions}
                  value={txCityFilter}
                  onChange={setTxCityFilter}
                  clearable
                  renderPill={renderCappedPill(txCityFilter)}
                />
                <div>
                  <Text size="sm" fw={500} mb={4}>{t('tx.filterPeriod')}</Text>
                  <SegmentedControl
                    fullWidth
                    value={txPeriodFilter}
                    onChange={(v) => setTxPeriodFilter(v as 'ALL' | Period)}
                    data={[
                      { label: t('tx.periodAll'), value: 'ALL' },
                      { label: t('period.before'), value: 'BEFORE' },
                      { label: t('period.during'), value: 'DURING' },
                    ]}
                  />
                </div>
              </SimpleGrid>
              <Group justify="space-between" mb="md">
                <Text size="sm" c="dimmed">
                  {filteredTx.length} {t('tx.filterResultsN')}
                </Text>
                {txFiltersActive && (
                  <Button size="xs" variant="subtle" onClick={clearTxFilters}>
                    {t('tx.clearFilters')}
                  </Button>
                )}
              </Group>
            </Box>
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
                        checked={filteredTx.length > 0 && selected.size === filteredTx.length}
                        indeterminate={selected.size > 0 && selected.size < filteredTx.length}
                        onChange={(e) =>
                          setSelected(
                            e.currentTarget.checked ? new Set(filteredTx.map((x) => x.id)) : new Set(),
                          )
                        }
                      />
                    </Table.Th>
                    <SortableTh field="date" label={t('table.date')} sortField={txSortField} sortDir={txSortDir} onSort={toggleTxSort} />
                    <Table.Th>{t('table.description')}</Table.Th>
                    <SortableTh field="category" label={t('table.category')} sortField={txSortField} sortDir={txSortDir} onSort={toggleTxSort} />
                    <SortableTh field="city" label={t('table.city')} sortField={txSortField} sortDir={txSortDir} onSort={toggleTxSort} />
                    <SortableTh field="period" label={t('table.period')} sortField={txSortField} sortDir={txSortDir} onSort={toggleTxSort} />
                    <SortableTh field="amount" label={t('table.amount')} sortField={txSortField} sortDir={txSortDir} onSort={toggleTxSort} align="right" />
                    <Table.Th />
                  </Table.Tr>
                </Table.Thead>
                <Table.Tbody>
                  {filteredTx.map((tx) => {
                    const c = cost(tx);
                    const cat = tx.categoryId ? catById.get(tx.categoryId) : undefined;
                    return (
                      <Table.Tr key={tx.id} bg={selected.has(tx.id) ? 'var(--mantine-color-orange-light)' : undefined}>
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
                          <SplitTag count={tx.splitCount} />
                        </Table.Td>
                        <Table.Td>
                          {tx.kind === 'IOF_REFUND' ? (
                            <Badge variant="light" color="gray" size="sm">IOF</Badge>
                          ) : cat ? (
                            <CategoryChip color={cat.color} name={cat.name} icon={cat.icon} />
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
      <ImportTransactions
        opened={importOpened}
        onClose={closeImport}
        trip={trip}
        categories={cats ?? []}
        rules={rules}
      />
    </Container>
  );
}
