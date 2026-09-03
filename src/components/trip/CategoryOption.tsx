import { Box, Group } from '@mantine/core';
import type { Category } from '../../db/schema';
import { CategoryIcon } from '../../lib/categoryIcons';

// Option row for a category Select/MultiSelect: icon + label, optionally a color swatch.
export function CategoryOption({
  category,
  label,
  withSwatch = false,
}: {
  category?: Category;
  label: string;
  withSwatch?: boolean;
}) {
  return (
    <Group gap={8} wrap="nowrap">
      {withSwatch && (
        <Box w={12} h={12} style={{ background: category?.color, borderRadius: 3 }} />
      )}
      <CategoryIcon name={category?.icon} size={14} />
      {label}
    </Group>
  );
}
