import { TextInput } from '@mantine/core';
import { DatePickerInput, type DateValue } from '@mantine/dates';
import { useI18n } from '../../i18n';

interface Props {
  name: string;
  onNameChange: (v: string) => void;
  destination: string;
  onDestinationChange: (v: string) => void;
  range: [DateValue, DateValue];
  onRangeChange: (v: [DateValue, DateValue]) => void;
}

// Name + destination + date-range fields shared by the "new trip" (Trips) and
// "edit trip" (TripForm) modals.
export function TripIdentityFields({
  name,
  onNameChange,
  destination,
  onDestinationChange,
  range,
  onRangeChange,
}: Props) {
  const { t } = useI18n();
  return (
    <>
      <TextInput
        label={t('form.name')}
        placeholder={t('form.namePlaceholder')}
        value={name}
        onChange={(e) => onNameChange(e.currentTarget.value)}
        data-autofocus
        required
      />
      <TextInput
        label={t('form.destination')}
        placeholder={t('form.destPlaceholder')}
        value={destination}
        onChange={(e) => onDestinationChange(e.currentTarget.value)}
      />
      <DatePickerInput
        type="range"
        label={t('form.dates')}
        placeholder={t('form.datesPlaceholder')}
        value={range}
        onChange={onRangeChange}
        clearable
      />
    </>
  );
}
