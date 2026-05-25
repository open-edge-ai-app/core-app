import Foundation

extension NativeI18n {
  static let localizedMessages: [NativeLanguage: [NativeI18nKey: String]] = {
    var messages: [NativeLanguage: [NativeI18nKey: String]] = [
      .korean: koreanMessages,
      .english: englishMessages,
      .simplifiedChinese: compactChineseMessages,
      .hindi: compactHindiMessages,
      .spanish: compactSpanishMessages,
      .french: compactFrenchMessages,
      .arabic: compactArabicMessages,
      .bengali: compactBengaliMessages,
      .russian: compactRussianMessages,
      .portuguese: compactPortugueseMessages,
      .urdu: compactUrduMessages,
      .indonesian: compactIndonesianMessages,
      .german: compactGermanMessages,
      .japanese: compactJapaneseMessages,
      .turkish: compactTurkishMessages
    ]
    return messages
  }()





  static let compactChineseMessages = compactMessages(
    settings: ["一般", "模型", "个性化", "外观", "信息", "语言"],
    todo: ["列表", "日历", "逾期", "今天", "任务", "昨天", "明天", "无标签"],
    actions: ["完成", "取消", "保存"]
  )
  static let compactHindiMessages = compactMessages(
    settings: ["सामान्य", "मॉडल", "व्यक्तिकरण", "दिखावट", "जानकारी", "भाषा"],
    todo: ["सूची", "कैलेंडर", "अतिदेय", "आज", "कार्य", "बीता कल", "कल", "कोई टैग नहीं"],
    actions: ["पूर्ण", "रद्द", "सहेजें"]
  )
  static let compactSpanishMessages = compactMessages(
    settings: ["General", "Modelo", "Personalización", "Apariencia", "Información", "Idioma"],
    todo: ["Lista", "Calendario", "Atrasado", "Hoy", "Tareas", "Ayer", "Mañana", "Sin etiqueta"],
    actions: ["Listo", "Cancelar", "Guardar"]
  )
  static let compactFrenchMessages = compactMessages(
    settings: ["Général", "Modèle", "Personnalisation", "Apparence", "Infos", "Langue"],
    todo: ["Liste", "Calendrier", "En retard", "Aujourd'hui", "Tâches", "Hier", "Demain", "Sans tag"],
    actions: ["Terminé", "Annuler", "Enregistrer"]
  )
  static let compactArabicMessages = compactMessages(
    settings: ["عام", "النموذج", "تخصيص", "المظهر", "معلومات", "اللغة"],
    todo: ["قائمة", "تقويم", "متأخر", "اليوم", "مهام", "أمس", "غدًا", "بدون وسم"],
    actions: ["تم", "إلغاء", "حفظ"]
  )
  static let compactBengaliMessages = compactMessages(
    settings: ["সাধারণ", "মডেল", "ব্যক্তিগতকরণ", "চেহারা", "তথ্য", "ভাষা"],
    todo: ["তালিকা", "ক্যালেন্ডার", "বিলম্বিত", "আজ", "কাজ", "গতকাল", "আগামীকাল", "ট্যাগ নেই"],
    actions: ["সম্পন্ন", "বাতিল", "সংরক্ষণ"]
  )

  static let compactRussianMessages = compactMessages(
    settings: ["Общие", "Модель", "Персонализация", "Вид", "Инфо", "Язык"],
    todo: ["Список", "Календарь", "Просрочено", "Сегодня", "Задачи", "Вчера", "Завтра", "Без тега"],
    actions: ["Готово", "Отмена", "Сохранить"]
  )

  static let compactPortugueseMessages = compactMessages(
    settings: ["Geral", "Modelo", "Personalização", "Aparência", "Info", "Idioma"],
    todo: ["Lista", "Calendário", "Atrasado", "Hoje", "Tarefas", "Ontem", "Amanhã", "Sem tag"],
    actions: ["Concluído", "Cancelar", "Salvar"]
  )

  static let compactUrduMessages = compactMessages(
    settings: ["عام", "ماڈل", "ذاتی", "ظاہری شکل", "معلومات", "زبان"],
    todo: ["فہرست", "کیلنڈر", "تاخیر", "آج", "کام", "گزشتہ کل", "کل", "کوئی ٹیگ نہیں"],
    actions: ["مکمل", "منسوخ", "محفوظ"]
  )

  static let compactIndonesianMessages = compactMessages(
    settings: ["Umum", "Model", "Personalisasi", "Tampilan", "Info", "Bahasa"],
    todo: ["Daftar", "Kalender", "Terlambat", "Hari ini", "Tugas", "Kemarin", "Besok", "Tanpa tag"],
    actions: ["Selesai", "Batal", "Simpan"]
  )

  static let compactGermanMessages = compactMessages(
    settings: ["Allgemein", "Modell", "Personalisierung", "Darstellung", "Info", "Sprache"],
    todo: ["Liste", "Kalender", "Überfällig", "Heute", "Aufgaben", "Gestern", "Morgen", "Kein Tag"],
    actions: ["Fertig", "Abbrechen", "Speichern"]
  )

  static let compactJapaneseMessages = compactMessages(
    settings: ["一般", "モデル", "パーソナライズ", "外観", "情報", "言語"],
    todo: ["リスト", "カレンダー", "期限切れ", "今日", "タスク", "昨日", "明日", "タグなし"],
    actions: ["完了", "キャンセル", "保存"]
  )

  static let compactTurkishMessages = compactMessages(
    settings: ["Genel", "Model", "Kişiselleştirme", "Görünüm", "Bilgi", "Dil"],
    todo: ["Liste", "Takvim", "Gecikmiş", "Bugün", "Görevler", "Dün", "Yarın", "Etiket yok"],
    actions: ["Bitti", "İptal", "Kaydet"]
  )

  static func compactMessages(
    settings: [String],
    todo: [String],
    actions: [String]
  ) -> [NativeI18nKey: String] {
    [
      .settingsGeneral: settings[0],
      .settingsModel: settings[1],
      .settingsPersonalization: settings[2],
      .settingsAppearance: settings[3],
      .settingsInfo: settings[4],
      .settingsLanguage: settings[5],
      .todoTabList: todo[0],
      .todoTabCalendar: todo[1],
      .todoOverdue: todo[2],
      .todoToday: todo[3],
      .todoTasks: todo[4],
      .todoYesterday: todo[5],
      .todoTomorrow: todo[6],
      .todoNoLabel: todo[7],
      .commonDone: actions[0],
      .commonCancel: actions[1],
      .commonSave: actions[2]
    ]
  }
}
