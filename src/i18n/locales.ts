export const supportedLocales = [
  {
    code: 'ko',
    englishName: 'Korean',
    nativeName: '한국어',
    searchTags: ['korean', 'hangul', '한국어'],
  },
  {
    code: 'en',
    englishName: 'English',
    nativeName: 'English',
    searchTags: ['english'],
  },
  {
    code: 'zh-Hans',
    englishName: 'Chinese (Simplified)',
    nativeName: '简体中文',
    searchTags: ['chinese', 'mandarin', '中文', 'zhongwen'],
  },
  {
    code: 'hi',
    englishName: 'Hindi',
    nativeName: 'हिन्दी',
    searchTags: ['hindi', 'हिंदी'],
  },
  {
    code: 'es',
    englishName: 'Spanish',
    nativeName: 'Español',
    searchTags: ['spanish', 'espanol', 'español'],
  },
  {
    code: 'fr',
    englishName: 'French',
    nativeName: 'Français',
    searchTags: ['french', 'francais', 'français'],
  },
  {
    code: 'ar',
    englishName: 'Arabic',
    nativeName: 'العربية',
    searchTags: ['arabic', 'العربية'],
  },
  {
    code: 'bn',
    englishName: 'Bengali',
    nativeName: 'বাংলা',
    searchTags: ['bengali', 'bangla', 'বাংলা'],
  },
  {
    code: 'ru',
    englishName: 'Russian',
    nativeName: 'Русский',
    searchTags: ['russian', 'русский'],
  },
  {
    code: 'pt',
    englishName: 'Portuguese',
    nativeName: 'Português',
    searchTags: ['portuguese', 'portugues', 'português'],
  },
  {
    code: 'ur',
    englishName: 'Urdu',
    nativeName: 'اردو',
    searchTags: ['urdu', 'اردو'],
  },
  {
    code: 'id',
    englishName: 'Indonesian',
    nativeName: 'Bahasa Indonesia',
    searchTags: ['indonesian', 'bahasa'],
  },
  {
    code: 'de',
    englishName: 'German',
    nativeName: 'Deutsch',
    searchTags: ['german', 'deutsch'],
  },
  {
    code: 'ja',
    englishName: 'Japanese',
    nativeName: '日本語',
    searchTags: ['japanese', 'nihongo', '日本語'],
  },
  {
    code: 'tr',
    englishName: 'Turkish',
    nativeName: 'Türkçe',
    searchTags: ['turkish', 'turkce', 'türkçe'],
  },
] as const;

export type LocaleCode = (typeof supportedLocales)[number]['code'];
export type SupportedLocale = (typeof supportedLocales)[number];

export const defaultLocale: LocaleCode = 'ko';
export const localeStorageKey = 'open-edge-ai:locale';
