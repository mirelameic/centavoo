import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  Container,
  SimpleGrid,
  Card,
  Group,
  Stack,
  Text,
  Title,
  Button,
  Badge,
  Modal,
  TextInput,
  Center,
} from '@mantine/core';
import { DatePickerInput } from '@mantine/dates';
import { useDisclosure } from '@mantine/hooks';
import { IconPlus, IconMapPin } from '@tabler/icons-react';
import { db } from '../db/db';
import { cost, createTrip } from '../db/repo';
import { useI18n } from '../i18n';

function toISO(d: unknown): string | null {
  if (!d) return null;
  if (typeof d === 'string') return d.slice(0, 10);
  if (d instanceof Date) return d.toISOString().slice(0, 10);
  return null;
}

export function Trips() {
  const { t, money, date } = useI18n();
  const trips = useLiveQuery(() => db.trips.orderBy('createdAt').reverse().toArray(), []);
  const txs = useLiveQuery(() => db.transactions.toArray(), []);

  const netByTrip = useMemo(() => {
    const m = new Map<string, number>();
    for (const tx of txs ?? []) m.set(tx.tripId, (m.get(tx.tripId) ?? 0) + cost(tx));
    return m;
  }, [txs]);

  const [opened, { open, close }] = useDisclosure(false);
  const [name, setName] = useState('');
  const [destination, setDestination] = useState('');
  const [range, setRange] = useState<[unknown, unknown]>([null, null]);

  async function handleCreate() {
    if (!name.trim()) return;
    await createTrip({
      name: name.trim(),
      destination: destination.trim() || undefined,
      startDate: toISO(range[0]),
      endDate: toISO(range[1]),
    });
    setName('');
    setDestination('');
    setRange([null, null]);
    close();
  }

  return (
    <Container size="lg" px={0}>
      <Group justify="space-between" mb="lg">
        <Title order={2}>{t('trips.title')}</Title>
        <Button leftSection={<IconPlus size={18} />} onClick={open}>
          {t('trips.new')}
        </Button>
      </Group>

      {trips && trips.length === 0 && (
        <Center mih="40vh">
          <Stack align="center">
            <Text c="dimmed">{t('trips.empty')}</Text>
            <Button leftSection={<IconPlus size={18} />} onClick={open}>
              {t('trips.createFirst')}
            </Button>
          </Stack>
        </Center>
      )}

      <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="md">
        {trips?.map((tr) => (
          <Card
            key={tr.id}
            renderRoot={(props) => <Link to={`/trip/${tr.id}`} {...props} />}
            withBorder
            shadow="sm"
            padding="lg"
            style={{ textDecoration: 'none', color: 'inherit', cursor: 'pointer' }}
          >
            <Stack gap="xs">
              <Text fw={700} size="lg">{tr.name}</Text>
              {tr.destination && (
                <Group gap={4} c="dimmed">
                  <IconMapPin size={14} />
                  <Text size="sm">{tr.destination}</Text>
                </Group>
              )}
              <Text size="sm" c="dimmed">
                {date(tr.startDate)} – {date(tr.endDate)}
              </Text>
              <Group justify="space-between" mt="sm">
                <Badge variant="light" color="grape">{t('trips.netSpend')}</Badge>
                <Text fw={700}>{money(netByTrip.get(tr.id) ?? 0, tr.currency)}</Text>
              </Group>
            </Stack>
          </Card>
        ))}
      </SimpleGrid>

      <Modal opened={opened} onClose={close} title={t('trips.new')} centered>
        <Stack>
          <TextInput
            label={t('form.name')}
            placeholder={t('form.namePlaceholder')}
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
            <Button variant="default" onClick={close}>{t('common.cancel')}</Button>
            <Button onClick={handleCreate} disabled={!name.trim()}>{t('common.create')}</Button>
          </Group>
        </Stack>
      </Modal>
    </Container>
  );
}
