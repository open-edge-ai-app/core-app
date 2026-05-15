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
  'settings.supportSection': '지원',
  'settings.appearance': '모양',
  'settings.personalCustomization': '개인 맞춤 설정',
  'settings.embeddingSettings': '임베딩 설정',
  'settings.model': '모델',
  'settings.reportIssue': '문제 신고하기',
  'settings.reportIssueCaption': 'GitHub 이슈로 오류나 제안을 남깁니다.',
  'settings.about': '정보',
  'settings.aboutCaption': '버전, 오픈소스, 기여하기',
  'settings.aboutDescription':
    '앱 정보, 사용 중인 오픈소스, 프로젝트 기여 경로를 확인합니다.',
  'settings.appInformation': '앱 정보',
  'settings.appName': '앱 이름',
  'settings.appVersion': '버전',
  'settings.bundleIdentifier': '번들 ID',
  'settings.repository': '저장소',
  'settings.openSource': '사용 오픈소스',
  'settings.openSourceDescription':
    '앱에서 사용하는 주요 오픈소스 패키지입니다.',
  'settings.contribute': '기여하기',
  'settings.contributeDescription':
    '오픈소스 프로젝트에 참여할 수 있는 경로입니다.',
  'settings.open': '열기',
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
  'settings.namePlaceholder': '예: Alex',
  'settings.personality': '성격',
  'settings.personalityCaption':
    '선택한 성격이 AI 응답 스타일에 적용됩니다.',
  'settings.personalityPlaceholder': '성격을 선택해 주세요.',
  'settings.personality.balanced.label': '균형 잡힌',
  'settings.personality.balanced.description':
    '결론을 먼저 말하고 필요한 근거만 짧게 덧붙입니다.',
  'settings.personality.friendly.label': '친절한',
  'settings.personality.friendly.description':
    '부드럽게 안내하되 과한 표현 없이 다음 행동을 정리합니다.',
  'settings.personality.concise.label': '간결한',
  'settings.personality.concise.description':
    '핵심 답변과 바로 실행할 수 있는 내용만 우선합니다.',
  'settings.personality.analytical.label': '분석적인',
  'settings.personality.analytical.description':
    '근거, 선택지, 불확실성, tradeoff를 구조적으로 표시합니다.',
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
    '앱의 언어와 글씨 크기 같은 표시 방식을 설정합니다.',
  'settings.appearanceCaption': '표시 방식',
  'settings.textSize': '글씨 크기',
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
  'settings.systemManagedModel': '시스템 관리 모델',
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
  'settings.supportSection': 'Support',
  'settings.appearance': 'Appearance',
  'settings.personalCustomization': 'Personalization',
  'settings.embeddingSettings': 'Embedding settings',
  'settings.model': 'Model',
  'settings.reportIssue': 'Report an issue',
  'settings.reportIssueCaption': 'Open a GitHub issue for bugs or ideas.',
  'settings.about': 'About',
  'settings.aboutCaption': 'Version, open source, contributing',
  'settings.aboutDescription':
    'Review app details, open source packages, and ways to contribute.',
  'settings.appInformation': 'App information',
  'settings.appName': 'App name',
  'settings.appVersion': 'Version',
  'settings.bundleIdentifier': 'Bundle ID',
  'settings.repository': 'Repository',
  'settings.openSource': 'Open source',
  'settings.openSourceDescription':
    'Major open source packages used by the app.',
  'settings.contribute': 'Contribute',
  'settings.contributeDescription':
    'Ways to participate in the open source project.',
  'settings.open': 'Open',
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
  'settings.namePlaceholder': 'E.g. Alex',
  'settings.personality': 'Personality',
  'settings.personalityCaption':
    'The selected personality is applied to the AI response style.',
  'settings.personalityPlaceholder': 'Choose a personality.',
  'settings.personality.balanced.label': 'Balanced',
  'settings.personality.balanced.description':
    'Start with the answer, then add only the necessary reasoning.',
  'settings.personality.friendly.label': 'Friendly',
  'settings.personality.friendly.description':
    'Guide softly and organize next actions without extra flourish.',
  'settings.personality.concise.label': 'Concise',
  'settings.personality.concise.description':
    'Prioritize the core answer and immediately actionable details.',
  'settings.personality.analytical.label': 'Analytical',
  'settings.personality.analytical.description':
    'Structure evidence, options, uncertainty, and tradeoffs clearly.',
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
    'Set display preferences such as app language and font size.',
  'settings.appearanceCaption': 'Display preferences',
  'settings.textSize': 'Font size',
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
  'settings.systemManagedModel': 'System-managed model',
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

const localizedPersonalityTranslations: Record<
  Exclude<LocaleCode, 'ko' | 'en'>,
  Partial<Record<I18nKey, string>>
> = {
  'zh-Hans': {
    'settings.personalityCaption': '已选择的性格会应用到 AI 回复风格。',
    'settings.personalityPlaceholder': '选择性格。',
    'settings.personality.balanced.label': '平衡',
    'settings.personality.balanced.description':
      '先给结论，再补充必要理由。',
    'settings.personality.friendly.label': '友好',
    'settings.personality.friendly.description':
      '温和引导，避免多余修饰，并整理下一步。',
    'settings.personality.concise.label': '简洁',
    'settings.personality.concise.description':
      '优先给核心答案和可立即执行的内容。',
    'settings.personality.analytical.label': '分析型',
    'settings.personality.analytical.description':
      '清晰呈现依据、选项、不确定性和权衡。',
  },
  hi: {
    'settings.personalityCaption':
      'चयनित व्यक्तित्व AI उत्तर शैली पर लागू होगा।',
    'settings.personalityPlaceholder': 'व्यक्तित्व चुनें।',
    'settings.personality.balanced.label': 'संतुलित',
    'settings.personality.balanced.description':
      'पहले उत्तर दें, फिर केवल ज़रूरी कारण जोड़ें।',
    'settings.personality.friendly.label': 'मित्रवत',
    'settings.personality.friendly.description':
      'नरम ढंग से मार्गदर्शन करें और अगले कदम साफ करें।',
    'settings.personality.concise.label': 'संक्षिप्त',
    'settings.personality.concise.description':
      'मुख्य उत्तर और तुरंत करने योग्य बातें प्राथमिकता दें।',
    'settings.personality.analytical.label': 'विश्लेषणात्मक',
    'settings.personality.analytical.description':
      'प्रमाण, विकल्प, अनिश्चितता और tradeoff स्पष्ट करें।',
  },
  es: {
    'settings.personalityCaption':
      'La personalidad seleccionada se aplica al estilo de respuesta de la IA.',
    'settings.personalityPlaceholder': 'Elige una personalidad.',
    'settings.personality.balanced.label': 'Equilibrada',
    'settings.personality.balanced.description':
      'Empieza con la respuesta y añade solo la razón necesaria.',
    'settings.personality.friendly.label': 'Amable',
    'settings.personality.friendly.description':
      'Guía con suavidad y organiza los próximos pasos sin exceso.',
    'settings.personality.concise.label': 'Concisa',
    'settings.personality.concise.description':
      'Prioriza la respuesta clave y los detalles accionables.',
    'settings.personality.analytical.label': 'Analítica',
    'settings.personality.analytical.description':
      'Estructura evidencia, opciones, incertidumbre y tradeoffs.',
  },
  fr: {
    'settings.personalityCaption':
      "La personnalité choisie s'applique au style de réponse de l'IA.",
    'settings.personalityPlaceholder': 'Choisissez une personnalité.',
    'settings.personality.balanced.label': 'Équilibrée',
    'settings.personality.balanced.description':
      'Commence par la réponse, puis ajoute seulement le raisonnement utile.',
    'settings.personality.friendly.label': 'Amicale',
    'settings.personality.friendly.description':
      'Guide avec douceur et organise les prochaines étapes sans excès.',
    'settings.personality.concise.label': 'Concise',
    'settings.personality.concise.description':
      'Priorise la réponse clé et les détails directement exploitables.',
    'settings.personality.analytical.label': 'Analytique',
    'settings.personality.analytical.description':
      'Structure les preuves, options, incertitudes et tradeoffs.',
  },
  ar: {
    'settings.personalityCaption':
      'يتم تطبيق الشخصية المختارة على أسلوب رد الذكاء الاصطناعي.',
    'settings.personalityPlaceholder': 'اختر شخصية.',
    'settings.personality.balanced.label': 'متوازن',
    'settings.personality.balanced.description':
      'ابدأ بالإجابة ثم أضف الأسباب الضرورية فقط.',
    'settings.personality.friendly.label': 'ودود',
    'settings.personality.friendly.description':
      'يرشد بلطف وينظم الخطوات التالية دون إسهاب.',
    'settings.personality.concise.label': 'موجز',
    'settings.personality.concise.description':
      'يركز على الإجابة الأساسية وما يمكن تنفيذه فورًا.',
    'settings.personality.analytical.label': 'تحليلي',
    'settings.personality.analytical.description':
      'يعرض الأدلة والخيارات وعدم اليقين والمفاضلات بوضوح.',
  },
  bn: {
    'settings.personalityCaption':
      'নির্বাচিত ব্যক্তিত্ব AI উত্তরের ধরনে প্রয়োগ হবে।',
    'settings.personalityPlaceholder': 'ব্যক্তিত্ব বেছে নিন।',
    'settings.personality.balanced.label': 'ভারসাম্যপূর্ণ',
    'settings.personality.balanced.description':
      'আগে উত্তর দিন, তারপর শুধু দরকারি কারণ যোগ করুন।',
    'settings.personality.friendly.label': 'বন্ধুত্বপূর্ণ',
    'settings.personality.friendly.description':
      'কোমলভাবে পথ দেখায় এবং পরের কাজ সাজায়।',
    'settings.personality.concise.label': 'সংক্ষিপ্ত',
    'settings.personality.concise.description':
      'মূল উত্তর ও এখনই করণীয় বিষয়কে অগ্রাধিকার দেয়।',
    'settings.personality.analytical.label': 'বিশ্লেষণধর্মী',
    'settings.personality.analytical.description':
      'প্রমাণ, বিকল্প, অনিশ্চয়তা ও tradeoff পরিষ্কার করে।',
  },
  ru: {
    'settings.personalityCaption':
      'Выбранный характер применяется к стилю ответов AI.',
    'settings.personalityPlaceholder': 'Выберите характер.',
    'settings.personality.balanced.label': 'Сбалансированный',
    'settings.personality.balanced.description':
      'Сначала ответ, затем только нужные обоснования.',
    'settings.personality.friendly.label': 'Дружелюбный',
    'settings.personality.friendly.description':
      'Мягко направляет и упорядочивает следующие шаги без лишнего.',
    'settings.personality.concise.label': 'Краткий',
    'settings.personality.concise.description':
      'Ставит в приоритет главный ответ и практические детали.',
    'settings.personality.analytical.label': 'Аналитический',
    'settings.personality.analytical.description':
      'Четко структурирует факты, варианты, неопределенность и tradeoff.',
  },
  pt: {
    'settings.personalityCaption':
      'A personalidade selecionada é aplicada ao estilo de resposta da IA.',
    'settings.personalityPlaceholder': 'Escolha uma personalidade.',
    'settings.personality.balanced.label': 'Equilibrada',
    'settings.personality.balanced.description':
      'Começa pela resposta e adiciona só o raciocínio necessário.',
    'settings.personality.friendly.label': 'Amigável',
    'settings.personality.friendly.description':
      'Orienta com suavidade e organiza próximos passos sem excesso.',
    'settings.personality.concise.label': 'Concisa',
    'settings.personality.concise.description':
      'Prioriza a resposta principal e detalhes acionáveis.',
    'settings.personality.analytical.label': 'Analítica',
    'settings.personality.analytical.description':
      'Estrutura evidências, opções, incertezas e tradeoffs.',
  },
  ur: {
    'settings.personalityCaption':
      'منتخب شخصیت AI کے جواب کے انداز پر لاگو ہوگی۔',
    'settings.personalityPlaceholder': 'شخصیت منتخب کریں۔',
    'settings.personality.balanced.label': 'متوازن',
    'settings.personality.balanced.description':
      'پہلے جواب دیں، پھر صرف ضروری وجہ شامل کریں۔',
    'settings.personality.friendly.label': 'دوستانہ',
    'settings.personality.friendly.description':
      'نرمی سے رہنمائی کرے اور اگلے اقدامات واضح کرے۔',
    'settings.personality.concise.label': 'مختصر',
    'settings.personality.concise.description':
      'اصل جواب اور فوری قابل عمل نکات کو ترجیح دے۔',
    'settings.personality.analytical.label': 'تجزیاتی',
    'settings.personality.analytical.description':
      'ثبوت، اختیارات، غیر یقینی صورتحال اور tradeoff واضح کرے۔',
  },
  id: {
    'settings.personalityCaption':
      'Kepribadian yang dipilih diterapkan pada gaya respons AI.',
    'settings.personalityPlaceholder': 'Pilih kepribadian.',
    'settings.personality.balanced.label': 'Seimbang',
    'settings.personality.balanced.description':
      'Mulai dengan jawaban, lalu tambahkan alasan yang diperlukan saja.',
    'settings.personality.friendly.label': 'Ramah',
    'settings.personality.friendly.description':
      'Memandu dengan lembut dan merapikan langkah berikutnya.',
    'settings.personality.concise.label': 'Ringkas',
    'settings.personality.concise.description':
      'Utamakan jawaban inti dan detail yang langsung bisa dilakukan.',
    'settings.personality.analytical.label': 'Analitis',
    'settings.personality.analytical.description':
      'Menyusun bukti, opsi, ketidakpastian, dan tradeoff dengan jelas.',
  },
  de: {
    'settings.personalityCaption':
      'Die ausgewählte Persönlichkeit wird auf den Antwortstil der KI angewendet.',
    'settings.personalityPlaceholder': 'Persönlichkeit auswählen.',
    'settings.personality.balanced.label': 'Ausgewogen',
    'settings.personality.balanced.description':
      'Beginnt mit der Antwort und ergänzt nur nötige Begründungen.',
    'settings.personality.friendly.label': 'Freundlich',
    'settings.personality.friendly.description':
      'Führt sanft und ordnet nächste Schritte ohne Ausschweifen.',
    'settings.personality.concise.label': 'Knapp',
    'settings.personality.concise.description':
      'Priorisiert die Kernaussage und direkt umsetzbare Details.',
    'settings.personality.analytical.label': 'Analytisch',
    'settings.personality.analytical.description':
      'Strukturiert Belege, Optionen, Unsicherheit und tradeoffs klar.',
  },
  ja: {
    'settings.personalityCaption':
      '選択した性格がAIの回答スタイルに適用されます。',
    'settings.personalityPlaceholder': '性格を選択してください。',
    'settings.personality.balanced.label': 'バランス型',
    'settings.personality.balanced.description':
      '先に答えを示し、必要な理由だけを短く添えます。',
    'settings.personality.friendly.label': '親切',
    'settings.personality.friendly.description':
      'やわらかく案内し、次の行動を整理します。',
    'settings.personality.concise.label': '簡潔',
    'settings.personality.concise.description':
      '核心の答えとすぐ実行できる内容を優先します。',
    'settings.personality.analytical.label': '分析的',
    'settings.personality.analytical.description':
      '根拠、選択肢、不確実性、tradeoffを明確に整理します。',
  },
  tr: {
    'settings.personalityCaption':
      'Seçilen kişilik AI yanıt stiline uygulanır.',
    'settings.personalityPlaceholder': 'Bir kişilik seçin.',
    'settings.personality.balanced.label': 'Dengeli',
    'settings.personality.balanced.description':
      'Önce yanıtı verir, sonra yalnızca gerekli gerekçeyi ekler.',
    'settings.personality.friendly.label': 'Sıcak',
    'settings.personality.friendly.description':
      'Nazikçe yönlendirir ve sonraki adımları sade biçimde düzenler.',
    'settings.personality.concise.label': 'Kısa',
    'settings.personality.concise.description':
      'Temel yanıtı ve hemen uygulanabilir ayrıntıları öne çıkarır.',
    'settings.personality.analytical.label': 'Analitik',
    'settings.personality.analytical.description':
      'Kanıtları, seçenekleri, belirsizliği ve tradeoffları net düzenler.',
  },
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
  ...(Object.fromEntries(
    Object.entries(compactTranslations).map(([locale, messages]) => [
      locale,
      {
        ...messages,
        ...localizedPersonalityTranslations[
          locale as Exclude<LocaleCode, 'ko' | 'en'>
        ],
      },
    ]),
  ) as Record<
    Exclude<LocaleCode, 'ko' | 'en'>,
    Partial<Record<I18nKey, string>>
  >),
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
