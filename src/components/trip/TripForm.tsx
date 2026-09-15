import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Modal, Stack, Group, Button, Divider } from '@mantine/core';
import type { DateValue } from '@mantine/dates';
import { IconTrash } from '@tabler/icons-react';
import type { Trip } from '../../db/schema';
import { updateTrip, deleteTrip, reassignTransactionPeriods } from '../../db/repo';
import { confirmDelete } from '../../lib/confirm';
import { toISO } from '../../lib/format';
import { useI18n } from '../../i18n';
import { TripIdentityFields } from './TripFields';

interface Props {
  opened: boolean;
  onClose: () => void;
  trip: Trip;
}

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
  const [range, setRange] = useState<[DateValue, DateValue]>([
    trip.startDate ?? null,
    trip.endDate ?? null,
  ]);

  async function handleSave() {
    if (!name.trim()) return;
    const startDate = toISO(range[0]);
    await updateTrip(trip.id, {
      name: name.trim(),
      destination: destination.trim() || undefined,
      startDate,
      endDate: toISO(range[1]),
    });
    await reassignTransactionPeriods(trip.id, startDate);
    onClose();
  }

  function handleDelete() {
    confirmDelete(t('trip.deleteConfirm'), async () => {
      await deleteTrip(trip.id);
      onClose();
      navigate('/');
    });
  }

  return (
    <Stack>
      <TripIdentityFields
        name={name}
        onNameChange={setName}
        destination={destination}
        onDestinationChange={setDestination}
        range={range}
        onRangeChange={setRange}
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
