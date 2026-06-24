import { useTranslation } from 'react-i18next';
import { money as fmtMoney, fmtDate } from '../lib/format';
import { localeOf, STORAGE_KEY, type Lang } from './config';

// Thin wrapper over react-i18next that also exposes locale-aware money/date
// formatters, so the rest of the app keeps a single i18n entry point.
export function useI18n() {
  const { t, i18n } = useTranslation();
  const lang = i18n.language as Lang;
  const locale = localeOf(lang);
  return {
    t: (key: string) => t(key),
    lang,
    setLang: (l: Lang) => {
      localStorage.setItem(STORAGE_KEY, l);
      void i18n.changeLanguage(l);
    },
    locale,
    money: (n: number, currency = 'BRL') => fmtMoney(n, currency, locale),
    date: (d?: string | null) => fmtDate(d, locale),
  };
}
