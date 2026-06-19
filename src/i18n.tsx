import { createContext, useContext, useMemo, useState, type ReactNode } from 'react';
import { money as fmtMoney, fmtDate } from './lib/format';

// Minimal i18n. The UI defaults to Portuguese; switching language is instant and
// the choice is persisted. To add another language, add a dictionary below.
export type Lang = 'pt' | 'en';

const LOCALE: Record<Lang, string> = { pt: 'pt-BR', en: 'en-US' };

type Dict = Record<string, string>;

const pt: Dict = {
  'app.title': 'Centavoo',
  'loading': 'Preparando seus dados…',
  'error': 'Erro ao carregar os dados.',

  'trips.title': 'Minhas viagens',
  'trips.new': 'Nova viagem',
  'trips.empty': 'Nenhuma viagem ainda.',
  'trips.createFirst': 'Criar a primeira',
  'trips.netSpend': 'Gasto líquido',

  'form.name': 'Nome',
  'form.namePlaceholder': 'ex. Europa 2025',
  'form.destination': 'Destino',
  'form.destPlaceholder': 'ex. Espanha · Grécia',
  'form.dates': 'Período',
  'form.datesPlaceholder': 'início – fim',
  'common.cancel': 'Cancelar',
  'common.create': 'Criar',
  'common.back': 'Voltar',

  'nav.trips': 'Viagens',
  'kpi.net': 'Líquido',
  'kpi.gross': 'Gasto bruto',
  'kpi.refunds': 'Reembolsos',
  'kpi.before': 'Antes',
  'kpi.during': 'Durante',
  'kpi.avgPerDay': 'Média/dia',

  'tab.summary': 'Resumo',
  'tab.byDay': 'Por dia',
  'tab.byCity': 'Por cidade',
  'tab.beforeDuring': 'Antes × Durante',
  'tab.transactions': 'Transações',

  'chart.before': 'Antes',
  'chart.during': 'Durante',
  'chart.noDated': 'Sem gastos com data neste período.',
  'chart.noCity': 'Nenhuma transação com cidade ainda.',

  'city.perDay': 'Cidades por dia',
  'city.placeholder': 'cidade',

  'table.date': 'Data',
  'table.description': 'Descrição',
  'table.category': 'Categoria',
  'table.city': 'Cidade',
  'table.period': 'Período',
  'table.amount': 'Valor',
  'table.full': 'integral',

  'period.before': 'Antes',
  'period.during': 'Durante',
  'trip.notFound': 'Viagem não encontrada.',
};

const en: Dict = {
  'app.title': 'Centavoo',
  'loading': 'Preparing your data…',
  'error': 'Failed to load data.',

  'trips.title': 'My trips',
  'trips.new': 'New trip',
  'trips.empty': 'No trips yet.',
  'trips.createFirst': 'Create the first one',
  'trips.netSpend': 'Net spend',

  'form.name': 'Name',
  'form.namePlaceholder': 'e.g. Europe 2025',
  'form.destination': 'Destination',
  'form.destPlaceholder': 'e.g. Spain · Greece',
  'form.dates': 'Dates',
  'form.datesPlaceholder': 'start – end',
  'common.cancel': 'Cancel',
  'common.create': 'Create',
  'common.back': 'Back',

  'nav.trips': 'Trips',
  'kpi.net': 'Net',
  'kpi.gross': 'Gross',
  'kpi.refunds': 'Refunds',
  'kpi.before': 'Before',
  'kpi.during': 'During',
  'kpi.avgPerDay': 'Avg/day',

  'tab.summary': 'Summary',
  'tab.byDay': 'By day',
  'tab.byCity': 'By city',
  'tab.beforeDuring': 'Before × During',
  'tab.transactions': 'Transactions',

  'chart.before': 'Before',
  'chart.during': 'During',
  'chart.noDated': 'No dated expenses in this period.',
  'chart.noCity': 'No transactions with a city yet.',

  'city.perDay': 'Cities per day',
  'city.placeholder': 'city',

  'table.date': 'Date',
  'table.description': 'Description',
  'table.category': 'Category',
  'table.city': 'City',
  'table.period': 'Period',
  'table.amount': 'Amount',
  'table.full': 'full',

  'period.before': 'Before',
  'period.during': 'During',
  'trip.notFound': 'Trip not found.',
};

const DICTS: Record<Lang, Dict> = { pt, en };

interface I18n {
  lang: Lang;
  setLang: (l: Lang) => void;
  t: (key: string) => string;
  locale: string;
  money: (n: number, currency?: string) => string;
  date: (d?: string | null) => string;
}

const Ctx = createContext<I18n | null>(null);

export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(
    () => (localStorage.getItem('lang') as Lang) || 'pt',
  );

  const value = useMemo<I18n>(() => {
    const locale = LOCALE[lang];
    return {
      lang,
      setLang: (l) => {
        localStorage.setItem('lang', l);
        setLangState(l);
      },
      t: (key) => DICTS[lang][key] ?? pt[key] ?? key,
      locale,
      money: (n, currency = 'BRL') => fmtMoney(n, currency, locale),
      date: (d) => fmtDate(d, locale),
    };
  }, [lang]);

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useI18n(): I18n {
  const v = useContext(Ctx);
  if (!v) throw new Error('useI18n must be used within I18nProvider');
  return v;
}
