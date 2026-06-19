import { useEffect, useState } from 'react';
import { Modal, Stack, TextInput, Group, Button } from '@mantine/core';
import { DatePickerInput } from '@mantine/dates';
import type { Trip } from '../db/schema';
import { updateTrip } from '../db/repo';
import { useI18n } from '../i18n';

function toISO(d: unknown): string | null {
  if (!d) return null;
  if (typeof d === 'string') return d.slice(0, 10);
  if (d instanceof Date) {
    const p = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
  }
  return null;
}

export function TripForm({
  opened,
  onClose,
  trip,
}: {
  opened: boolean;
  onClose: () => void;
  trip: Trip;
}) {
  const { t } = useI18n();
  const [name, setName] = useState('');
  const [destination, setDestination] = useState('');
  const [range, setRange] = useState<[unknown, unknown]>([null, null]);

  useEffect(() => {
    if (!opened) return;
    setName(trip.name);
    setDestination(trip.destination ?? '');
    setRange([trip.startDate ?? null, trip.endDate ?? null]);
  }, [opened, trip]);

  async function handleSave() {
    if (!name.trim()) return;
    await updateTrip(trip.id, {
      name: name.trim(),
      destination: destination.trim() || undefined,
      startDate: toISO(range[0]),
      endDate: toISO(range[1]),
    });
    onClose();
  }

  return (
    <Modal opened={opened} onClose={onClose} title={t('trip.edit')} centered>
      <Stack>
        <TextInput
          label={t('form.name')}
          value={name}
          onChange={(e) => setName(e.currentTarget.value)}
          data-autofocus
          required
        />
        <TextInput
          label={t('form.destination')}
          placeholder={t('form.destPlaceholder')}
          value={destination}
          onChange={(e) => setDestination(e.currentTarget.value)}
        />
        <DatePickerInput
          type="range"
          label={t('form.dates')}
          placeholder={t('form.datesPlaceholder')}
          value={range as never}
          onChange={(v) => setRange(v as [unknown, unknown])}
          clearable
        />
        <Group justify="flex-end">
          <Button variant="default" onClick={onClose}>{t('common.cancel')}</Button>
          <Button onClick={handleSave} disabled={!name.trim()}>{t('common.save')}</Button>
        </Group>
      </Stack>
    </Modal>
  );
}
