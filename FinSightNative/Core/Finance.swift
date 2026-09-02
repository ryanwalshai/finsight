import Foundation

// The arithmetic, ported from index.html.
//
// Everything here is a pure function of its arguments. That is deliberate: it is the part of the
// app that has to be right, it is the part that is worth testing, and it is the part that must
// not quietly disagree with the web app about what a person owes.
//
// One note on types. Money is `Double`, not `Decimal`, because the web app computes in IEEE
// doubles and the whole point is that both apps show the same figure. Switching to Decimal here
// would be more correct in the abstract and would make the two disagree in the last penny of a
// long amortisation, which is worse.

enum Finance {

    // MARK: - Amortisation

    /// The level monthly payment that clears `balance` over `termMonths` at `annualPct`.
    ///
    /// Derived from the outstanding balance rather than the original advance, so the figures stay
    /// right after an overpayment or a remortgage.
    static func monthlyPayment(balance: Double, annualPct: Double, termMonths: Int) -> Double {
        guard balance > 0, termMonths > 0 else { return 0 }
        let r = annualPct / 100 / 12
        if r <= 0 { return balance / Double(termMonths) }
        return balance * r / (1 - pow(1 + r, -Double(termMonths)))
    }

    /// Months still to run: the term less what has already elapsed since it started.
    static func termMonths(of m: Mortgage) -> Int {
        let total = Int((m.termYears * 12).rounded())
        guard !m.startDate.isEmpty else { return max(1, total) }
        let parts = m.startDate.split(separator: "-")
        guard parts.count >= 2, let y = Int(parts[0]), let mo = Int(parts[1]) else { return max(1, total) }
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        let elapsed = ((now.year ?? y) - y) * 12 + ((now.month ?? mo) - mo)
        return clamp(total - max(0, elapsed), 1, max(1, total))
    }

    /// What actually leaves the account each month: the figure typed in by hand if there is one,
    /// otherwise the computed payment.
    static func payment(of m: Mortgage) -> Double {
        m.paymentOverride > 0 ? m.paymentOverride
                              : monthlyPayment(balance: m.balance, annualPct: m.rate, termMonths: termMonths(of: m))
    }

    /// The same equation read the other way: given what you can pay, how long until it clears?
    ///
    /// `nil` when the payment does not even cover the interest, which is the answer that matters —
    /// the balance grows, it is never paid off, and a slider needs to say so rather than draw a
    /// line off the end of the chart.
    static func payoffMonths(balance: Double, annualPct: Double, payment: Double) -> Int? {
        guard balance > 0 else { return 0 }
        guard payment > 0 else { return nil }
        let r = annualPct / 100 / 12
        if r <= 0 { return Int((balance / payment).rounded(.up)) }
        if payment <= balance * r + 0.005 { return nil }        // interest-only or worse
        return Int((-log(1 - r * balance / payment) / log(1 + r)).rounded(.up))
    }

    /// What a debt costs in total interest if paid at `payment` a month until it clears.
    static func totalInterest(balance: Double, annualPct: Double, payment: Double) -> Double? {
        guard let n = payoffMonths(balance: balance, annualPct: annualPct, payment: payment) else { return nil }
        return max(0, payment * Double(n) - balance)
    }

    /// The balance `k` whole months from now at a chosen payment, for drawing the curve.
    static func balanceAfter(balance: Double, annualPct: Double, payment: Double, months k: Int) -> Double {
        let r = annualPct / 100 / 12
        if r <= 0 { return max(0, balance - payment * Double(k)) }
        let g = pow(1 + r, Double(k))
        return max(0, balance * g - payment * (g - 1) / r)
    }

    /// Outstanding balance on a given date. A date in the past walks the schedule backwards.
    static func balance(of m: Mortgage, at iso: String) -> Double {
        guard m.balance > 0 else { return 0 }
        let now = ISODate.today
        let nowParts = now.split(separator: "-").compactMap { Int($0) }
        let atParts = iso.split(separator: "-").compactMap { Int($0) }
        guard nowParts.count >= 2, atParts.count >= 2 else { return m.balance }
        let k = (atParts[0] - nowParts[0]) * 12 + (atParts[1] - nowParts[1])
        let r = m.rate / 100 / 12
        let pay = payment(of: m)
        let ceiling = m.borrowed > 0 ? m.borrowed : Double.greatestFiniteMagnitude
        if r <= 0 { return clamp(m.balance - pay * Double(k), 0, ceiling) }
        let g = pow(1 + r, Double(k))
        return clamp(m.balance * g - pay * (g - 1) / r, 0, ceiling)
    }

    // MARK: - Recurring commitments

    /// Every recurring commitment: the ones typed in by hand, plus a row per mortgage or loan.
    ///
    /// The mortgage rows are derived rather than stored. A stored copy goes stale the moment the
    /// balance changes, and is silently lost when a backup or the demo set replaces the list.
    static func recurringList(_ state: FinState) -> [RecurringPayment] {
        let manual = state.recurringManual.filter { !$0.isDerived }
        let derived: [RecurringPayment] = state.mortgages.compactMap { m in
            let pay = (payment(of: m) * 100).rounded() / 100
            guard pay > 0 else { return nil }
            var row = RecurringPayment(
                id: "mtg-" + m.id,
                name: m.name.isEmpty ? m.kindLabel : m.name,
                amount: pay,
                freq: .monthly,
                dueDay: m.paymentDay,
                dueMonth: 1,
                category: m.isLoan ? "debt" : "housing",
                active: true,
                mortgageId: m.id
            )
            let lender = m.lender.isEmpty ? "" : m.lender + " · "
            row.note = lender + String(format: "%.2f", m.rate) + "% over \(termMonths(of: m)) more months"
            return row
        }
        // Mortgages first, then what was typed in, which is the order the web app builds it in.
        return derived + manual
    }

    /// What the bills you track come to in a given month: everything monthly, plus any yearly one
    /// falling due in it.
    ///
    /// A once-a-year bill lands in the month it actually leaves your account — November costs more
    /// than October because that is when the insurance goes out.
    static func billsDue(in month: MonthKey, of state: FinState) -> Double {
        recurringList(state)
            .filter { $0.active && ($0.freq != .yearly || $0.dueMonth == month.month) }
            .map(\.amount)
            .total
    }

    /// The next date a payment falls due, as an ISO day.
    ///
    /// The day is clamped to 28 rather than 31 on purpose: a bill set for the 31st has no such
    /// date in February, and rolling it forward would put "next due" in the wrong month. The 28th
    /// is the last day every month actually has.
    static func nextDue(_ r: RecurringPayment) -> String {
        let cal = Calendar.current
        let today = ISODate.today
        let day = clamp(r.dueDay, 1, 28)
        let now = cal.dateComponents([.year, .month], from: Date())
        let year = now.year ?? 1970
        let month = now.month ?? 1

        func iso(year: Int, month: Int, day: Int) -> String {
            guard let d = cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else {
                return String(format: "%04d-%02d-%02d", year, month, day)
            }
            return ISODate.string(from: d)
        }

        if r.freq == .yearly {
            let thisYear = iso(year: year, month: r.dueMonth, day: day)
            return thisYear < today ? iso(year: year + 1, month: r.dueMonth, day: day) : thisYear
        }
        let thisMonth = iso(year: year, month: month, day: day)
        // month + 1 rolls into January of the next year on its own — DateComponents normalises.
        return thisMonth < today ? iso(year: year, month: month + 1, day: day) : thisMonth
    }

    /// The order the Recurring screen lists payments in: soonest first.
    ///
    /// Anything switched off has no next date and sits at the end rather than jumping to the front
    /// on an empty sort key, and a tie between two payments on the same day is broken by name so
    /// the order does not shuffle between redraws.
    static func byNextDue(_ rows: [RecurringPayment]) -> [RecurringPayment] {
        rows.sorted { a, b in
            if a.active != b.active { return a.active }
            if !a.active { return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending }
            let da = nextDue(a), db = nextDue(b)
            if da == db { return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending }
            return da < db
        }
    }
}
