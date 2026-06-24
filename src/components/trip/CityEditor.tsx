import { Box, Group, Select, Stack, TagsInput, Text } from '@mantine/core';
import type { CityMap } from '../../db/schema';
import { setTripCity, updateTrip } from '../../db/repo';
import { useI18n } from '../../i18n';

// Editable city per day. First you list the trip's cities (TagsInput), then pick
// one per day from a dropdown. Stored on the trip (a day = a city); days flow
// top-to-bottom in date order via CSS columns.
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
  const options = [...new Set([...listValue, ...distinct])].sort();
  return (
    <Stack gap="sm">
      <TagsInput
        label={t('city.list')}
        placeholder={t('city.listPlaceholder')}
        value={listValue}
        onChange={(vals) => updateTrip(tripId, { cityList: vals })}
        clearable
      />
      <Box style={{ columnWidth: 240, columnGap: 16 }}>
        {days.map((d) => (
          <Group key={d} gap="xs" wrap="nowrap" style={{ breakInside: 'avoid', marginBottom: 8 }}>
            <Text size="sm" c="dimmed" w={56}>{date(d)}</Text>
            <Select
              size="xs"
              placeholder={t('city.placeholder')}
              data={options}
              value={cities[d] ?? null}
              onChange={(v) => setTripCity(tripId, d, v ?? '')}
              searchable
              clearable
              style={{ flex: 1 }}
            />
          </Group>
        ))}
      </Box>
    </Stack>
  );
}
