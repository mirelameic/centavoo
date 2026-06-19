// Domain types. These same shapes are produced by the Python seed
// (scripts/seed_europa.py -> public/europa.json).

export type Period = 'BEFORE' | 'DURING';
export type Kind = 'EXPENSE' | 'REFUND' | 'IOF_REFUND';

export interface Trip {
  id: string;
  name: string;
  destination?: string;
  startDate?: string | null; // 'YYYY-MM-DD'
  endDate?: string | null;
  currency: string;          // 'BRL'
  notes?: string;
  createdAt: string;
}

export interface Category {
  id: string;
  name: string;
  color: string;             // hex, e.g. '#FF9900'
  icon?: string;             // emoji
  sortOrder: number;
}

export interface Transaction {
  id: string;
  tripId: string;
  period: Period;
  date?: string | null;      // 'YYYY-MM-DD' (may be null for BEFORE)
  description: string;
  amount: number;            // SIGNED full amount: expense +, refund -
  categoryId?: string | null;
  kind: Kind;
  isIof: boolean;
  splitCount: number;        // 1 = no split; effective cost = amount / splitCount
  city?: string | null;      // where it happened (null for pre-trip BEFORE items)
  rawText?: string;
  createdAt: string;
}

export interface CategoryRule {
  id?: number;               // auto-increment in Dexie
  keyword: string;           // lowercase substring to look for in the description
  categoryId: string;
  priority: number;          // higher wins
}
