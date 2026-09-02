import Foundation

// Money, percentages and dates, written the way the web app writes them.
//
// These are ports rather than reinterpretations. The point of the native app is that it shows
// the same person the same figures, so where the web app made a choice — the penny always
// shown, U+2212 for a minus rather than a hyphen, a month key that is just the first seven
// characters of a date — this file makes the same one. Anywhere the two disagree, this file
// is wrong, not index.html.

enum Fmt {

    /// en-GB grouping with a fixed number of decimals, which is what `toLocaleString` gives.
    private static func grouped(_ value: Double, dp: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.numberStyle = .decimal
        f.minimumFractionDigits = dp
        f.maximumFractionDigits = dp
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.\(dp)f", value)
    }

    /// `fmt` — money, to the penny by default.
    ///
    /// Whole pounds read more calmly but they disagree with your bank: £1,029.40 shown as
    /// £1,029 is a figure you cannot reconcile against a statement.
    static func money(_ n: Double, dp: Int = 2) -> String {
        let v = n.isFinite ? n : 0
        // U+2212 MINUS SIGN, not a hyphen — it aligns with the digits.
        return (v < 0 ? "\u{2212}" : "") + "£" + grouped(abs(v), dp: dp)
    }

    /// `fmtS` — money that always declares its direction, for deltas.
    static func moneySigned(_ n: Double, dp: Int = 2) -> String {
        let v = n.isFinite ? n : 0
        return (v >= 0 ? "+" : "\u{2212}") + "£" + grouped(abs(v), dp: dp)
    }

    /// `fmtP` — a proportion as a percentage. An infinite or NaN ratio has no percentage, and
    /// says so with an em dash rather than printing "inf%".
    static func percent(_ n: Double, dp: Int = 0) -> String {
        guard n.isFinite else { return "—%" }
        return String(format: "%.\(dp)f", n * 100) + "%"
    }

    static func percentSigned(_ n: Double, dp: Int = 1) -> String {
        guard n.isFinite else { return "—%" }
        return (n >= 0 ? "+" : "") + String(format: "%.\(dp)f", n * 100) + "%"
    }

    /// `fmtK` — money short enough to sit under a dial tick: £48k, £1.2m.
    static func moneyShort(_ n: Double) -> String {
        let v = n.isFinite ? n : 0
        let a = abs(v)
        let sign = v < 0 ? "\u{2212}" : ""
        func trimmed(_ d: Double, _ places: Int) -> String {
            var s = String(format: "%.\(places)f", d)
            if s.hasSuffix(".0") { s.removeLast(2) }
            return s
        }
        if a >= 1_000_000 { return sign + "£" + trimmed(a / 1_000_000, a >= 10_000_000 ? 0 : 1) + "m" }
        if a >= 1_000 { return sign + "£" + trimmed(a / 1_000, a >= 10_000 ? 0 : 1) + "k" }
        return sign + "£" + String(Int(a.rounded()))
    }
}

// MARK: - Dates

/// A month, stored the way the web app stores it: the string "2026-09".
///
/// It is a string rather than a `Date` on purpose. Every month key in a saved backup is one of
/// these, and a type that round-trips them exactly is worth more here than one that is prettier
/// to do arithmetic with.
struct MonthKey: Hashable, Codable, CustomStringConvertible, Comparable {
    let year: Int
    let month: Int          // 1...12

    init(year: Int, month: Int) {
        // Normalised so that MonthKey(year: 2026, month: 13) is January 2027 rather than nonsense,
        // which is what `new Date(y, m, 1)` does on the other side.
        let total = year * 12 + (month - 1)
        self.year = Int(floor(Double(total) / 12.0))
        self.month = total - self.year * 12 + 1
    }

    /// Parses "2026-09", and also "2026-09-05" — a month key is the first seven characters of a
    /// date, which is the assumption the web app makes everywhere it calls `.slice(0, 7)`.
    init?(_ raw: String) {
        let parts = raw.split(separator: "-")
        guard parts.count >= 2, let y = Int(parts[0]), let m = Int(parts[1]), (1...12).contains(m) else { return nil }
        self.year = y
        self.month = m
    }

    static var current: MonthKey {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return MonthKey(year: c.year ?? 1970, month: c.month ?? 1)
    }

    var description: String { String(format: "%04d-%02d", year, month) }

    func adding(_ months: Int) -> MonthKey { MonthKey(year: year, month: month + months) }

    /// "Sep 26"
    var short: String { "\(MonthKey.shortNames[month - 1]) \(String(format: "%04d", year).suffix(2))" }
    /// "September 2026"
    var long: String { "\(MonthKey.longNames[month - 1]) \(year)" }

    static func < (a: MonthKey, b: MonthKey) -> Bool {
        a.year != b.year ? a.year < b.year : a.month < b.month
    }

    /// The last `n` months ending at this one, oldest first.
    func lastN(_ n: Int) -> [MonthKey] {
        guard n > 0 else { return [] }
        return (0..<n).reversed().map { adding(-$0) }
    }

    static let shortNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    static let longNames = ["January", "February", "March", "April", "May", "June", "July", "August",
                            "September", "October", "November", "December"]
}

/// Dates are ISO day strings ("2026-09-05") throughout, for the same reason months are strings:
/// that is what is in the file, and a lossless port beats a tidier one.
enum ISODate {

    static func string(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    static func date(from iso: String) -> Date? {
        let parts = iso.split(separator: "-")
        guard parts.count >= 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        // Midday, so a timezone shift cannot move it onto the day before.
        return Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: 12))
    }

    static var today: String { string(from: Date()) }

    /// "5 Sep 26"
    static func label(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count >= 3, let m = Int(parts[1]), let d = Int(parts[2]), (1...12).contains(m) else { return iso }
        return "\(d) \(MonthKey.shortNames[m - 1]) \(String(parts[0]).suffix(2))"
    }

    /// Whole days between an ISO day and today. Positive means in the past.
    static func daysAgo(_ iso: String) -> Int {
        guard let d = date(from: iso) else { return 0 }
        return Int((Date().timeIntervalSince(d) / 86_400).rounded())
    }

    /// Whole days from today until an ISO day. Positive means still to come, which is the way
    /// round every question about a bill is asked.
    static func daysUntil(_ iso: String) -> Int { -daysAgo(iso) }

    /// The last day of a month, as an ISO day.
    static func monthEnd(_ key: MonthKey) -> String {
        let next = key.adding(1)
        guard let firstOfNext = Calendar.current.date(from: DateComponents(year: next.year, month: next.month, day: 1, hour: 12)),
              let last = Calendar.current.date(byAdding: .day, value: -1, to: firstOfNext) else {
            return String(format: "%04d-%02d-28", key.year, key.month)
        }
        return string(from: last)
    }
}

// MARK: - Small shared helpers

func clamp<T: Comparable>(_ n: T, _ low: T, _ high: T) -> T { max(low, min(high, n)) }

extension Sequence where Element == Double {
    var total: Double { reduce(0, +) }
}

/// The web app's `uid()`: short, random, and good enough for keys in a file only ever read by
/// the one device that wrote it.
func uid() -> String {
    let random = String(Int.random(in: 0..<Int(1e12)), radix: 36)
    let stamp = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
    return String((random + stamp).suffix(11))
}
