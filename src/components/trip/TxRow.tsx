import { ActionIcon, Badge, Checkbox, Menu, Text } from '@mantine/core';
import { IconArrowBackUp, IconDotsVertical, IconPencil, IconTrash } from '@tabler/icons-react';
import type { Category, CityMap, Transaction } from '../../db/schema';
import { cost } from '../../db/stats';
import { useI18n } from '../../i18n';
import { CategoryIcon } from '../../lib/categoryIcons';
import { SplitTag } from './primitives';

export function TxRow({
  tx,
  cat,
  cities,
  cur,
  showMeta = true,
  showPeriod,
  selecting,
  selected,
  onToggleSelect,
  onEdit,
  onDelete,
}: {
  tx: Transaction;
  cat?: Category;
  cities: CityMap;
  cur: string;
  showMeta?: boolean;
  showPeriod?: boolean;
  selecting?: boolean;
  selected?: boolean;
  onToggleSelect?: () => void;
  onEdit?: () => void;
  onDelete?: () => void;
}) {
  const { t, money, date } = useI18n();
  const amount = cost(tx);
  const cityName = (tx.date && cities[tx.date]) || null;
  const isIof = tx.isIof;
  const isRefund = tx.kind === 'REFUND';

  return (
    <div
      className={selecting ? 'list-row list-row-clickable' : 'list-row'}
      onClick={selecting ? onToggleSelect : undefined}
      style={{
        cursor: selecting ? 'pointer' : undefined,
        background: selected ? 'var(--mantine-color-orange-light)' : undefined,
      }}
    >
      <div
        className="list-row-icon"
        style={{
          background: selecting
            ? undefined
            : isRefund
              ? 'var(--mantine-color-teal-light)'
              : cat
                ? `${cat.color}26`
                : 'var(--mantine-color-default-hover)',
        }}
      >
        {selecting ? (
          <Checkbox
            checked={selected}
            readOnly
            tabIndex={-1}
            aria-label="select-row"
            style={{ pointerEvents: 'none' }}
          />
        ) : isRefund ? (
          <IconArrowBackUp size={17} color="var(--mantine-color-teal-6)" />
        ) : cat ? (
          <CategoryIcon name={cat.icon} size={17} color={cat.color} />
        ) : (
          <Text c="dimmed">—</Text>
        )}
      </div>

      <div className="list-row-main">
        <div className="list-row-title">
          {tx.description}
          <SplitTag count={tx.splitCount} />
        </div>
        {showMeta && (
          <div className="list-row-meta">
            {isIof ? (
              <Badge variant="light" color="gray" size="xs">IOF</Badge>
            ) : isRefund ? (
              <Badge variant="light" color="teal" size="xs">{t('type.refund')}</Badge>
            ) : (
              <span>{cat ? cat.name : '—'}</span>
            )}
            {cityName && (
              <>
                <span className="list-row-meta-sep">·</span>
                <span>{cityName}</span>
              </>
            )}
            <span className="list-row-meta-sep">·</span>
            <span>{date(tx.date)}</span>
            {showPeriod && (
              <>
                <span className="list-row-meta-sep">·</span>
                <span>{tx.period === 'BEFORE' ? t('period.before') : t('period.during')}</span>
              </>
            )}
          </div>
        )}
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', flex: '0 0 auto' }}>
        <Text className="list-row-amount" c={amount < 0 ? 'teal' : undefined}>{money(amount, cur)}</Text>
        {tx.splitCount > 1 && (
          <Text size="xs" c="dimmed">{t('table.full')} {money(tx.amount, cur)}</Text>
        )}
      </div>

      {!selecting && (onEdit || onDelete) && (
        <Menu withinPortal position="bottom-end" shadow="md">
          <Menu.Target>
            <ActionIcon variant="subtle" color="gray" aria-label="more-actions">
              <IconDotsVertical size={16} />
            </ActionIcon>
          </Menu.Target>
          <Menu.Dropdown>
            {onEdit && (
              <Menu.Item leftSection={<IconPencil size={14} />} onClick={onEdit}>
                {t('common.edit')}
              </Menu.Item>
            )}
            {onDelete && (
              <Menu.Item leftSection={<IconTrash size={14} />} color="red" onClick={onDelete}>
                {t('tx.deleteOne')}
              </Menu.Item>
            )}
          </Menu.Dropdown>
        </Menu>
      )}
    </div>
  );
}
