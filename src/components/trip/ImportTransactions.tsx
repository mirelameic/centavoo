import { useMemo, useState } from 'react';
import {
  Modal,
  Stack,
  Group,
  Button,
  Badge,
  Textarea,
  FileButton,
  Select,
  Checkbox,
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
import { periodForDate } from '../../lib/format';
import {
  splitRows,
  parseAmount,
  parseDate,
  guessRoles,
  looksLikeHeaderRow,
  deriveKind,
  deriveIsIof,
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
  isIof: boolean;
  period: Period;
  error: string | null;
}

function Flow({ onClose, trip, categories, rules }: Omit<Props, 'opened'>) {
  const { t } = useI18n();

  const [rawText, setRawText] = useState('');
  const [delimiter, setDelimiter] = useState<DelimiterOption>('auto');
  const [noRowsError, setNoRowsError] = useState(false);

  const [rows, setRows] = useState<string[][] | null>(null);
  const [roles, setRoles] = useState<ColumnRole[]>([]);
  const [hasHeader, setHasHeader] = useState(false);
  const [invertSign, setInvertSign] = useState(false);
  const [excluded, setExcluded] = useState<Set<number>>(new Set());
  const [categoryOverrides, setCategoryOverrides] = useState<Map<number, string | null>>(new Map());
  const [iofOverrides, setIofOverrides] = useState<Map<number, boolean>>(new Map());
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
    setIofOverrides(new Map());
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

      const kind = deriveKind(amount);

      const suggested = !error ? suggestCategory(description, rules) : null;
      const categoryId =
        kind === 'REFUND'
          ? null
          : (categoryOverrides.get(i) ??
            (suggested && categories.some((c) => c.id === suggested) ? suggested : null));

      const isIof = iofOverrides.get(i) ?? deriveIsIof(kind, description);

      const rowPeriod = periodForDate(date, trip.startDate) ?? 'DURING';

      return {
        date,
        description,
        amount,
        kind,
        categoryId,
        isIof,
        period: rowPeriod,
        error,
      };
    });
  }, [dataRows, roles, invertSign, categoryOverrides, iofOverrides, categories, rules, t, trip.startDate]);

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
        period: r.period,
        date: r.date,
        description: r.description,
        amount: r.amount as number,
        categoryId: r.categoryId,
        kind: r.kind,
        isIof: r.isIof,
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

  return (
    <Stack>
      <Group gap="xl">
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
      </Group>

      <Box>
        <Text size="sm" fw={600} mb={4}>{t('import.mapHint')}</Text>
        <Group gap="sm" align="flex-start" wrap="wrap">
          {roles.map((role, i) => (
            <Stack key={i} gap={4} miw={110} style={{ flex: '1 1 110px' }}>
              <Text size="xs" c="dimmed">
                {t('import.columnN').replace('{n}', String(i + 1))}
              </Text>
              <Select
                size="xs"
                allowDeselect={false}
                value={role}
                onChange={(v) => setRole(i, (v as ColumnRole) ?? 'ignore')}
                data={roleOptions}
              />
              <Text size="xs" c="dimmed" truncate>
                {dataRows[0]?.[i] || '—'}
              </Text>
            </Stack>
          ))}
        </Group>
      </Box>

      <ScrollArea h={320}>
        <div>
          {parsedRows.map((r, i) => (
            <div
              key={i}
              className="list-row"
              style={{ alignItems: 'flex-start', opacity: r.error || excluded.has(i) ? 0.5 : 1 }}
            >
              <Checkbox
                mt={2}
                aria-label="include-row"
                checked={!excluded.has(i)}
                disabled={!!r.error}
                onChange={() => toggleExcluded(i)}
              />
              <div className="list-row-main">
                <div className="list-row-title">{r.description || '—'}</div>
                <div className="list-row-meta">
                  <span>{r.date ?? '—'}</span>
                  <span className="list-row-meta-sep">·</span>
                  <span>{r.period === 'BEFORE' ? t('period.before') : t('period.during')}</span>
                  <span className="list-row-meta-sep">·</span>
                  {r.error ? (
                    <Text span size="xs" c="red">{r.error}</Text>
                  ) : (
                    <Text span size="xs" c="teal">{t('import.rowOk')}</Text>
                  )}
                </div>
                {r.kind === 'REFUND' ? (
                  <Group gap={8} mt={6}>
                    <Badge variant="light" color={r.isIof ? 'gray' : 'teal'} size="sm">
                      {r.isIof ? 'IOF' : t('type.refund')}
                    </Badge>
                    <Checkbox
                      size="xs"
                      label={t('type.iof')}
                      checked={r.isIof}
                      disabled={!!r.error}
                      onChange={(e) => {
                        const checked = e.currentTarget.checked;
                        setIofOverrides((prev) => new Map(prev).set(i, checked));
                      }}
                    />
                  </Group>
                ) : (
                  <Select
                    mt={6}
                    size="xs"
                    w={220}
                    maw="100%"
                    placeholder="—"
                    data={catData}
                    value={r.categoryId}
                    onChange={(v) => setCategoryOverrides((prev) => new Map(prev).set(i, v))}
                    disabled={!!r.error}
                    renderOption={catRenderOption}
                    clearable
                  />
                )}
              </div>
              <Text className="list-row-amount">{r.amount != null ? r.amount.toFixed(2) : '—'}</Text>
            </div>
          ))}
        </div>
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
