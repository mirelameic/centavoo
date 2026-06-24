// Public entry point for the app's i18n. Importing this also initializes
// i18next (side effect of ./config), so it must be imported once at startup.
export { useI18n } from './useI18n';
export { LANGUAGES, localeOf, type Lang } from './config';
export { default as i18n } from './config';
