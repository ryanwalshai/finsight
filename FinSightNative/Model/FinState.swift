import Foundation

// The saved state, as Swift types.
//
// The governing constraint here is that a file written by the web app has to survive a trip
// through this app unchanged. A person with two years of figures in index.html should be able to
// export a backup, open it here, change one bill, send it back, and find everything else exactly
// as they left it — including the parts this app has no screens for yet.
//
// So every type carries `extras`: the keys it did not recognise, kept verbatim and written back
// out on save. A field this app has never heard of is not a field it is entitled to delete. The
// same rule is why the collections below that have no native screen yet (accounts, transactions,
// holdings, snapshots, payslips, and the typed-in month maps) stay as raw JSON rather than being
// half-modelled: an approximate struct is how you lose a column nobody noticed.

// MARK: - Any JSON, kept losslessly

/// A value of any JSON shape. Used for the parts of the file this app does not model yet.
enum JSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unrecognised JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    var double: Double? { if case .number(let v) = self { return v }; return nil }
    var string: String? { if case .string(let v) = self { return v }; return nil }
    var bool: Bool? { if case .bool(let v) = self { return v }; return nil }
    var object: [String: JSONValue]? { if case .object(let v) = self { return v }; return nil }
    var array: [JSONValue]? { if case .array(let v) = self { return v }; return nil }
}

/// A coding key whose name is only known at runtime, for reading and writing `extras`.
struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue s: String) { stringValue = s }
    init?(intValue: Int) { return nil }
}

extension KeyedDecodingContainer {
    /// Decode, or fall back — a missing key, a null, or a value of the wrong type all give the
    /// default rather than failing the whole document. A backup written by a older or newer
    /// version of the app still opens.
    func get<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }
}

extension Decoder {
    /// Everything in this container that is not one of `known`, kept as-is.
    func extras(besides known: [String]) -> [String: JSONValue] {
        guard let c = try? container(keyedBy: DynamicKey.self) else { return [:] }
        let skip = Set(known)
        var out: [String: JSONValue] = [:]
        for key in c.allKeys where !skip.contains(key.stringValue) {
            if let v = try? c.decode(JSONValue.self, forKey: key) { out[key.stringValue] = v }
        }
        return out
    }
}

extension Encoder {
    func writeExtras(_ extras: [String: JSONValue]) throws {
        guard !extras.isEmpty else { return }
        var c = container(keyedBy: DynamicKey.self)
        for (k, v) in extras { try c.encode(v, forKey: DynamicKey(k)) }
    }
}

// MARK: - Recurring payments

struct RecurringPayment: Codable, Identifiable, Equatable {
    var id: String = uid()
    var name: String = ""
    var amount: Double = 0
    var freq: Frequency = .monthly
    /// 1...31 as stored. Note that the *next due date* clamps this to 28 — see `Finance.nextDue`.
    var dueDay: Int = 1
    /// Only meaningful for a yearly payment: the month it goes out.
    var dueMonth: Int = 1
    var category: String = "subscriptions"
    var note: String = ""
    var active: Bool = true
    /// Set only on the rows derived from a mortgage or loan. Those are computed on the fly and
    /// never stored — a stored copy goes stale the moment the balance changes.
    var mortgageId: String?

    var extras: [String: JSONValue] = [:]

    enum Frequency: String, Codable, CaseIterable {
        case monthly, yearly
        var label: String { self == .monthly ? "Monthly" : "Yearly" }
    }

    /// What this costs per month: a yearly bill spread over the twelve.
    var monthlyEquivalent: Double { freq == .yearly ? amount / 12 : amount }

    /// True for the rows owned by the Mortgage & loans screen, which cannot be edited or deleted
    /// here — the way to be rid of one is to be rid of the debt behind it.
    var isDerived: Bool { mortgageId != nil }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, name, amount, freq, dueDay, dueMonth, category, note, active, mortgageId
    }

    init(id: String = uid(), name: String = "", amount: Double = 0, freq: Frequency = .monthly,
         dueDay: Int = 1, dueMonth: Int = 1, category: String = "subscriptions",
         note: String = "", active: Bool = true, mortgageId: String? = nil) {
        self.id = id; self.name = name; self.amount = amount; self.freq = freq
        self.dueDay = dueDay; self.dueMonth = dueMonth; self.category = category
        self.note = note; self.active = active; self.mortgageId = mortgageId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.get(.id, uid())
        name = c.get(.name, "")
        amount = c.get(.amount, 0)
        freq = Frequency(rawValue: c.get(.freq, "monthly")) ?? .monthly
        dueDay = clamp(c.get(.dueDay, 1), 1, 31)
        dueMonth = clamp(c.get(.dueMonth, 1), 1, 12)
        category = c.get(.category, "subscriptions")
        note = c.get(.note, "")
        // Only an explicit false switches a payment off, matching `r.active !== false`: a row
        // saved before the flag existed is still a live bill.
        active = c.get(.active, true)
        mortgageId = (try? c.decodeIfPresent(String.self, forKey: .mortgageId)) ?? nil
        extras = decoder.extras(besides: CodingKeys.allCases.map(\.rawValue))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(amount, forKey: .amount)
        try c.encode(freq.rawValue, forKey: .freq)
        try c.encode(dueDay, forKey: .dueDay)
        try c.encode(dueMonth, forKey: .dueMonth)
        try c.encode(category, forKey: .category)
        try c.encode(note, forKey: .note)
        try c.encode(active, forKey: .active)
        try c.encodeIfPresent(mortgageId, forKey: .mortgageId)
        try encoder.writeExtras(extras)
    }
}


// MARK: - Mortgages and loans

/// A loan and a mortgage are the same arithmetic — a balance, a rate, a term, a level payment.
/// They share one type and carry a `kind` to say which they are; a record with no kind is a
/// mortgage, which is what every record was before loans existed.
struct Mortgage: Codable, Identifiable, Equatable {
    var id: String = uid()
    var kind: Kind = .mortgage
    var name: String = ""
    var lender: String = ""
    var propertyValue: Double = 0
    var borrowed: Double = 0
    var balance: Double = 0
    /// Annual rate as a percentage, so 4.5 means 4.5%.
    var rate: Double = 0
    var termYears: Double = 25
    var startDate: String = ISODate.today
    var paymentDay: Int = 1
    /// A payment typed in by hand, which wins over the computed one when above zero.
    var paymentOverride: Double = 0
    var includeInNetWorth: Bool = true

    var extras: [String: JSONValue] = [:]

    enum Kind: String, Codable { case mortgage, loan }

    var isLoan: Bool { kind == .loan }
    var kindLabel: String { isLoan ? "Loan" : "Mortgage" }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id, kind, name, lender, propertyValue, borrowed, balance, rate
        case termYears, startDate, paymentDay, paymentOverride, includeInNetWorth
    }

    init(id: String = uid(), kind: Kind = .mortgage, name: String = "") {
        self.id = id; self.kind = kind; self.name = name
        self.termYears = kind == .loan ? 5 : 25
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.get(.id, uid())
        kind = Kind(rawValue: c.get(.kind, "mortgage")) ?? .mortgage
        name = c.get(.name, kind == .loan ? "Loan" : "Mortgage")
        lender = c.get(.lender, "")
        propertyValue = kind == .loan ? 0 : c.get(.propertyValue, 0)
        borrowed = c.get(.borrowed, 0)
        balance = c.get(.balance, 0)
        rate = c.get(.rate, 0)
        termYears = c.get(.termYears, kind == .loan ? 5 : 25)
        startDate = c.get(.startDate, ISODate.today)
        paymentDay = clamp(c.get(.paymentDay, 1), 1, 28)
        paymentOverride = c.get(.paymentOverride, 0)
        includeInNetWorth = c.get(.includeInNetWorth, true)
        extras = decoder.extras(besides: CodingKeys.allCases.map(\.rawValue))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind.rawValue, forKey: .kind)
        try c.encode(name, forKey: .name)
        try c.encode(lender, forKey: .lender)
        try c.encode(propertyValue, forKey: .propertyValue)
        try c.encode(borrowed, forKey: .borrowed)
        try c.encode(balance, forKey: .balance)
        try c.encode(rate, forKey: .rate)
        try c.encode(termYears, forKey: .termYears)
        try c.encode(startDate, forKey: .startDate)
        try c.encode(paymentDay, forKey: .paymentDay)
        try c.encode(paymentOverride, forKey: .paymentOverride)
        try c.encode(includeInNetWorth, forKey: .includeInNetWorth)
        try encoder.writeExtras(extras)
    }
}


// MARK: - Preferences and targets

struct Prefs: Codable, Equatable {
    var name: String = ""
    var theme: String = "system"
    var currency: String = "GBP"
    var startPage: String = "overview"
    var disclaimerHide: Bool = false
    var privacyAccepted: Int = 0

    var extras: [String: JSONValue] = [:]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case name, theme, currency, startPage, disclaimerHide, privacyAccepted
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.get(.name, "")
        theme = c.get(.theme, "system")
        currency = c.get(.currency, "GBP")
        startPage = c.get(.startPage, "overview")
        disclaimerHide = c.get(.disclaimerHide, false)
        privacyAccepted = c.get(.privacyAccepted, 0)
        extras = decoder.extras(besides: CodingKeys.allCases.map(\.rawValue))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(theme, forKey: .theme)
        try c.encode(currency, forKey: .currency)
        try c.encode(startPage, forKey: .startPage)
        try c.encode(disclaimerHide, forKey: .disclaimerHide)
        try c.encode(privacyAccepted, forKey: .privacyAccepted)
        try encoder.writeExtras(extras)
    }
}


struct Targets: Codable, Equatable {
    var monthlySpend: Double = 0
    var monthlySave: Double = 0
    var emergencyFund: Double = 0
    var monthlyInvest: Double = 0
    var isaAnnual: Double = 20_000
    var netWorth: Double = 0

    var extras: [String: JSONValue] = [:]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case monthlySpend, monthlySave, emergencyFund, monthlyInvest, isaAnnual, netWorth
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        monthlySpend = c.get(.monthlySpend, 0)
        monthlySave = c.get(.monthlySave, 0)
        emergencyFund = c.get(.emergencyFund, 0)
        monthlyInvest = c.get(.monthlyInvest, 0)
        isaAnnual = c.get(.isaAnnual, 20_000)
        netWorth = c.get(.netWorth, 0)
        extras = decoder.extras(besides: CodingKeys.allCases.map(\.rawValue))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(monthlySpend, forKey: .monthlySpend)
        try c.encode(monthlySave, forKey: .monthlySave)
        try c.encode(emergencyFund, forKey: .emergencyFund)
        try c.encode(monthlyInvest, forKey: .monthlyInvest)
        try c.encode(isaAnnual, forKey: .isaAnnual)
        try c.encode(netWorth, forKey: .netWorth)
        try encoder.writeExtras(extras)
    }
}


// MARK: - The document

struct FinState: Codable, Equatable {
    var version: Int = 1
    var onboarded: Bool = false
    var prefs = Prefs()
    var targets = Targets()
    var recurringManual: [RecurringPayment] = []
    var mortgages: [Mortgage] = []

    // Not modelled yet — each of these gets typed when its screen is built. Until then they are
    // carried through byte for byte so that nothing is lost by opening a backup here.
    var accounts: [JSONValue] = []
    var transactions: [JSONValue] = []
    var holdings: [JSONValue] = []
    var snapshots: [JSONValue] = []
    var payslips: [JSONValue] = []
    var monthlySpend: [String: JSONValue] = [:]
    var notes: [String: JSONValue] = [:]
    var isaYearUsed: [String: JSONValue] = [:]

    var extras: [String: JSONValue] = [:]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case version, onboarded, prefs, targets, recurringManual, mortgages
        case accounts, transactions, holdings, snapshots, payslips
        case monthlySpend, notes, isaYearUsed
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.get(.version, 1)
        onboarded = c.get(.onboarded, false)
        prefs = c.get(.prefs, Prefs())
        targets = c.get(.targets, Targets())
        recurringManual = c.get(.recurringManual, [])
        mortgages = c.get(.mortgages, [])
        accounts = c.get(.accounts, [])
        transactions = c.get(.transactions, [])
        holdings = c.get(.holdings, [])
        snapshots = c.get(.snapshots, [])
        payslips = c.get(.payslips, [])
        monthlySpend = c.get(.monthlySpend, [:])
        notes = c.get(.notes, [:])
        isaYearUsed = c.get(.isaYearUsed, [:])
        extras = decoder.extras(besides: CodingKeys.allCases.map(\.rawValue))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(onboarded, forKey: .onboarded)
        try c.encode(prefs, forKey: .prefs)
        try c.encode(targets, forKey: .targets)
        try c.encode(recurringManual, forKey: .recurringManual)
        try c.encode(mortgages, forKey: .mortgages)
        try c.encode(accounts, forKey: .accounts)
        try c.encode(transactions, forKey: .transactions)
        try c.encode(holdings, forKey: .holdings)
        try c.encode(snapshots, forKey: .snapshots)
        try c.encode(payslips, forKey: .payslips)
        try c.encode(monthlySpend, forKey: .monthlySpend)
        try c.encode(notes, forKey: .notes)
        try c.encode(isaYearUsed, forKey: .isaYearUsed)
        try encoder.writeExtras(extras)
    }
}


// MARK: - Categories

struct SpendCategory: Identifiable, Equatable {
    let id: String
    let label: String
    let hex: String
    let essential: Bool
}

enum Categories {
    /// The same list, in the same order, with the same colours as the web app.
    static let all: [SpendCategory] = [
        .init(id: "groceries", label: "Groceries", hex: "#6FBF52", essential: true),
        .init(id: "housing", label: "Housing & Rent", hex: "#D98452", essential: true),
        .init(id: "utilities", label: "Utilities & Bills", hex: "#D9AE5C", essential: true),
        .init(id: "debt", label: "Loan repayments", hex: "#C97A5A", essential: true),
        .init(id: "transport", label: "Transport", hex: "#7C7FD9", essential: true),
        .init(id: "dining", label: "Dining Out", hex: "#C24E82", essential: false),
        .init(id: "coffee", label: "Coffee & Snacks", hex: "#D08B6B", essential: false),
        .init(id: "subscriptions", label: "Subscriptions", hex: "#A98FD9", essential: false),
        .init(id: "shopping", label: "Shopping", hex: "#D9679A", essential: false),
        .init(id: "health", label: "Health & Fitness", hex: "#4FB6AE", essential: true),
        .init(id: "entertainment", label: "Entertainment", hex: "#B15FC9", essential: false),
        .init(id: "travel", label: "Travel", hex: "#8FC4E8", essential: false),
        .init(id: "insurance", label: "Insurance", hex: "#5B5FA6", essential: true),
        .init(id: "fees", label: "Fees & Charges", hex: "#D9526B", essential: true),
        .init(id: "income", label: "Income", hex: "#3FAE7A", essential: false),
        .init(id: "savings", label: "Savings", hex: "#6FC9C4", essential: false),
        .init(id: "investing", label: "Investing", hex: "#6B4FA0", essential: false),
        .init(id: "transfers", label: "Transfers", hex: "#6B7280", essential: false),
        .init(id: "other", label: "Uncategorised", hex: "#7A7E88", essential: false),
    ]

    /// An unknown id is Uncategorised rather than a crash — categories are strings in the file.
    static func byId(_ id: String) -> SpendCategory {
        all.first { $0.id == id } ?? all[all.count - 1]
    }

    /// The ones a payment can be filed under: what money goes out on, not where it moved to.
    static let spending: [SpendCategory] = all.filter {
        !["income", "savings", "investing", "transfers"].contains($0.id)
    }
}
