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

const defaultLocale: LocaleCode = 'ko';
const localeStorageKey = 'open-edge-ai:locale';

const defaultMessages = {
  'common.search': '검색',
  'common.select': '선택',
  'common.noResults': '검색 결과 없음',
  'chat.addToQueue': '대기열에 메시지 추가',
  'chat.analyzeAttachedFile': '첨부한 파일을 분석해줘',
  'chat.attachFile': '파일 첨부',
  'chat.attachmentFailed': '파일 첨부 실패: {message}',
  'chat.attachmentPrefix': '첨부: {summary}',
  'chat.defaultAttachment': '첨부 파일',
  'chat.filePickFailed': '파일을 선택하지 못했습니다.',
  'chat.heroBody': '로컬 AI가 빠르고 안전하게 답변해드려요.',
  'chat.heroTitle': '무엇이든 물어보세요',
  'chat.inputPlaceholder': '무엇이든 묻거나 검색하고 만들어보세요...',
  'chat.loadingResponse': '{model} 응답 준비 중',
  'chat.messageCount': '{count}개 메시지',
  'chat.modeChat': '채팅',
  'chat.modeFiles': '파일',
  'chat.modeReason': '분석',
  'chat.modeSearch': '검색',
  'chat.newChat': '새 채팅',
  'chat.queueCancel': '취소',
  'chat.queueCount': '{count}개 대기 중',
  'chat.queueDelete': '대기 메시지 삭제',
  'chat.queueEdit': '대기 메시지 수정',
  'chat.queueEditCancel': '대기 메시지 수정 취소',
  'chat.queueEditPlaceholder': '대기 중인 메시지 수정',
  'chat.queueSave': '저장',
  'chat.queueSaveAction': '대기 메시지 저장',
  'chat.queueTitle': '대기열',
  'chat.removeAttachment': '{name} 제거',
  'chat.responseFailed': '응답 실패: {message}',
  'chat.retrying': '다시 생성 중...',
  'chat.scrollToBottom': '최신 메시지로 이동',
  'chat.sendMessage': '메시지 보내기',
  'chat.stopResponse': 'AI 응답 중단',
  'chat.threadTitle': '대화',
  'chat.unknownResponseError':
    'AI 응답 처리 중 알 수 없는 문제가 발생했습니다.',
  'settings.title': '설정',
  'settings.customizationSection': '맞춤 설정',
  'settings.aiSection': 'AI',
  'settings.appearance': '모양',
  'settings.personalCustomization': '개인 맞춤 설정',
  'settings.embeddingSettings': '임베딩 설정',
  'settings.model': '모델',
  'settings.loaded': '로드됨',
  'settings.installed': '설치됨',
  'settings.downloading': '다운로드 중',
  'settings.installNeeded': '설치 필요',
  'settings.waiting': '대기 중',
  'settings.connected': '연결됨',
  'settings.off': '꺼짐',
  'settings.required': '필요함',
  'settings.loading': '로드 중',
  'settings.noRecord': '기록 없음',
  'settings.language': '언어',
  'settings.languageCaption': '앱 표시 언어',
  'settings.languageSearchPlaceholder': '언어 검색',
  'settings.languageNoResults': '일치하는 언어가 없습니다.',
  'settings.personalCustomizationDescription':
    'AI가 사용자를 이해하고 응답 방식을 맞출 수 있도록 기본 정보를 관리합니다.',
  'settings.personalCustomizationCaption': '이름, 성격, 지침, 메모리',
  'settings.memoryOn': '메모리 켜짐',
  'settings.memoryOff': '메모리 꺼짐',
  'settings.name': '이름',
  'settings.namePlaceholder': '예: Minjun',
  'settings.personality': '성격',
  'settings.personalityPlaceholder':
    '예: 차분하고 직접적이며, 필요한 경우 근거를 짧게 설명해줘.',
  'settings.customInstructions': '맞춤형 지침',
  'settings.customInstructionsPlaceholder':
    '예: 항상 한국어로 간결하게 답하고, 모호한 요청은 필요한 가정을 먼저 밝혀줘.',
  'settings.memoryEnabled': '메모리 활성',
  'settings.memoryEnabledDescription':
    '채팅 기록에서 기억을 생성하고 이후 응답에 반영합니다.',
  'settings.savedMemoryList': '저장된 메모리 리스트',
  'settings.savedMemoryEmpty':
    '채팅 기록에서 생성된 메모리가 여기에 표시됩니다.',
  'settings.appearanceDescription':
    '앱에서 반복적으로 보는 텍스트의 표시 크기를 설정합니다.',
  'settings.appearanceCaption': '언어 및 텍스트 크기',
  'settings.textSize': '텍스트 크기',
  'settings.textSize.compact.label': '작게',
  'settings.textSize.compact.description': '한 화면에 더 많은 내용을 보여줘요.',
  'settings.textSize.default.label': '기본',
  'settings.textSize.default.description':
    'iPhone 기본에 가까운 균형 잡힌 크기예요.',
  'settings.textSize.large.label': '크게',
  'settings.textSize.large.description': '읽기 편한 큰 글씨로 보여줘요.',
  'settings.modelDescription':
    '온디바이스 모델 파일과 런타임 연결 상태를 관리합니다.',
  'settings.engineStatus': '엔진 연결 상태',
  'settings.nativeBridge': 'Native bridge',
  'settings.defaultModel': '기본 모델',
  'settings.modelFile': '모델 파일',
  'settings.download': '다운로드',
  'settings.downloadModel': '모델 다운로드',
  'settings.cancel': '취소',
  'settings.runtime': '런타임',
  'settings.loadModel': '모델 켜기',
  'settings.unloadModel': '모델 끄기',
  'settings.embeddingDescription':
    '검색과 개인 메모리에 사용할 소스별 임베딩을 관리합니다.',
  'settings.embeddingCaption': '소스별 임베딩 생성/삭제',
  'settings.itemCount': '{count}개',
  'settings.embeddingItems': '임베딩 항목',
  'settings.smsEmbedding': 'SMS 임베딩',
  'settings.galleryEmbedding': '갤러리 임베딩',
  'settings.documentEmbedding': '문서 임베딩',
  'settings.lastEmbedding': '마지막 임베딩 생성',
  'settings.sms': 'SMS',
  'settings.gallery': '갤러리',
  'settings.documents': '문서',
  'settings.smsEmbeddingCaption': '문자 임베딩',
  'settings.galleryEmbeddingCaption': '사진 임베딩',
  'settings.documentEmbeddingCaption': '다운로드/공유 문서 임베딩',
  'settings.embeddingHelp':
    '백그라운드 작업과 권한 상태는 네이티브 엔진 연결에 맞춰 갱신됩니다.',
  'settings.startEmbedding': 'SMS/갤러리/문서 임베딩 생성',
  'settings.deleteSmsEmbedding': 'SMS 임베딩 삭제',
  'settings.deleteGalleryEmbedding': '갤러리 임베딩 삭제',
  'settings.deleteDocumentEmbedding': '문서 임베딩 삭제',
  'settings.refreshStatus': '상태 새로고침',
};

export type I18nKey = keyof typeof defaultMessages;

const en: Record<I18nKey, string> = {
  'common.search': 'Search',
  'common.select': 'Select',
  'common.noResults': 'No results',
  'chat.addToQueue': 'Add message to queue',
  'chat.analyzeAttachedFile': 'Analyze the attached file',
  'chat.attachFile': 'Attach file',
  'chat.attachmentFailed': 'File attachment failed: {message}',
  'chat.attachmentPrefix': 'Attachment: {summary}',
  'chat.defaultAttachment': 'Attachment',
  'chat.filePickFailed': 'Could not choose a file.',
  'chat.heroBody': 'Local AI answers quickly and safely.',
  'chat.heroTitle': 'Ask anything',
  'chat.inputPlaceholder': 'Ask, search, or make anything...',
  'chat.loadingResponse': '{model} is preparing a response',
  'chat.messageCount': '{count} messages',
  'chat.modeChat': 'Chat',
  'chat.modeFiles': 'Files',
  'chat.modeReason': 'Analyze',
  'chat.modeSearch': 'Search',
  'chat.newChat': 'New chat',
  'chat.queueCancel': 'Cancel',
  'chat.queueCount': '{count} queued',
  'chat.queueDelete': 'Delete queued message',
  'chat.queueEdit': 'Edit queued message',
  'chat.queueEditCancel': 'Cancel queued message edit',
  'chat.queueEditPlaceholder': 'Edit queued message',
  'chat.queueSave': 'Save',
  'chat.queueSaveAction': 'Save queued message',
  'chat.queueTitle': 'Queue',
  'chat.removeAttachment': 'Remove {name}',
  'chat.responseFailed': 'Response failed: {message}',
  'chat.retrying': 'Regenerating...',
  'chat.scrollToBottom': 'Go to latest message',
  'chat.sendMessage': 'Send message',
  'chat.stopResponse': 'Stop AI response',
  'chat.threadTitle': 'Conversation',
  'chat.unknownResponseError':
    'An unknown error occurred while processing the AI response.',
  'settings.title': 'Settings',
  'settings.customizationSection': 'Customization',
  'settings.aiSection': 'AI',
  'settings.appearance': 'Appearance',
  'settings.personalCustomization': 'Personalization',
  'settings.embeddingSettings': 'Embedding settings',
  'settings.model': 'Model',
  'settings.loaded': 'Loaded',
  'settings.installed': 'Installed',
  'settings.downloading': 'Downloading',
  'settings.installNeeded': 'Install needed',
  'settings.waiting': 'Waiting',
  'settings.connected': 'Connected',
  'settings.off': 'Off',
  'settings.required': 'Required',
  'settings.loading': 'Loading',
  'settings.noRecord': 'No record',
  'settings.language': 'Language',
  'settings.languageCaption': 'App display language',
  'settings.languageSearchPlaceholder': 'Search languages',
  'settings.languageNoResults': 'No matching language.',
  'settings.personalCustomizationDescription':
    'Manage the profile AI uses to understand you and tailor responses.',
  'settings.personalCustomizationCaption': 'Name, tone, instructions, memory',
  'settings.memoryOn': 'Memory on',
  'settings.memoryOff': 'Memory off',
  'settings.name': 'Name',
  'settings.namePlaceholder': 'E.g. Minjun',
  'settings.personality': 'Personality',
  'settings.personalityPlaceholder':
    'E.g. Calm and direct, with brief reasoning when needed.',
  'settings.customInstructions': 'Custom instructions',
  'settings.customInstructionsPlaceholder':
    'E.g. Reply concisely in Korean and state assumptions when a request is unclear.',
  'settings.memoryEnabled': 'Memory enabled',
  'settings.memoryEnabledDescription':
    'Create memories from chat history and use them in later responses.',
  'settings.savedMemoryList': 'Saved memories',
  'settings.savedMemoryEmpty':
    'Memories created from chat history will appear here.',
  'settings.appearanceDescription':
    'Set the display size for text you see repeatedly in the app.',
  'settings.appearanceCaption': 'Language and text size',
  'settings.textSize': 'Text size',
  'settings.textSize.compact.label': 'Compact',
  'settings.textSize.compact.description': 'Show more content on one screen.',
  'settings.textSize.default.label': 'Default',
  'settings.textSize.default.description':
    'Balanced size close to the iPhone default.',
  'settings.textSize.large.label': 'Large',
  'settings.textSize.large.description': 'Larger text for easier reading.',
  'settings.modelDescription':
    'Manage on-device model files and runtime connection status.',
  'settings.engineStatus': 'Engine status',
  'settings.nativeBridge': 'Native bridge',
  'settings.defaultModel': 'Default model',
  'settings.modelFile': 'Model file',
  'settings.download': 'Download',
  'settings.downloadModel': 'Download model',
  'settings.cancel': 'Cancel',
  'settings.runtime': 'Runtime',
  'settings.loadModel': 'Load model',
  'settings.unloadModel': 'Unload model',
  'settings.embeddingDescription':
    'Manage source embeddings for search and personal memory.',
  'settings.embeddingCaption': 'Create/delete embeddings by source',
  'settings.itemCount': '{count} items',
  'settings.embeddingItems': 'Embedding items',
  'settings.smsEmbedding': 'SMS embeddings',
  'settings.galleryEmbedding': 'Gallery embeddings',
  'settings.documentEmbedding': 'Document embeddings',
  'settings.lastEmbedding': 'Last embedding',
  'settings.sms': 'SMS',
  'settings.gallery': 'Gallery',
  'settings.documents': 'Documents',
  'settings.smsEmbeddingCaption': 'Text message embeddings',
  'settings.galleryEmbeddingCaption': 'Photo embeddings',
  'settings.documentEmbeddingCaption': 'Downloaded/shared document embeddings',
  'settings.embeddingHelp':
    'Background jobs and permission state update with the native engine.',
  'settings.startEmbedding': 'Create SMS/Gallery/Document embeddings',
  'settings.deleteSmsEmbedding': 'Delete SMS embeddings',
  'settings.deleteGalleryEmbedding': 'Delete gallery embeddings',
  'settings.deleteDocumentEmbedding': 'Delete document embeddings',
  'settings.refreshStatus': 'Refresh status',
};

const compactTranslations: Record<
  Exclude<LocaleCode, 'ko' | 'en'>,
  Partial<Record<I18nKey, string>>
> = {
  'zh-Hans': {
    'common.search': '搜索',
    'common.select': '选择',
    'common.noResults': '无结果',
    'settings.title': '设置',
    'settings.customizationSection': '自定义',
    'settings.aiSection': 'AI',
    'settings.appearance': '外观',
    'settings.personalCustomization': '个人定制',
    'settings.embeddingSettings': '嵌入设置',
    'settings.model': '模型',
    'settings.language': '语言',
    'settings.languageCaption': '应用显示语言',
    'settings.languageSearchPlaceholder': '搜索语言',
    'settings.languageNoResults': '没有匹配的语言。',
    'settings.name': '名称',
    'settings.personality': '性格',
    'settings.customInstructions': '自定义指令',
    'settings.memoryEnabled': '启用记忆',
    'settings.savedMemoryList': '已保存记忆',
    'settings.textSize': '文字大小',
  },
  hi: {
    'common.search': 'खोजें',
    'common.select': 'चुनें',
    'common.noResults': 'कोई परिणाम नहीं',
    'settings.title': 'सेटिंग्स',
    'settings.customizationSection': 'अनुकूलन',
    'settings.aiSection': 'AI',
    'settings.appearance': 'रूप',
    'settings.personalCustomization': 'व्यक्तिगत अनुकूलन',
    'settings.embeddingSettings': 'एम्बेडिंग सेटिंग्स',
    'settings.model': 'मॉडल',
    'settings.language': 'भाषा',
    'settings.languageCaption': 'ऐप की भाषा',
    'settings.languageSearchPlaceholder': 'भाषा खोजें',
    'settings.languageNoResults': 'मिलती-जुलती भाषा नहीं मिली।',
    'settings.name': 'नाम',
    'settings.personality': 'व्यक्तित्व',
    'settings.customInstructions': 'कस्टम निर्देश',
    'settings.memoryEnabled': 'मेमोरी सक्षम',
    'settings.savedMemoryList': 'सहेजी गई मेमोरी',
    'settings.textSize': 'टेक्स्ट आकार',
  },
  es: {
    'common.search': 'Buscar',
    'common.select': 'Seleccionar',
    'common.noResults': 'Sin resultados',
    'settings.title': 'Ajustes',
    'settings.customizationSection': 'Personalización',
    'settings.aiSection': 'IA',
    'settings.appearance': 'Apariencia',
    'settings.personalCustomization': 'Personalización',
    'settings.embeddingSettings': 'Ajustes de embeddings',
    'settings.model': 'Modelo',
    'settings.language': 'Idioma',
    'settings.languageCaption': 'Idioma de la app',
    'settings.languageSearchPlaceholder': 'Buscar idiomas',
    'settings.languageNoResults': 'No hay idiomas coincidentes.',
    'settings.name': 'Nombre',
    'settings.personality': 'Personalidad',
    'settings.customInstructions': 'Instrucciones personalizadas',
    'settings.memoryEnabled': 'Memoria activada',
    'settings.savedMemoryList': 'Memorias guardadas',
    'settings.textSize': 'Tamaño del texto',
  },
  fr: {
    'common.search': 'Rechercher',
    'common.select': 'Sélectionner',
    'common.noResults': 'Aucun résultat',
    'settings.title': 'Réglages',
    'settings.customizationSection': 'Personnalisation',
    'settings.aiSection': 'IA',
    'settings.appearance': 'Apparence',
    'settings.personalCustomization': 'Personnalisation',
    'settings.embeddingSettings': 'Réglages des embeddings',
    'settings.model': 'Modèle',
    'settings.language': 'Langue',
    'settings.languageCaption': "Langue d'affichage",
    'settings.languageSearchPlaceholder': 'Rechercher une langue',
    'settings.languageNoResults': 'Aucune langue correspondante.',
    'settings.name': 'Nom',
    'settings.personality': 'Personnalité',
    'settings.customInstructions': 'Instructions personnalisées',
    'settings.memoryEnabled': 'Mémoire activée',
    'settings.savedMemoryList': 'Mémoires enregistrées',
    'settings.textSize': 'Taille du texte',
  },
  ar: {
    'common.search': 'بحث',
    'common.select': 'اختيار',
    'common.noResults': 'لا نتائج',
    'settings.title': 'الإعدادات',
    'settings.customizationSection': 'التخصيص',
    'settings.aiSection': 'الذكاء الاصطناعي',
    'settings.appearance': 'المظهر',
    'settings.personalCustomization': 'التخصيص الشخصي',
    'settings.embeddingSettings': 'إعدادات التضمين',
    'settings.model': 'النموذج',
    'settings.language': 'اللغة',
    'settings.languageCaption': 'لغة عرض التطبيق',
    'settings.languageSearchPlaceholder': 'ابحث عن لغة',
    'settings.languageNoResults': 'لا توجد لغة مطابقة.',
    'settings.name': 'الاسم',
    'settings.personality': 'الشخصية',
    'settings.customInstructions': 'تعليمات مخصصة',
    'settings.memoryEnabled': 'تفعيل الذاكرة',
    'settings.savedMemoryList': 'الذكريات المحفوظة',
    'settings.textSize': 'حجم النص',
  },
  bn: {
    'common.search': 'অনুসন্ধান',
    'common.select': 'নির্বাচন',
    'common.noResults': 'কোনো ফল নেই',
    'settings.title': 'সেটিংস',
    'settings.customizationSection': 'কাস্টমাইজেশন',
    'settings.aiSection': 'AI',
    'settings.appearance': 'রূপ',
    'settings.personalCustomization': 'ব্যক্তিগত কাস্টমাইজেশন',
    'settings.embeddingSettings': 'এম্বেডিং সেটিংস',
    'settings.model': 'মডেল',
    'settings.language': 'ভাষা',
    'settings.languageCaption': 'অ্যাপের ভাষা',
    'settings.languageSearchPlaceholder': 'ভাষা খুঁজুন',
    'settings.languageNoResults': 'মিল থাকা ভাষা নেই।',
    'settings.name': 'নাম',
    'settings.personality': 'ব্যক্তিত্ব',
    'settings.customInstructions': 'কাস্টম নির্দেশনা',
    'settings.memoryEnabled': 'মেমরি চালু',
    'settings.savedMemoryList': 'সংরক্ষিত মেমরি',
    'settings.textSize': 'টেক্সটের আকার',
  },
  ru: {
    'common.search': 'Поиск',
    'common.select': 'Выбрать',
    'common.noResults': 'Нет результатов',
    'settings.title': 'Настройки',
    'settings.customizationSection': 'Настройка',
    'settings.aiSection': 'AI',
    'settings.appearance': 'Внешний вид',
    'settings.personalCustomization': 'Персонализация',
    'settings.embeddingSettings': 'Настройки эмбеддингов',
    'settings.model': 'Модель',
    'settings.language': 'Язык',
    'settings.languageCaption': 'Язык интерфейса',
    'settings.languageSearchPlaceholder': 'Поиск языка',
    'settings.languageNoResults': 'Подходящий язык не найден.',
    'settings.name': 'Имя',
    'settings.personality': 'Характер',
    'settings.customInstructions': 'Пользовательские инструкции',
    'settings.memoryEnabled': 'Память включена',
    'settings.savedMemoryList': 'Сохраненная память',
    'settings.textSize': 'Размер текста',
  },
  pt: {
    'common.search': 'Pesquisar',
    'common.select': 'Selecionar',
    'common.noResults': 'Sem resultados',
    'settings.title': 'Configurações',
    'settings.customizationSection': 'Personalização',
    'settings.aiSection': 'IA',
    'settings.appearance': 'Aparência',
    'settings.personalCustomization': 'Personalização',
    'settings.embeddingSettings': 'Configurações de embeddings',
    'settings.model': 'Modelo',
    'settings.language': 'Idioma',
    'settings.languageCaption': 'Idioma do app',
    'settings.languageSearchPlaceholder': 'Pesquisar idiomas',
    'settings.languageNoResults': 'Nenhum idioma correspondente.',
    'settings.name': 'Nome',
    'settings.personality': 'Personalidade',
    'settings.customInstructions': 'Instruções personalizadas',
    'settings.memoryEnabled': 'Memória ativada',
    'settings.savedMemoryList': 'Memórias salvas',
    'settings.textSize': 'Tamanho do texto',
  },
  ur: {
    'common.search': 'تلاش',
    'common.select': 'منتخب کریں',
    'common.noResults': 'کوئی نتیجہ نہیں',
    'settings.title': 'ترتیبات',
    'settings.customizationSection': 'تخصیص',
    'settings.aiSection': 'AI',
    'settings.appearance': 'ظاہری شکل',
    'settings.personalCustomization': 'ذاتی تخصیص',
    'settings.embeddingSettings': 'ایمبیڈنگ ترتیبات',
    'settings.model': 'ماڈل',
    'settings.language': 'زبان',
    'settings.languageCaption': 'ایپ کی زبان',
    'settings.languageSearchPlaceholder': 'زبان تلاش کریں',
    'settings.languageNoResults': 'کوئی مماثل زبان نہیں۔',
    'settings.name': 'نام',
    'settings.personality': 'شخصیت',
    'settings.customInstructions': 'حسب ضرورت ہدایات',
    'settings.memoryEnabled': 'میموری فعال',
    'settings.savedMemoryList': 'محفوظ یادداشتیں',
    'settings.textSize': 'متن کا سائز',
  },
  id: {
    'common.search': 'Cari',
    'common.select': 'Pilih',
    'common.noResults': 'Tidak ada hasil',
    'settings.title': 'Pengaturan',
    'settings.customizationSection': 'Kustomisasi',
    'settings.aiSection': 'AI',
    'settings.appearance': 'Tampilan',
    'settings.personalCustomization': 'Personalisasi',
    'settings.embeddingSettings': 'Pengaturan embedding',
    'settings.model': 'Model',
    'settings.language': 'Bahasa',
    'settings.languageCaption': 'Bahasa tampilan aplikasi',
    'settings.languageSearchPlaceholder': 'Cari bahasa',
    'settings.languageNoResults': 'Tidak ada bahasa yang cocok.',
    'settings.name': 'Nama',
    'settings.personality': 'Kepribadian',
    'settings.customInstructions': 'Instruksi kustom',
    'settings.memoryEnabled': 'Memori aktif',
    'settings.savedMemoryList': 'Memori tersimpan',
    'settings.textSize': 'Ukuran teks',
  },
  de: {
    'common.search': 'Suchen',
    'common.select': 'Auswählen',
    'common.noResults': 'Keine Ergebnisse',
    'settings.title': 'Einstellungen',
    'settings.customizationSection': 'Anpassung',
    'settings.aiSection': 'KI',
    'settings.appearance': 'Darstellung',
    'settings.personalCustomization': 'Personalisierung',
    'settings.embeddingSettings': 'Embedding-Einstellungen',
    'settings.model': 'Modell',
    'settings.language': 'Sprache',
    'settings.languageCaption': 'Anzeigesprache der App',
    'settings.languageSearchPlaceholder': 'Sprachen suchen',
    'settings.languageNoResults': 'Keine passende Sprache.',
    'settings.name': 'Name',
    'settings.personality': 'Persönlichkeit',
    'settings.customInstructions': 'Benutzerdefinierte Anweisungen',
    'settings.memoryEnabled': 'Speicher aktiviert',
    'settings.savedMemoryList': 'Gespeicherte Erinnerungen',
    'settings.textSize': 'Textgröße',
  },
  ja: {
    'common.search': '検索',
    'common.select': '選択',
    'common.noResults': '結果なし',
    'settings.title': '設定',
    'settings.customizationSection': 'カスタマイズ',
    'settings.aiSection': 'AI',
    'settings.appearance': '外観',
    'settings.personalCustomization': 'パーソナライズ',
    'settings.embeddingSettings': '埋め込み設定',
    'settings.model': 'モデル',
    'settings.language': '言語',
    'settings.languageCaption': 'アプリの表示言語',
    'settings.languageSearchPlaceholder': '言語を検索',
    'settings.languageNoResults': '一致する言語がありません。',
    'settings.name': '名前',
    'settings.personality': '性格',
    'settings.customInstructions': 'カスタム指示',
    'settings.memoryEnabled': 'メモリ有効',
    'settings.savedMemoryList': '保存済みメモリ',
    'settings.textSize': '文字サイズ',
  },
  tr: {
    'common.search': 'Ara',
    'common.select': 'Seç',
    'common.noResults': 'Sonuç yok',
    'settings.title': 'Ayarlar',
    'settings.customizationSection': 'Özelleştirme',
    'settings.aiSection': 'AI',
    'settings.appearance': 'Görünüm',
    'settings.personalCustomization': 'Kişiselleştirme',
    'settings.embeddingSettings': 'Gömme ayarları',
    'settings.model': 'Model',
    'settings.language': 'Dil',
    'settings.languageCaption': 'Uygulama dili',
    'settings.languageSearchPlaceholder': 'Dil ara',
    'settings.languageNoResults': 'Eşleşen dil yok.',
    'settings.name': 'Ad',
    'settings.personality': 'Kişilik',
    'settings.customInstructions': 'Özel talimatlar',
    'settings.memoryEnabled': 'Bellek açık',
    'settings.savedMemoryList': 'Kayıtlı anılar',
    'settings.textSize': 'Metin boyutu',
  },
};

const dictionaries: Record<LocaleCode, Partial<Record<I18nKey, string>>> = {
  ko: defaultMessages,
  en,
  ...compactTranslations,
};

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
        dictionaries[locale]?.[key] ?? en[key] ?? defaultMessages[key] ?? key;
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
