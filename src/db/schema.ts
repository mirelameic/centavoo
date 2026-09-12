export type Period = 'BEFORE' | 'DURING';
export type Kind = 'EXPENSE' | 'REFUND' | 'IOF_REFUND';

export type CityMap = Record<string, string>;

export interface Trip {
  id: string;
  name: string;
  destination?: string;
  startDate?: string | null;
  endDate?: string | null;
  currency: string;
  notes?: string;
  cities?: CityMap;
  cityList?: string[];
  createdAt: string;
}

export interface Category {
  id: string;
  tripId: string;
  name: string;
  color: string;
  icon?: string;
  sortOrder: number;
}

export interface Transaction {
  id: string;
  tripId: string;
  period: Period;
  date?: string | null;
  description: string;
  amount: number;
  categoryId?: string | null;
  kind: Kind;
  isIof: boolean;
  splitCount: number;
  city?: string | null;
  rawText?: string;
  createdAt: string;
}

export interface CategoryRule {
  id?: number;
  keyword: string;
  categoryId: string;
  priority: number;
}
