import { useState } from 'react';
import {
  Modal,
  Stack,
  Group,
  Button,
  SegmentedControl,
  TextInput,
  NumberInput,
  Select,
  Box,
} from '@mantine/core';
import { DatePickerInput } from '@mantine/dates';
import type { Category, CategoryRule, Kind, Period, Transaction, Trip } from '../db/schema';
import { addTransaction, updateTransaction } from '../db/repo';
import { suggestCategory } from '../lib/categorize';
import { toISO } from '../lib/format';
import { useI18n } from '../i18n';

interface Props {
  opened: boolean;
  onClose: () => void;
  trip: Trip;
  categories: Category[];
  rules: CategoryRule[];
  editing?: Transaction | null;
}

// The fields remount (via `key`) whenever the modal opens or the edited row
// changes, so state is initialized straight from props — no reset effect needed.
export function TransactionForm({ opened, onClose, editing, ...rest }: Props) {
  const { t } = useI18n();
  return (
    <Modal opened={opened} onClose={onClose} title={editing ? t('tx.edit') : t('tx.new')} centered>
      {opened && <Fields key={editing?.id ?? 'new'} editing={editing} onClose={onClose} {...rest} />}
    </Modal>
  );
}

function Fields({
  onClose,
  trip,
  categories,
  rules,
  editing,
}: Omit<Props, 'opened'>) {
  const { t } = useI18n();

  const [period, setPeriod] = useState<Period>(editing?.period ?? 'DURING');
  const [date, setDate] = useState<string | null>(
    editing ? editing.date ?? null : trip.startDate ?? null,
  );
  const [description, setDescription] = useState(editing?.description ?? '');
  const [amount, setAmount] = useState<number | string>(editing ? Math.abs(editing.amount) : '');
  const [type, setType] = useState<Kind>(editing?.kind ?? 'EXPENSE');
  const [categoryId, setCategoryId] = useState<string | null>(editing?.categoryId ?? null);
  const [splitCount, setSplitCount] = useState<number | string>(editing?.splitCount || 1);

  const colorById = new Map(categories.map((c) => [c.id, c.color] as const));
  const catData = categories.map((c) => ({ value: c.id, label: c.name }));

  function suggestFromDescription() {
    if (!categoryId && description.trim()) {
      const s = suggestCategory(description, rules);
      // only apply if the suggested category belongs to this trip
      if (s && categories.some((c) => c.id === s)) setCategoryId(s);
    }
  }

  const amountNum = typeof amount === 'number' ? amount : parseFloat(amount as string);
  const valid = description.trim().length > 0 && amountNum > 0;

  async function handleSave() {
    if (!valid) return;
    const abs = Math.abs(amountNum);
    const signed = type === 'EXPENSE' ? abs : -abs;
    const payload = {
      tripId: trip.id,
      period,
      date: date ?? null,
      description: description.trim(),
      amount: signed,
      categoryId: type === 'IOF_REFUND' ? null : categoryId,
      kind: type,
      isIof: type === 'IOF_REFUND',
      splitCount: Math.max(1, Number(splitCount) || 1),
    };
    if (editing) {
      await updateTransaction(editing.id, payload);
    } else {
      await addTransaction(payload);
    }
    onClose();
  }

  return (
    <Stack>
      <SegmentedControl
        fullWidth
        value={period}
        onChange={(v) => setPeriod(v as Period)}
        data={[
          { label: t('period.before'), value: 'BEFORE' },
          { label: t('period.during'), value: 'DURING' },
        ]}
      />
      <DatePickerInput
        label={t('table.date')}
        placeholder="—"
        value={date as never}
        onChange={(v) => setDate(toISO(v))}
        clearable
      />
      <TextInput
        label={t('table.description')}
        value={description}
        onChange={(e) => setDescription(e.currentTarget.value)}
        onBlur={suggestFromDescription}
        data-autofocus
        required
      />
      <Group grow>
        <NumberInput
          label={t('table.amount')}
          prefix={`${trip.currency === 'BRL' ? 'R$ ' : ''}`}
          decimalScale={2}
          min={0}
          value={amount}
          onChange={setAmount}
          required
        />
        <NumberInput
          label={t('field.split')}
          min={1}
          step={1}
          value={splitCount}
          onChange={setSplitCount}
        />
      </Group>
      <Select
        label={t('field.type')}
        data={[
          { value: 'EXPENSE', label: t('type.expense') },
          { value: 'REFUND', label: t('type.refund') },
          { value: 'IOF_REFUND', label: t('type.iof') },
        ]}
        value={type}
        onChange={(v) => setType((v as Kind) ?? 'EXPENSE')}
        allowDeselect={false}
      />
      {type !== 'IOF_REFUND' && (
        <Select
          label={t('table.category')}
          placeholder="—"
          data={catData}
          value={categoryId}
          onChange={setCategoryId}
          searchable
          clearable
          renderOption={({ option }) => (
            <Group gap={8}>
              <Box
                w={12}
                h={12}
                style={{ background: colorById.get(option.value), borderRadius: 3 }}
              />
              {option.label}
            </Group>
          )}
        />
      )}
      <Group justify="flex-end" mt="xs">
        <Button variant="default" onClick={onClose}>{t('common.cancel')}</Button>
        <Button onClick={handleSave} disabled={!valid}>{t('common.save')}</Button>
      </Group>
    </Stack>
  );
}
