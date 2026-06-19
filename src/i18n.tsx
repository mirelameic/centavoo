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
  'city.list': 'Cidades da viagem',
  'city.listPlaceholder': 'adicione e tecle Enter',
  'tx.deleteSelected': 'Excluir selecionadas',
  'tx.selectedN': 'selecionadas',
  'tx.deleteSelectedConfirm': 'Excluir as transações selecionadas?',

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

  'common.save': 'Salvar',
  'common.edit': 'Editar',
  'common.delete': 'Excluir',
  'tx.new': 'Nova transação',
  'tx.edit': 'Editar transação',
  'tx.deleteConfirm': 'Excluir esta transação?',
  'field.type': 'Tipo',
  'field.split': 'Dividir por',
  'type.expense': 'Gasto',
  'type.refund': 'Reembolso',
  'type.iof': 'Reembolso de IOF',
  'menu.categories': 'Categorias',
  'menu.export': 'Exportar dados',
  'menu.import': 'Importar dados',
  'cat.title': 'Categorias',
  'cat.new': 'Nova categoria',
  'cat.color': 'Cor',
  'cat.emoji': 'Emoji',
  'cat.empty': 'Nenhuma categoria.',
  'cat.deleteConfirm': 'Excluir categoria? As transações dela ficam sem categoria.',
  'backup.exportedOk': 'Backup exportado.',
  'backup.importedOk': 'Backup importado com sucesso.',
  'backup.importError': 'Arquivo de backup inválido.',

  'tab.time': 'Tempo',
  'tab.cities': 'Cidades',
  'tab.cats': 'Categorias',
  'sec.byDay': 'Por dia',
  'sec.calendar': 'Calendário',
  'sec.weekday': 'Por dia da semana',
  'sec.catMix': 'Mix de categorias no tempo',
  'sec.byCity': 'Por cidade',
  'sec.avgCity': 'Custo médio por dia (por cidade)',
  'sec.cityTable': 'Resumo por cidade',
  'sec.catTable': 'Resumo por categoria',
  'sec.beforeDuring': 'Antes × Durante',
  'sec.topSpends': 'Maiores gastos',
  'sec.topBefore': 'Maiores gastos · antes',
  'sec.topDuring': 'Maiores gastos · durante',
  'trip.edit': 'Editar viagem',
  'trip.delete': 'Excluir viagem',
  'trip.deleteConfirm':
    'Excluir esta viagem permanentemente? Todas as transações e categorias dela serão apagadas. Não dá pra desfazer.',
  'city.filter': 'Filtrar por categoria',
  'city.filterPlaceholder': 'todas as categorias',
  'sec.split': 'Você dividiu × sua parte',
  'col.days': 'Dias',
  'col.total': 'Total',
  'col.avgDay': 'Média/dia',
  'col.topCat': 'Top categoria',
  'col.count': 'Nº',
  'col.avgTicket': 'Ticket médio',
  'split.integral': 'Valor integral',
  'split.share': 'Sua parte',
  'split.savings': 'Você economizou',
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
  'city.list': 'Trip cities',
  'city.listPlaceholder': 'add and press Enter',
  'tx.deleteSelected': 'Delete selected',
  'tx.selectedN': 'selected',
  'tx.deleteSelectedConfirm': 'Delete the selected transactions?',

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

  'common.save': 'Save',
  'common.edit': 'Edit',
  'common.delete': 'Delete',
  'tx.new': 'New transaction',
  'tx.edit': 'Edit transaction',
  'tx.deleteConfirm': 'Delete this transaction?',
  'field.type': 'Type',
  'field.split': 'Split by',
  'type.expense': 'Expense',
  'type.refund': 'Refund',
  'type.iof': 'IOF refund',
  'menu.categories': 'Categories',
  'menu.export': 'Export data',
  'menu.import': 'Import data',
  'cat.title': 'Categories',
  'cat.new': 'New category',
  'cat.color': 'Color',
  'cat.emoji': 'Emoji',
  'cat.empty': 'No categories.',
  'cat.deleteConfirm': 'Delete category? Its transactions will be left uncategorized.',
  'backup.exportedOk': 'Backup exported.',
  'backup.importedOk': 'Backup imported successfully.',
  'backup.importError': 'Invalid backup file.',

  'tab.time': 'Time',
  'tab.cities': 'Cities',
  'tab.cats': 'Categories',
  'sec.byDay': 'By day',
  'sec.calendar': 'Calendar',
  'sec.weekday': 'By weekday',
  'sec.catMix': 'Category mix over time',
  'sec.byCity': 'By city',
  'sec.avgCity': 'Average cost per day (by city)',
  'sec.cityTable': 'City summary',
  'sec.catTable': 'Category summary',
  'sec.beforeDuring': 'Before × During',
  'sec.topSpends': 'Top spends',
  'sec.topBefore': 'Top spends · before',
  'sec.topDuring': 'Top spends · during',
  'trip.edit': 'Edit trip',
  'trip.delete': 'Delete trip',
  'trip.deleteConfirm':
    'Delete this trip permanently? All its transactions and categories will be erased. This cannot be undone.',
  'city.filter': 'Filter by category',
  'city.filterPlaceholder': 'all categories',
  'sec.split': 'Shared vs your share',
  'col.days': 'Days',
  'col.total': 'Total',
  'col.avgDay': 'Avg/day',
  'col.topCat': 'Top category',
  'col.count': 'Count',
  'col.avgTicket': 'Avg ticket',
  'split.integral': 'Full value',
  'split.share': 'Your share',
  'split.savings': 'You saved',
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
