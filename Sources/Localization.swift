import Foundation

// [Foundation] 首选语言决定整个 App 的文案，不能扫描后备列表：
// 例如 [fr-FR, zh-Hans] 必须显示英文，而不是因中文在第二位就切换中文。
enum L10n {
    static func language(for preferredLanguages: [String]) -> String {
        guard let first = preferredLanguages.first else { return "en" }
        let parts = first.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-")
        guard parts.first == "zh" else { return "en" }
        if parts.contains("hant") { return "zh-Hant" }
        if parts.contains("hans") { return "zh-Hans" }
        return parts.contains(where: { ["tw", "hk", "mo"].contains($0) }) ? "zh-Hant" : "zh-Hans"
    }
    static let currentLanguage = language(for: Locale.preferredLanguages)
    static func text(_ key: String, language: String = currentLanguage) -> String {
        // [Foundation] 使用指定语言资源包；缺失翻译时回退到英文。
        func bundle(_ language: String) -> Bundle? {
            Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
        }
        let fallback = bundle("en")?.localizedString(forKey: key, value: key, table: nil) ?? key
        return bundle(language)?.localizedString(forKey: key, value: fallback, table: nil) ?? fallback
    }
    static func duration(minutes: Int, charging: Bool, language: String = currentLanguage) -> String {
        String(format: text(charging ? "time_to_full" : "time_remaining", language: language),
               locale: Locale(identifier: language), minutes / 60, minutes % 60)
    }
}
