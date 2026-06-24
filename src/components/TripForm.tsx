import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Modal, Stack, TextInput, Group, Button, Divider } from '@mantine/core';
import { DatePickerInput } from '@mantine/dates';
import { IconTrash } from '@tabler/icons-react';
import type { Trip } from '../db/schema';
import { updateTrip, deleteTrip } from '../db/repo';
import { toISO } from '../lib/format';
import { useI18n } from '../i18n';

interface Props {
  opened: boolean;
  onClose: () => void;
  trip: Trip;
}

// The fields remount (via `key`) each time the modal opens, so state starts from
// the current trip — no reset effect needed.
export function TripForm({ opened, onClose, trip }: Props) {
  const { t } = useI18n();
  return (
    <Modal opened={opened} onClose={onClose} title={t('trip.edit')} centered>
      {opened && <Fields key={trip.id} trip={trip} onClose={onClose} />}
    </Modal>
  );
}

function Fields({ trip, onClose }: Omit<Props, 'opened'>) {
  const { t } = useI18n();
  const navigate = useNavigate();
  const [name, setName] = useState(trip.name);
  const [destination, setDestination] = useState(trip.destination ?? '');
  const [range, setRange] = useState<[unknown, unknown]>([
    trip.startDate ?? null,
    trip.endDate ?? null,
  ]);

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

  async function handleDelete() {
    if (window.confirm(t('trip.deleteConfirm'))) {
      await deleteTrip(trip.id);
      onClose();
      navigate('/');
    }
  }

  return (
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
      <Divider my="xs" />
      <Button
        variant="light"
        color="red"
        leftSection={<IconTrash size={16} />}
        onClick={handleDelete}
      >
        {t('trip.delete')}
      </Button>
    </Stack>
  );
}
