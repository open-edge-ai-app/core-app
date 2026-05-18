import AsyncStorage from '@react-native-async-storage/async-storage';
import React, {
  createContext,
  ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';

import { defaultLocale, localeStorageKey, supportedLocales } from './locales';
import type { LocaleCode, SupportedLocale } from './locales';
import { defaultMessages, dictionaries } from './messages';
import type { I18nKey } from './messages';

export { supportedLocales } from './locales';
export type { LocaleCode, SupportedLocale } from './locales';
export type { I18nKey } from './messages';

type I18nContextValue = {
  locale: LocaleCode;
  selectedLocale: SupportedLocale;
  setLocale: (nextLocale: LocaleCode) => void;
  supportedLocales: readonly SupportedLocale[];
  t: (key: I18nKey, values?: Record<string, string | number>) => string;
};

const I18nContext = createContext<I18nContextValue | null>(null);

function isLocaleCode(value: string | null | undefined): value is LocaleCode {
  return supportedLocales.some(locale => locale.code === value);
}

function normalizeLocale(value: string | undefined): LocaleCode | null {
  if (!value) {
    return null;
  }

  if (isLocaleCode(value)) {
    return value;
  }

  const language = value.toLowerCase().split(/[-_]/)[0];

  if (language === 'zh') {
    return 'zh-Hans';
  }

  return supportedLocales.find(locale => locale.code === language)?.code ?? null;
}

function detectLocale(): LocaleCode {
  try {
    return normalizeLocale(Intl.DateTimeFormat().resolvedOptions().locale) ?? defaultLocale;
  } catch {
    return defaultLocale;
  }
}

function interpolate(
  message: string,
  values?: Record<string, string | number>,
) {
  if (!values) {
    return message;
  }

  return Object.entries(values).reduce(
    (result, [key, value]) => result.replaceAll(`{${key}}`, String(value)),
    message,
  );
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<LocaleCode>(detectLocale);

  useEffect(() => {
    let isCancelled = false;

    AsyncStorage.getItem(localeStorageKey)
      .then(storedLocale => {
        if (!isCancelled && isLocaleCode(storedLocale)) {
          setLocaleState(storedLocale);
        }
      })
      .catch(() => undefined);

    return () => {
      isCancelled = true;
    };
  }, []);

  const setLocale = useCallback((nextLocale: LocaleCode) => {
    setLocaleState(nextLocale);
    AsyncStorage.setItem(localeStorageKey, nextLocale).catch(() => undefined);
  }, []);

  const t = useCallback(
    (key: I18nKey, values?: Record<string, string | number>) => {
      const message =
        dictionaries[locale]?.[key] ??
        dictionaries.en?.[key] ??
        defaultMessages[key] ??
        key;
      return interpolate(message, values);
    },
    [locale],
  );

  const selectedLocale = useMemo(
    () =>
      supportedLocales.find(candidate => candidate.code === locale) ??
      supportedLocales[0],
    [locale],
  );

  const value = useMemo<I18nContextValue>(
    () => ({
      locale,
      selectedLocale,
      setLocale,
      supportedLocales,
      t,
    }),
    [locale, selectedLocale, setLocale, t],
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  const context = useContext(I18nContext);

  if (!context) {
    throw new Error('useI18n must be used within I18nProvider.');
  }

  return context;
}
