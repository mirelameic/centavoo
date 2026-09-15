import { useState } from 'react';
import {
  ActionIcon,
  Box,
  Button,
  Card,
  Group,
  Pill,
  Select,
  Stack,
  Text,
  TextInput,
} from '@mantine/core';
import { DatePickerInput } from '@mantine/dates';
import { IconCheck, IconPencil, IconPlus, IconTrash, IconX } from '@tabler/icons-react';
import { colorForCity } from '../../db/stats';
import type { CityMap } from '../../db/schema';
import { setTripCityRange, updateTrip } from '../../db/repo';
import { dateRange, groupCityBlocks, toISO, type CityBlock } from '../../lib/format';
import { confirmDelete } from '../../lib/confirm';
import { useI18n } from '../../i18n';
import { Dot } from './primitives';

export function CityEditor({
  tripId,
  days,
  cities,
  cityList,
}: {
  tripId: string;
  days: string[];
  cities: CityMap;
  cityList?: string[];
}) {
  const { t, date } = useI18n();
  const distinct = [...new Set(Object.values(cities).filter(Boolean))].sort();
  const listValue = cityList ?? distinct;

  const blocks = groupCityBlocks(days, cities);
  const unassigned = days.length - blocks.reduce((n, b) => n + b.days.length, 0);

  const [editing, setEditing] = useState<CityBlock | null>(null);
  const [formCity, setFormCity] = useState<string | null>(null);
  const [formRange, setFormRange] = useState<[string | null, string | null]>([null, null]);

  const resetForm = () => {
    setEditing(null);
    setFormCity(null);
    setFormRange([null, null]);
  };

  const startEdit = (b: CityBlock) => {
    setEditing(b);
    setFormCity(b.city);
    setFormRange([b.start, b.end]);
  };

  const submit = async () => {
    if (!formCity || !formRange[0] || !formRange[1]) return;
    if (editing) await setTripCityRange(tripId, editing.days, '');
    await setTripCityRange(tripId, dateRange(formRange[0], formRange[1]), formCity);
    resetForm();
  };

  const removeBlock = (b: CityBlock) => {
    confirmDelete(t('city.removeBlockConfirm'), async () => {
      await setTripCityRange(tripId, b.days, '');
      if (editing === b) resetForm();
    });
  };

  const removeCity = async (city: string) => {
    const daysUsed = days.filter((d) => cities[d] === city);
    const removeIt = async () => {
      if (daysUsed.length > 0) await setTripCityRange(tripId, daysUsed, '');
      await updateTrip(tripId, { cityList: listValue.filter((c) => c !== city) });
    };
    if (daysUsed.length > 0) {
      const msg = `${city} — ${daysUsed.length} ${t('city.daysN')}. ${t('city.removeUsedWarning')}`;
      confirmDelete(msg, removeIt);
    } else {
      await removeIt();
    }
  };

  const [addingCity, setAddingCity] = useState(false);
  const [newCityText, setNewCityText] = useState('');

  const cancelAddCity = () => {
    setAddingCity(false);
    setNewCityText('');
  };

  const confirmAddCity = async () => {
    const v = newCityText.trim();
    if (v && !listValue.includes(v)) {
      await updateTrip(tripId, { cityList: [...listValue, v] });
    }
    cancelAddCity();
  };

  return (
    <Stack gap="sm">
      <Box>
        <Text size="sm" fw={500} mb={6}>{t('city.list')}</Text>
        <Pill.Group>
          {listValue.map((city) => (
            <Pill
              key={city}
              size="md"
              withRemoveButton
              onRemove={() => removeCity(city)}
              removeButtonProps={{ 'aria-label': `${t('city.removeCity')} ${city}`, 'aria-hidden': false }}
            >
              <Group gap={6} wrap="nowrap">
                <Dot color={colorForCity(city)} />
                {city}
              </Group>
            </Pill>
          ))}
          {addingCity ? (
            <Group gap={4} wrap="nowrap">
              <TextInput
                size="xs"
                autoFocus
                value={newCityText}
                onChange={(e) => setNewCityText(e.currentTarget.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') confirmAddCity();
                  if (e.key === 'Escape') cancelAddCity();
                }}
                placeholder={t('city.placeholder')}
                style={{ width: 140 }}
              />
              <ActionIcon variant="filled" aria-label="confirm-add-city" onClick={confirmAddCity}>
                <IconCheck size={16} />
              </ActionIcon>
              <ActionIcon variant="subtle" color="gray" aria-label="cancel-add-city" onClick={cancelAddCity}>
                <IconX size={16} />
              </ActionIcon>
            </Group>
          ) : (
            <Button
              size="xs"
              variant="light"
              radius="xl"
              leftSection={<IconPlus size={14} />}
              onClick={() => setAddingCity(true)}
            >
              {t('city.addCity')}
            </Button>
          )}
        </Pill.Group>
      </Box>

      <Group align="flex-end" gap="xs" wrap="wrap">
        <Select
          label={t('city.blockCityLabel')}
          placeholder={t('city.placeholder')}
          data={listValue}
          value={formCity}
          onChange={setFormCity}
          searchable
          style={{ flex: '1 1 160px' }}
        />
        <DatePickerInput
          type="range"
          label={t('city.blockRangeLabel')}
          valueFormat="DD/MM/YY"
          value={formRange}
          onChange={(v) => setFormRange([toISO(v[0]), toISO(v[1])])}
          style={{ flex: '1 1 200px' }}
        />
        <Button size="sm" onClick={submit} disabled={!formCity || !formRange[0] || !formRange[1]}>
          {editing ? t('common.save') : t('city.addBlock')}
        </Button>
        {editing && (
          <Button size="sm" variant="subtle" onClick={resetForm}>{t('common.cancel')}</Button>
        )}
      </Group>

      <Stack gap={6}>
        {blocks.length === 0 && (
          <Text size="sm" c="dimmed">{t('city.noBlocks')}</Text>
        )}
        {blocks.map((b) => (
          <Card key={`${b.city}-${b.start}`} withBorder padding="xs">
            <Group justify="space-between" wrap="nowrap">
              <Group gap={8} wrap="nowrap">
                <Dot color={colorForCity(b.city)} />
                <Box>
                  <Text size="sm" fw={600}>{b.city}</Text>
                  <Text size="xs" c="dimmed">
                    {b.start === b.end ? date(b.start) : `${date(b.start)} – ${date(b.end)}`}
                    {' · '}{b.days.length} {t('city.daysN')}
                  </Text>
                </Box>
              </Group>
              <Group gap={4} wrap="nowrap">
                <ActionIcon
                  variant="subtle"
                  color="gray"
                  aria-label="edit-city-block"
                  onClick={() => startEdit(b)}
                >
                  <IconPencil size={16} />
                </ActionIcon>
                <ActionIcon
                  variant="subtle"
                  color="red"
                  aria-label="delete-city-block"
                  onClick={() => removeBlock(b)}
                >
                  <IconTrash size={16} />
                </ActionIcon>
              </Group>
            </Group>
          </Card>
        ))}
        {unassigned > 0 && (
          <Text size="xs" c="dimmed">{unassigned} {t('city.unassignedN')}</Text>
        )}
      </Stack>
    </Stack>
  );
}
