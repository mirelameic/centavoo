import i18next from 'i18next';
import { initReactI18next } from 'react-i18next';
import { pt } from './locales/pt';
import { en } from './locales/en';

export const LANGUAGES = [
  { code: 'pt', label: 'PT', locale: 'pt-BR', dict: pt },
  { code: 'en', label: 'EN', locale: 'en-US', dict: en },
] as const;

export type Lang = (typeof LANGUAGES)[number]['code'];

const STORAGE_KEY = 'lang';
const FALLBACK: Lang = 'pt';

export const localeOf = (code: string): string =>
  LANGUAGES.find((l) => l.code === code)?.locale ?? LANGUAGES[0].locale;

const stored = localStorage.getItem(STORAGE_KEY);
const initialLng = LANGUAGES.some((l) => l.code === stored) ? (stored as Lang) : FALLBACK;

i18next.use(initReactI18next).init({
  resources: Object.fromEntries(LANGUAGES.map((l) => [l.code, { translation: l.dict }])),
  lng: initialLng,
  fallbackLng: FALLBACK,
  keySeparator: false,
  nsSeparator: false,
  interpolation: { escapeValue: false },
});

export { STORAGE_KEY };
export default i18next;
