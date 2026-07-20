import Foundation

extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

extension Double {
    var currencyText: String {
        String(format: "$%.4f", self)
    }

    var compactCurrencyText: String {
        if abs(self) >= 1000 {
            return String(format: "$%.2f", self)
        }
        return String(format: "$%.4f", self)
    }
}

extension Int {
    var compactText: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        }
        if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        }
        return "\(self)"
    }
}

enum DateText {
    static func display(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "-" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return raw.replacingOccurrences(of: "T", with: " ").replacingOccurrences(of: "Z", with: "")
    }
}

enum StatusTone {
    case success, warning, danger, neutral

    static func forStatus(_ status: String?) -> StatusTone {
        switch status?.lowercased() {
        case "active", "paid", "success", "ok", "online", "operational":
            return .success
        case "inactive", "pending", "suspended", "unknown":
            return .warning
        case "disabled", "expired", "revoked", "failed", "quota_exhausted", "offline", "error", "degraded":
            return .danger
        default:
            return .neutral
        }
    }
}
