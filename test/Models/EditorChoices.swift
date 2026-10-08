enum EditorAction: String, CaseIterable, Identifiable {
    case paraphrase
    case shorten
    case translate
    case proofread

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paraphrase:
            "Перефразировать"
        case .shorten:
            "Сократить"
        case .translate:
            "Перевести"
        case .proofread:
            "Исправить ошибки"
        }
    }
}

enum TranslationLanguage: String, CaseIterable, Identifiable {
    case en
    case ru
    case de
    case fr
    case es
    case it
    case tr
    case zh

    var id: String { rawValue }

    var title: String {
        switch self {
        case .en:
            "английский"
        case .ru:
            "русский"
        case .de:
            "немецкий"
        case .fr:
            "французский"
        case .es:
            "испанский"
        case .it:
            "итальянский"
        case .tr:
            "турецкий"
        case .zh:
            "китайский"
        }
    }
}
