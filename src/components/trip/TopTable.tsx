import type { Category, CityMap, Transaction } from '../../db/schema';
import { TxRow } from './TxRow';

export function TopTable({
  items,
  catById,
  cities,
  cur,
}: {
  items: Transaction[];
  catById: Map<string, Category>;
  cities: CityMap;
  cur: string;
}) {
  return (
    <div>
      {items.map((tx) => (
        <TxRow
          key={tx.id}
          tx={tx}
          cat={tx.categoryId ? catById.get(tx.categoryId) : undefined}
          cities={cities}
          cur={cur}
          showMeta={false}
        />
      ))}
    </div>
  );
}
