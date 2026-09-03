import { useMemo, useState } from 'react';
import {
  Modal,
  Stack,
  Group,
  Button,
  Textarea,
  FileButton,
  Select,
  Checkbox,
  SegmentedControl,
  Table,
  ScrollArea,
  Text,
  Alert,
  Box,
} from '@mantine/core';
import { notifications } from '@mantine/notifications';
import { IconUpload, IconAlertCircle } from '@tabler/icons-react';
import type { Category, CategoryRule, Kind, Period, Trip } from '../../db/schema';
import { bulkAddTransactions } from '../../db/repo';
import { suggestCategory } from '../../lib/categorize';
import { toCatById } from '../../lib/categories';
import {
  splitRows,
  parseAmount,
  parseDate,
  guessRoles,
  looksLikeHeaderRow,
  type ColumnRole,
  type DelimiterOption,
} from '../../lib/parseTable';
import { useI18n } from '../../i18n';
import { CategoryOption } from './CategoryOption';

interface Props {
  opened: boolean;
  onClose: () => void;
  trip: Trip;
  categories: Category[];
  rules: CategoryRule[];
}

export function ImportTransactions({ opened, onClose, ...rest }: Props) {
  const { t } = useI18n();
  return (
    <Modal opened={opened} onClose={onClose} title={t('import.title')} size="xl" centered>
      {opened && <Flow onClose={onClose} {...rest} />}
    </Modal>
  );
}

interface ParsedRow {
  date: string | null;
  description: string;
  amount: number | null;
  kind: Kind;
  categoryId: string | null;
  error: string | null;
}

function Flow({ onClose, trip, categories, rules }: Omit<Props, 'opened'>) {
  const { t } = useI18n();

  // Step 1: get raw text (pasted or from a file).
  const [rawText, setRawText] = useState('');
  const [delimiter, setDelimiter] = useState<DelimiterOption>('auto');
  const [noRowsError, setNoRowsError] = useState(false);

  // Step 2: parsed grid + how to interpret it.
  const [rows, setRows] = useState<string[][] | null>(null);
  const [roles, setRoles] = useState<ColumnRole[]>([]);
  const [hasHeader, setHasHeader] = useState(false);
  const [period, setPeriod] = useState<Period>('DURING');
  const [invertSign, setInvertSign] = useState(false);
  const [excluded, setExcluded] = useState<Set<number>>(new Set());
  const [categoryOverrides, setCategoryOverrides] = useState<Map<number, string | null>>(new Map());
  const [importing, setImporting] = useState(false);

  function handleFile(file: File | null) {
    if (!file) return;
    file.text().then(setRawText).catch(() => setNoRowsError(true));
  }

  function handleContinue() {
    const parsed = splitRows(rawText, delimiter);
    if (!parsed.length) {
      setNoRowsError(true);
      return;
    }
    setNoRowsError(false);
    const guessedRoles = guessRoles(parsed);
    setRows(parsed);
    setRoles(guessedRoles);
    setHasHeader(looksLikeHeaderRow(parsed, guessedRoles));
    setExcluded(new Set());
    setCategoryOverrides(new Map());
  }

  function handleBack() {
    setRows(null);
  }

  const dataRows = useMemo(
    () => (rows ? (hasHeader ? rows.slice(1) : rows) : []),
    [rows, hasHeader],
  );

  const parsedRows = useMemo<ParsedRow[]>(() => {
    const dateCol = roles.indexOf('date');
    const descCol = roles.indexOf('description');
    const amountCol = roles.indexOf('amount');

    return dataRows.map((cols, i) => {
      const description = descCol >= 0 ? cols[descCol].trim() : '';
      const dateRaw = dateCol >= 0 ? cols[dateCol].trim() : '';
      const date = dateRaw ? parseDate(dateRaw) : null;
      let amount = amountCol >= 0 ? parseAmount(cols[amountCol]) : null;
      if (amount != null && invertSign) amount = -amount;

      let error: string | null = null;
      if (amountCol < 0 || amount == null) error = t('import.errAmount');
      else if (!description) error = t('import.errDescription');
      else if (dateRaw && date == null) error = t('import.errDate');

      const suggested = !error ? suggestCategory(description, rules) : null;
      const categoryId =
        categoryOverrides.get(i) ??
        (suggested && categories.some((c) => c.id === suggested) ? suggested : null);

      return {
        date,
        description,
        amount,
        kind: (amount ?? 0) < 0 ? 'REFUND' : 'EXPENSE',
        categoryId,
        error,
      };
    });
  }, [dataRows, roles, invertSign, categoryOverrides, categories, rules, t]);

  const validCount = parsedRows.filter((r, i) => !r.error && !excluded.has(i)).length;
  const errorCount = parsedRows.filter((r) => r.error).length;

  function setRole(colIndex: number, role: ColumnRole) {
    setRoles((prev) => prev.map((r, i) => (i === colIndex ? role : r)));
  }

  function toggleExcluded(rowIndex: number) {
    setExcluded((prev) => {
      const next = new Set(prev);
      if (next.has(rowIndex)) next.delete(rowIndex); else next.add(rowIndex);
      return next;
    });
  }

  async function handleImport() {
    const toInsert = parsedRows
      .map((r, i) => ({ r, i }))
      .filter(({ r, i }) => !r.error && !excluded.has(i))
      .map(({ r }) => ({
        tripId: trip.id,
        period,
        date: r.date,
        description: r.description,
        amount: r.amount as number,
        categoryId: r.categoryId,
        kind: r.kind,
        isIof: false,
        splitCount: 1,
        city: null,
      }));
    if (!toInsert.length) return;

    setImporting(true);
    try {
      await bulkAddTransactions(toInsert);
      notifications.show({ message: `${toInsert.length} ${t('import.successSuffix')}`, color: 'teal' });
      onClose();
    } catch {
      notifications.show({ message: t('import.error'), color: 'red' });
    } finally {
      setImporting(false);
    }
  }

  const catById = toCatById(categories);
  const catData = categories.map((c) => ({ value: c.id, label: c.name }));
  const catRenderOption = ({ option }: { option: { value: string; label: string } }) => (
    <CategoryOption category={catById.get(option.value)} label={option.label} withSwatch />
  );
  const roleOptions = [
    { value: 'ignore', label: t('import.colIgnore') },
    { value: 'date', label: t('import.colDate') },
    { value: 'description', label: t('import.colDescription') },
    { value: 'amount', label: t('import.colAmount') },
  ];

  // Step 1 — get the raw text.
  if (!rows) {
    return (
      <Stack>
        <Text size="sm" c="dimmed">{t('import.intro')}</Text>
        <Textarea
          label={t('import.pasteLabel')}
          placeholder={t('import.pastePlaceholder')}
          autosize
          minRows={6}
          maxRows={12}
          value={rawText}
          onChange={(e) => setRawText(e.currentTarget.value)}
        />
        <Group justify="space-between" align="flex-end">
          <FileButton onChange={handleFile} accept=".csv,.txt,text/csv,text/plain">
            {(props) => (
              <Button variant="default" leftSection={<IconUpload size={16} />} {...props}>
                {t('import.uploadButton')}
              </Button>
            )}
          </FileButton>
          <Select
            label={t('import.delimiter')}
            w={220}
            allowDeselect={false}
            value={delimiter}
            onChange={(v) => setDelimiter((v as DelimiterOption) ?? 'auto')}
            data={[
              { value: 'auto', label: t('import.delimiterAuto') },
              { value: ',', label: t('import.delimiterComma') },
              { value: ';', label: t('import.delimiterSemicolon') },
              { value: '\t', label: t('import.delimiterTab') },
            ]}
          />
        </Group>
        {noRowsError && (
          <Alert color="red" icon={<IconAlertCircle size={16} />}>{t('import.noRows')}</Alert>
        )}
        <Group justify="flex-end">
          <Button variant="default" onClick={onClose}>{t('common.cancel')}</Button>
          <Button onClick={handleContinue} disabled={!rawText.trim()}>{t('import.continue')}</Button>
        </Group>
      </Stack>
    );
  }

  // Step 2 — map columns, review, confirm.
  return (
    <Stack>
      <Group grow align="flex-end">
        <div>
          <Text size="sm" fw={600} mb={4}>{t('import.period')}</Text>
          <SegmentedControl
            fullWidth
            value={period}
            onChange={(v) => setPeriod(v as Period)}
            data={[
              { label: t('period.before'), value: 'BEFORE' },
              { label: t('period.during'), value: 'DURING' },
            ]}
          />
        </div>
        <Stack gap={4}>
          <Checkbox
            label={t('import.hasHeader')}
            checked={hasHeader}
            onChange={(e) => setHasHeader(e.currentTarget.checked)}
          />
          <Checkbox
            label={t('import.invertSign')}
            checked={invertSign}
            onChange={(e) => setInvertSign(e.currentTarget.checked)}
          />
        </Stack>
      </Group>

      <Box>
        <Text size="sm" fw={600} mb={4}>{t('import.mapHint')}</Text>
        <Group grow>
          {roles.map((role, i) => (
            <Select
              key={i}
              size="xs"
              allowDeselect={false}
              value={role}
              onChange={(v) => setRole(i, (v as ColumnRole) ?? 'ignore')}
              data={roleOptions}
            />
          ))}
        </Group>
      </Box>

      <ScrollArea h={320}>
        <Table stickyHeader striped>
          <Table.Thead>
            <Table.Tr>
              <Table.Th w={36} />
              <Table.Th>{t('import.colDate')}</Table.Th>
              <Table.Th>{t('import.colDescription')}</Table.Th>
              <Table.Th ta="right">{t('import.colAmount')}</Table.Th>
              <Table.Th>{t('table.category')}</Table.Th>
              <Table.Th>{t('import.status')}</Table.Th>
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {parsedRows.map((r, i) => (
              <Table.Tr key={i} opacity={r.error || excluded.has(i) ? 0.5 : 1}>
                <Table.Td>
                  <Checkbox
                    aria-label="include-row"
                    checked={!excluded.has(i)}
                    disabled={!!r.error}
                    onChange={() => toggleExcluded(i)}
                  />
                </Table.Td>
                <Table.Td>{r.date ?? '—'}</Table.Td>
                <Table.Td>{r.description || '—'}</Table.Td>
                <Table.Td ta="right">{r.amount != null ? r.amount.toFixed(2) : '—'}</Table.Td>
                <Table.Td>
                  <Select
                    size="xs"
                    placeholder="—"
                    data={catData}
                    value={r.categoryId}
                    onChange={(v) => setCategoryOverrides((prev) => new Map(prev).set(i, v))}
                    disabled={!!r.error}
                    renderOption={catRenderOption}
                    clearable
                  />
                </Table.Td>
                <Table.Td>
                  {r.error ? (
                    <Text size="xs" c="red">{r.error}</Text>
                  ) : (
                    <Text size="xs" c="teal">{t('import.rowOk')}</Text>
                  )}
                </Table.Td>
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
      </ScrollArea>

      <Group justify="space-between">
        <Text size="sm" c="dimmed">
          {validCount} {t('import.rowsReady')}
          {errorCount > 0 && ` · ${errorCount} ${t('import.rowsSkipped')}`}
        </Text>
        <Group>
          <Button variant="default" onClick={handleBack}>{t('import.back')}</Button>
          <Button onClick={handleImport} disabled={validCount === 0} loading={importing}>
            {t('import.confirmButton')} ({validCount})
          </Button>
        </Group>
      </Group>
    </Stack>
  );
}
