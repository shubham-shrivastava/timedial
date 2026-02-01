import Foundation

@MainActor
final class DateFormatterCache {
    static let shared = DateFormatterCache()

    private struct Key: Hashable {
        let timeZoneId: String
        let style: DateFormatter.Style
    }

    private var cache: [Key: DateFormatter] = [:]

    func formatter(timeZone: TimeZone, style: DateFormatter.Style) -> DateFormatter {
        let key = Key(timeZoneId: timeZone.identifier, style: style)
        if let formatter = cache[key] {
            return formatter
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = style
        formatter.timeZone = timeZone
        cache[key] = formatter
        return formatter
    }

    func string(from date: Date, timeZone: TimeZone, style: DateFormatter.Style) -> String {
        formatter(timeZone: timeZone, style: style).string(from: date)
    }
}
