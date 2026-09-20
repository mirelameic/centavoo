import { useMemo, useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  Container,
  Title,
  Text,
  Group,
  SimpleGrid,
  Card,
  Tabs,
  Anchor,
  Center,
  Loader,
  ScrollArea,
  Button,
  ActionIcon,
  Select,
  MultiSelect,
  Box,
  SegmentedControl,
  Pill,
  UnstyledButton,
  TextInput,
  type ComboboxRenderPillInput,
} from '@mantine/core';
import { DatePickerInput } from '@mantine/dates';
import { useDisclosure } from '@mantine/hooks';
import { DonutChart, BarChart, AreaChart } from '@mantine/charts';
import {
  IconArrowLeft,
  IconPlus,
  IconPencil,
  IconTrash,
  IconCategory,
  IconFileImport,
  IconSortAscending,
  IconSortDescending,
  IconChartPie,
  IconChartBar,
  IconCalendar,
  IconMapPin,
  IconReceipt2,
  IconArrowUp,
  IconSearch,
} from '@tabler/icons-react';
import { db } from '../db/db';
import { computeStats, cityBreakdown, cost } from '../db/stats';
import { deleteTransaction, deleteTransactions } from '../db/repo';
import type { Period, Transaction } from '../db/schema';
import { dateRange, toISO } from '../lib/format';
import { PERIOD_COLORS, ROW_BREAK } from '../lib/constants';
import { confirmDelete } from '../lib/confirm';
import { toCatById } from '../lib/categories';
import { TransactionForm } from '../components/trip/TransactionForm';
import { TripForm } from '../components/trip/TripForm';
import { ImportTransactions } from '../components/trip/ImportTransactions';
import { CategoryChip, Kpi, LegendList, Section, SummaryRow, ToggleLegend } from '../components/trip/primitives';
import { CategoryOption } from '../components/trip/CategoryOption';
import { TopTable } from '../components/trip/TopTable';
import { TxRow } from '../components/trip/TxRow';
import { CityEditor } from '../components/trip/CityEditor';
import { useI18n } from '../i18n';

const TAB_ITEMS = [
  { value: 'summary', label: 'tab.summary', icon: IconChartPie },
  { value: 'top', label: 'tab.top', icon: IconChartBar },
  { value: 'time', label: 'tab.time', icon: IconCalendar },
  { value: 'cities', label: 'tab.cities', icon: IconMapPin },
  { value: 'cats', label: 'tab.cats', icon: IconCategory },
  { value: 'tx', label: 'tab.transactions', icon: IconReceipt2 },
] as const;

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

  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const activeTab = searchParams.get('tab');
  const openTab = (value: string) => {
    if (activeTab === value) {
      navigate(-1);
    } else if (activeTab) {
      setSearchParams({ tab: value }, { replace: true });
    } else {
      setSearchParams({ tab: value });
    }
  };
  const closeTab = () => navigate(-1);
  const [formOpened, { open: openForm, close: closeForm }] = useDisclosure(false);
  const [tripFormOpened, { open: openTripForm, close: closeTripForm }] = useDisclosure(false);
  const [importOpened, { open: openImport, close: closeImport }] = useDisclosure(false);
  const [editingTx, setEditingTx] = useState<Transaction | null>(null);
  const openAdd = () => { setEditingTx(null); openForm(); };
  const openEdit = (tx: Transaction) => { setEditingTx(tx); openForm(); };
  const removeTx = (tx: Transaction) => {
    confirmDelete(t('tx.deleteConfirm'), () => deleteTransaction(tx.id));
  };

  const [hiddenDaySeries, setHiddenDaySeries] = useState<Set<string>>(new Set());
  const toggleDaySeries = (name: string) =>
    setHiddenDaySeries((s) => {
      const n = new Set(s);
      if (n.has(name)) n.delete(name);
      else n.add(name);
      return n;
    });
  const [hiddenBdSeries, setHiddenBdSeries] = useState<Set<string>>(new Set());
  const toggleBdSeries = (name: string) =>
    setHiddenBdSeries((s) => {
      const n = new Set(s);
      if (n.has(name)) n.delete(name);
      else n.add(name);
      return n;
    });

  const [cityCatFilter, setCityCatFilter] = useState<string[]>([]);
  const [txSearch, setTxSearch] = useState('');
  const [txCatFilter, setTxCatFilter] = useState<string[]>([]);
  const [txCityFilter, setTxCityFilter] = useState<string[]>([]);
  const [txPeriodFilter, setTxPeriodFilter] = useState<'ALL' | Period>('ALL');
  const [txDateMode, setTxDateMode] = useState<'day' | 'range'>('range');
  const [txDate, setTxDate] = useState<string | null>(null);
  const [txDateRange, setTxDateRange] = useState<[string | null, string | null]>([null, null]);
  const [txSortField, setTxSortField] = useState<TxSortField | null>(null);
  const [txSortDir, setTxSortDir] = useState<'asc' | 'desc'>('asc');
  const txFiltersActive =
    txSearch.trim() !== '' ||
    txCatFilter.length > 0 ||
    txCityFilter.length > 0 ||
    txPeriodFilter !== 'ALL' ||
    txDate !== null ||
    txDateRange[0] !== null ||
    txDateRange[1] !== null;
  const clearTxFilters = () => {
    setTxSearch('');
    setTxCatFilter([]);
    setTxCityFilter([]);
    setTxPeriodFilter('ALL');
    setTxDate(null);
    setTxDateRange([null, null]);
  };
  const [selectMode, setSelectMode] = useState(false);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const toggleSel = (txId: string) =>
    setSelected((s) => {
      const n = new Set(s);
      if (n.has(txId)) n.delete(txId);
      else n.add(txId);
      return n;
    });
  const toggleSelectMode = () => {
    setSelectMode((m) => !m);
    setSelected(new Set());
  };
  const bulkDelete = () => {
    if (!selected.size) return;
    confirmDelete(t('tx.deleteSelectedConfirm'), async () => {
      await deleteTransactions([...selected]);
      setSelected(new Set());
    });
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
  const txDates = (txs ?? []).filter((tx) => tx.date).map((tx) => tx.date as string);
  const rangeDays = trip.startDate && trip.endDate ? dateRange(trip.startDate, trip.endDate) : [];
  const tripDays = [...new Set([...rangeDays, ...txDates])].sort();
  const donut = stats.byCategory.map((c) => ({ name: c.name, value: c.amount, color: c.color }));
  const cityBd = cityBreakdown(
    txs ?? [],
    cats ?? [],
    cities,
    cityCatFilter.length ? new Set(cityCatFilter) : undefined,
  );
  const cityDonut = cityBd.byCity.map((c) => ({ name: c.city, value: c.amount, color: c.color }));
  const cityTotal = cityBd.byCity.reduce((sum, c) => sum + c.amount, 0);

  const dayKeys = new Set<string>();
  stats.dayData.forEach((r) => Object.keys(r).forEach((k) => k !== 'date' && dayKeys.add(k)));
  const daySeries = stats.usedCategories
    .filter((c) => dayKeys.has(c.name))
    .map((c) => ({ name: c.name, color: c.color }));

  const bdSeries = [
    { name: 'before', label: t('chart.before'), color: PERIOD_COLORS.before },
    { name: 'during', label: t('chart.during'), color: PERIOD_COLORS.during },
  ];

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
  const txSearchQuery = txSearch.trim().toLowerCase();
  const filteredTx = (txs ?? [])
    .filter((tx) => {
      if (txSearchQuery && !tx.description.toLowerCase().includes(txSearchQuery)) return false;
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
  const filteredTxTotal = filteredTx.reduce((sum, tx) => sum + cost(tx), 0);

  return (
    <Container size="lg" px={0} className="trip-page">
      {activeTab ? (
        <UnstyledButton
          onClick={closeTab}
          aria-label="back-to-trip"
          mb="sm"
          style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}
        >
          <IconArrowLeft size={20} />
        </UnstyledButton>
      ) : (
        <Anchor component={Link} to="/" mb="sm" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
          <IconArrowLeft size={16} /> {t('nav.trips')}
        </Anchor>
      )}
      <Group
        justify="space-between"
        align="flex-end"
        mb="md"
        className={activeTab ? 'hide-when-tab-open' : undefined}
      >
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

      <SimpleGrid
        cols={{ base: 1, sm: 3 }}
        spacing="sm"
        mb="lg"
        className={activeTab ? 'hide-when-tab-open' : undefined}
      >
        <Kpi label={t('kpi.net')} value={money(stats.net, cur)} />
        <Kpi label={t('kpi.gross')} value={money(stats.gross, cur)} />
        <Kpi label={t('kpi.refunds')} value={money(stats.refunds, cur)} color="teal" />
        <Kpi label={t('kpi.before')} value={money(stats.before, cur)} />
        <Kpi label={t('kpi.during')} value={money(stats.during, cur)} />
        <Kpi label={t('kpi.avgPerDay')} value={money(stats.avgPerDay, cur)} />
      </SimpleGrid>

      <Tabs
        value={activeTab}
        onChange={(v) => v && openTab(v)}
        variant="pills"
        radius="xl"
      >
        <Tabs.List className="tabs-list-desktop" mb="md" style={{ flexWrap: 'wrap', gap: 8, justifyContent: 'center' }}>
          {TAB_ITEMS.map(({ value, label, icon: Icon }) => (
            <Tabs.Tab key={value} value={value} leftSection={<Icon size={36} />}>
              {t(label)}
            </Tabs.Tab>
          ))}
        </Tabs.List>

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
              <LegendList
                currency={cur}
                locale={locale}
                rows={stats.byCategory.map((c) => ({
                  key: c.name,
                  color: c.color,
                  label: c.name,
                  icon: c.icon,
                  amount: c.amount,
                }))}
              />
            </Group>

            {hasSplit && (
              <>
                <Section>{t('sec.split')}</Section>
                <SimpleGrid cols={{ base: 1, xs: 3 }} spacing="sm">
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
          </Card>
        </Tabs.Panel>

        <Tabs.Panel value="top">
          <Card withBorder padding="lg">
            {topBefore.length > 0 && (
              <>
                <Section first>{t('sec.topBefore')}</Section>
                <TopTable items={topBefore} catById={catById} cities={cities} cur={cur} />
              </>
            )}
            {topDuring.length > 0 && (
              <>
                <Section first={topBefore.length === 0}>{t('sec.topDuring')}</Section>
                <TopTable items={topDuring} catById={catById} cities={cities} cur={cur} />
              </>
            )}
            {topBefore.length === 0 && topDuring.length === 0 && (
              <Text c="dimmed">{t('chart.noTop')}</Text>
            )}
          </Card>
        </Tabs.Panel>

        <Tabs.Panel value="time">
          <Card withBorder padding="lg">
            <Section first>{t('sec.byDay')}</Section>
            {stats.dayData.length ? (
              <BarChart
                h={340}
                data={stats.dayData}
                dataKey="date"
                type="stacked"
                series={daySeries.filter((s) => !hiddenDaySeries.has(s.name))}
                valueFormatter={(v) => money(v, cur)}
                yAxisProps={{ width: 88 }}
                withLegend
                legendProps={{
                  verticalAlign: 'bottom',
                  content: () => (
                    <ToggleLegend series={daySeries} hidden={hiddenDaySeries} onToggle={toggleDaySeries} />
                  ),
                }}
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
              valueLabelProps={{
                formatter: (v) => (typeof v === 'number' ? Math.round(v).toLocaleString(locale) : v),
              }}
            />

            <Section>{t('sec.cumulative')}</Section>
            {stats.cumulativeByDay.length ? (
              <AreaChart
                h={220}
                data={stats.cumulativeByDay}
                dataKey="date"
                series={[{ name: 'total', color: 'orange.5', label: t('table.amount') }]}
                valueFormatter={(v) => money(v, cur)}
                curveType="monotone"
                withGradient
              />
            ) : (
              <Text c="dimmed">{t('chart.noDated')}</Text>
            )}
          </Card>
        </Tabs.Panel>

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
                    chartLabel={money(cityTotal, cur)}
                    valueFormatter={(v) => money(v, cur)}
                  />
                  <LegendList
                    currency={cur}
                    locale={locale}
                    rows={cityBd.byCity.map((c) => ({ key: c.city, color: c.color, label: c.city, amount: c.amount }))}
                  />
                </Group>

                <Section>{t('sec.cityTable')}</Section>
                <div>
                  {cityBd.cityTable.map((c) => (
                    <SummaryRow
                      key={c.city}
                      leading={c.city}
                      meta={[
                        `${c.days} ${t('city.daysN')}`,
                        `${t('col.avgDay')}: ${money(c.avgPerDay, cur)}`,
                        ROW_BREAK,
                        <span key="top" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                          <IconArrowUp size={12} />
                          {c.topCategory}
                        </span>,
                      ]}
                      amount={money(c.total, cur)}
                    />
                  ))}
                </div>
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

        <Tabs.Panel value="cats">
          <Card withBorder padding="lg">
            <Section first>{t('sec.catTable')}</Section>
            <div>
              {stats.categoryTable.map((c) => (
                <SummaryRow
                  key={c.name}
                  leading={<CategoryChip color={c.color} name={c.name} icon={c.icon} />}
                  meta={[
                    `${c.pct}%`,
                    `${c.count} ${c.count === 1 ? t('col.entry') : t('col.entries')}`,
                    ROW_BREAK,
                    `${t('col.avgTicket')}: ${money(c.avgTicket, cur)}`,
                  ]}
                  amount={money(c.total, cur)}
                />
              ))}
            </div>

            <Section>{t('sec.beforeDuring')}</Section>
            <BarChart
              h={340}
              data={stats.beforeDuringData}
              dataKey="category"
              series={bdSeries.filter((s) => !hiddenBdSeries.has(s.name))}
              valueFormatter={(v) => money(v, cur)}
              yAxisProps={{ width: 88 }}
              barProps={{ radius: 4 }}
              withLegend
              legendProps={{
                verticalAlign: 'bottom',
                content: () => (
                  <ToggleLegend series={bdSeries} hidden={hiddenBdSeries} onToggle={toggleBdSeries} />
                ),
              }}
            />
          </Card>
        </Tabs.Panel>

        <Tabs.Panel value="tx">
          <Card withBorder padding={0}>
            <Box px="md" pt="md">
              <TextInput
                leftSection={<IconSearch size={16} />}
                placeholder={t('tx.searchPlaceholder')}
                value={txSearch}
                onChange={(e) => setTxSearch(e.currentTarget.value)}
                mb="sm"
              />
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
              <Group justify="space-between" mb="xs" wrap="wrap" gap="xs">
                <Text size="sm" c="dimmed">
                  {filteredTx.length} {t('tx.filterResultsN')} · {money(filteredTxTotal, cur)}
                </Text>
                <Group gap="xs" wrap="nowrap">
                  {txFiltersActive && (
                    <Button size="xs" variant="subtle" onClick={clearTxFilters}>
                      {t('tx.clearFilters')}
                    </Button>
                  )}
                  <Button size="xs" variant={selectMode ? 'light' : 'subtle'} onClick={toggleSelectMode}>
                    {selectMode ? t('tx.cancelSelect') : t('tx.select')}
                  </Button>
                </Group>
              </Group>
              <Group gap={6} mb="md">
                <Text size="sm" c="dimmed">{t('tx.sortBy')}</Text>
                <Select
                  size="xs"
                  w={150}
                  value={txSortField ?? ''}
                  onChange={(v) => {
                    if (!v) {
                      setTxSortField(null);
                    } else if (v !== txSortField) {
                      setTxSortField(v as TxSortField);
                      setTxSortDir('asc');
                    }
                  }}
                  data={[
                    { value: '', label: t('tx.sortDefault') },
                    { value: 'date', label: t('table.date') },
                    { value: 'category', label: t('table.category') },
                    { value: 'city', label: t('table.city') },
                    { value: 'period', label: t('table.period') },
                    { value: 'amount', label: t('table.amount') },
                  ]}
                />
                <ActionIcon
                  variant="default"
                  disabled={!txSortField}
                  onClick={() => setTxSortDir((d) => (d === 'asc' ? 'desc' : 'asc'))}
                  aria-label="toggle-sort-direction"
                >
                  {txSortDir === 'asc' ? <IconSortAscending size={16} /> : <IconSortDescending size={16} />}
                </ActionIcon>
              </Group>
            </Box>
            {selectMode && (
              <Group justify="space-between" px="md" py="xs" style={{ borderBottom: '1px solid var(--mantine-color-default-border)' }}>
                <Group gap="xs">
                  <Text size="sm" fw={600}>{selected.size} {t('tx.selectedN')}</Text>
                  <Button
                    size="xs"
                    variant="subtle"
                    onClick={() =>
                      setSelected(
                        selected.size === filteredTx.length ? new Set() : new Set(filteredTx.map((x) => x.id)),
                      )
                    }
                  >
                    {selected.size === filteredTx.length ? t('tx.clearSelection') : t('tx.selectAll')}
                  </Button>
                </Group>
                <Button
                  size="xs"
                  color="red"
                  variant="light"
                  leftSection={<IconTrash size={16} />}
                  disabled={!selected.size}
                  onClick={bulkDelete}
                >
                  {t('tx.deleteSelected')}
                </Button>
              </Group>
            )}
            <ScrollArea h={520}>
              <Box px="md">
                {filteredTx.map((tx) => (
                  <TxRow
                    key={tx.id}
                    tx={tx}
                    cat={tx.categoryId ? catById.get(tx.categoryId) : undefined}
                    cities={cities}
                    cur={cur}
                    showPeriod
                    selecting={selectMode}
                    selected={selected.has(tx.id)}
                    onToggleSelect={() => toggleSel(tx.id)}
                    onEdit={() => openEdit(tx)}
                    onDelete={() => removeTx(tx)}
                  />
                ))}
              </Box>
            </ScrollArea>
          </Card>
        </Tabs.Panel>
      </Tabs>

      <nav className="glass-panel mobile-bottom-nav">
        {TAB_ITEMS.map(({ value, label, icon: Icon }) => (
          <UnstyledButton
            key={value}
            className="mobile-bottom-nav-item"
            data-active={activeTab === value || undefined}
            onClick={() => openTab(value)}
          >
            <Icon size={20} />
            <Text className="mobile-bottom-nav-label">{t(label)}</Text>
          </UnstyledButton>
        ))}
      </nav>

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
