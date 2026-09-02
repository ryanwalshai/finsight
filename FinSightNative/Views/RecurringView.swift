import SwiftUI

/// The bills and subscriptions you pay regularly.
///
/// This is the screen that prompted the native app, so it is worth saying what changed. On the web
/// it is a table, and a table on a 390pt screen has to put edit and delete in a column narrow
/// enough that three icons share about eighty points between them. Here each payment is a row you
/// tap to edit and swipe to delete, which is both bigger than a fingertip and the thing an iPhone
/// user already expects. The action is not hidden in a cramped cell; it is the row itself.
struct RecurringView: View {
    @Environment(Store.self) private var store

    @State private var draft: RecurringDraft?
    @State private var pendingDelete: RecurringPayment?
    @State private var validationMessage: String?

    // MARK: - Figures

    private var all: [RecurringPayment] { store.recurring }
    private var active: [RecurringPayment] { all.filter(\.active) }

    /// What goes out every month, not counting the yearly ones.
    private var monthlyOnly: Double {
        active.filter { $0.freq != .yearly }.map(\.amount).total
    }
    /// The yearly bills, spread over twelve months.
    private var yearlyAveraged: Double {
        active.filter { $0.freq == .yearly }.map(\.monthlyEquivalent).total
    }
    private var totalPerMonth: Double { monthlyOnly + yearlyAveraged }

    /// What actually leaves the account in the next thirty days, at full amount — a yearly bill
    /// falling next week costs its whole self, not a twelfth of it.
    private var dueIn30Days: Double {
        active.filter { ISODate.daysUntil(Finance.nextDue($0)) <= 30 }
              .map(\.amount).total
    }

    private var monthly: [RecurringPayment] { Finance.byNextDue(all.filter { $0.freq == .monthly }) }
    private var yearly: [RecurringPayment] { Finance.byNextDue(all.filter { $0.freq == .yearly }) }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.fsBg.ignoresSafeArea()
            List {
                Section {
                    header
                    tiles
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                paymentSection(
                    title: "Monthly payments",
                    rows: monthly,
                    empty: "Nothing tracked yet. Add one with the button above."
                )

                if !yearly.isEmpty {
                    paymentSection(
                        title: "Yearly payments",
                        rows: yearly,
                        empty: nil
                    )
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.fsBg)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $draft) { current in
            RecurringEditor(
                draft: current,
                onSave: save,
                onDelete: { payment in
                    draft = nil
                    pendingDelete = payment
                }
            )
        }
        .confirmationDialog(
            pendingDelete.map { "Stop tracking \($0.name)?" } ?? "",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let p = pendingDelete { store.deleteRecurring(id: p.id) }
                pendingDelete = nil
            }
            Button("Keep it", role: .cancel) { pendingDelete = nil }
        } message: {
            // Named, because "are you sure?" against a list of nine bills is a question you
            // cannot answer.
            Text("It comes out of your bills, your monthly total and the calendar. This cannot be undone.")
        }
        .alert("FinSight", isPresented: Binding(get: { validationMessage != nil },
                                                set: { if !$0 { validationMessage = nil } })) {
            Button("OK", role: .cancel) { validationMessage = nil }
        } message: {
            Text(validationMessage ?? "")
        }
    }

    private var header: some View {
        FSSectionHead(
            title: "Recurring payments",
            sub: "The bills and subscriptions you pay regularly, and what they come to"
        ) {
            Button {
                draft = RecurringDraft()
            } label: {
                Label("Add payment", systemImage: "plus")
            }
            .buttonStyle(FSPrimaryButtonStyle())
        }
        .padding(.top, 4)
    }

    private var tiles: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            // The headline is what leaves every month on its own. The yearly bills are real but
            // they are an average, and averaging them into the same figure made a number that
            // matches neither the standing orders nor the bank statement.
            FSTile(
                icon: "arrow.triangle.2.circlepath",
                tint: Color.fsFixed(Categories.byId("subscriptions").hex),
                key: "Every month",
                value: Fmt.money(monthlyOnly),
                sub: yearlyAveraged > 0
                    ? "+\(Fmt.money(yearlyAveraged)) from yearly ones averaged in"
                    : "\(active.count) payment\(active.count == 1 ? "" : "s")"
            )
            FSTile(
                icon: "calendar",
                tint: Color.fsPurple,
                key: "A year of it",
                value: Fmt.money(totalPerMonth * 12),
                sub: "what these come to over twelve months"
            )
            FSTile(
                icon: "clock",
                tint: Color.fsFixed("#8FC4E8"),
                key: "Next 30 days",
                value: Fmt.money(dueIn30Days),
                valueColor: dueIn30Days > 0 ? Color.fsAmber : nil,
                sub: "what leaves before the month is out"
            )
            FSTile(
                icon: "percent",
                tint: Color.fsRed,
                key: "Share of income",
                value: "—",
                // Honest about why: income comes from payslips and statements, which this app
                // does not read yet.
                sub: "needs your income, which is still in the web app"
            )
        }
    }

    @ViewBuilder
    private func paymentSection(title: String, rows: [RecurringPayment], empty: String?) -> some View {
        Section {
            if rows.isEmpty, let empty {
                Text(empty)
                    .font(FSFont.body(13))
                    .foregroundStyle(Color.fsDim)
                    .listRowBackground(Color.fsSurface)
            }
            ForEach(rows) { row in
                RecurringRow(payment: row)
                    .contentShape(Rectangle())
                    .onTapGesture { open(row) }
                    .listRowBackground(Color.fsSurface)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !row.isDerived {
                            Button(role: .destructive) { pendingDelete = row } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { store.toggleRecurringActive(id: row.id) } label: {
                                Label(row.active ? "Pause" : "Resume",
                                      systemImage: row.active ? "eye.slash" : "eye")
                            }
                            .tint(Color.fsAmber)
                        }
                    }
            }
        } header: {
            Text(title.uppercased())
                .font(FSFont.display(11, .bold))
                .tracking(1.5)
                .foregroundStyle(Color.fsMuted)
        }
    }

    // MARK: - Actions

    private func open(_ payment: RecurringPayment) {
        guard !payment.isDerived else {
            validationMessage = "\(payment.name) comes from the Mortgage & loans screen, which works out the payment from the balance and rate. Change it there and this follows."
            return
        }
        draft = RecurringDraft(payment)
    }

    private func save(_ draft: RecurringDraft) {
        guard let payment = draft.toPayment() else {
            validationMessage = "A name and a positive amount are required."
            return
        }
        store.saveRecurring(payment)
        self.draft = nil
    }
}

// MARK: - One row

private struct RecurringRow: View {
    let payment: RecurringPayment

    var body: some View {
        HStack(spacing: 11) {
            Circle()
                .fill(Color.fsFixed(Categories.byId(payment.category).hex))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(payment.name)
                        .font(FSFont.body(15, .medium))
                        .foregroundStyle(Color.fsText)
                        .lineLimit(1)
                    if payment.isDerived {
                        Text(payment.category == "debt" ? "loan" : "mortgage")
                            .font(FSFont.body(10, .semibold))
                            .foregroundStyle(Color.fsAmber)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.fsAmber.opacity(0.14), in: Capsule())
                    }
                }
                Text(payment.active ? ISODate.label(Finance.nextDue(payment)) : "Paused")
                    .font(FSFont.body(12))
                    .foregroundStyle(Color.fsDim)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.money(payment.amount))
                    .font(FSFont.number(15, .semibold))
                    .foregroundStyle(Color.fsText)
                if payment.freq == .yearly {
                    Text("\(Fmt.money(payment.monthlyEquivalent))/mo")
                        .font(FSFont.number(11, .regular))
                        .foregroundStyle(Color.fsDim)
                }
            }
        }
        .padding(.vertical, 5)
        .opacity(payment.active ? 1 : 0.45)
    }
}

// MARK: - The draft behind the editor

/// The editor's working copy. Amounts and days are strings while being typed, because a field
/// holding a number cannot represent "half-way through typing 15.99".
struct RecurringDraft: Identifiable {
    var id: String
    var isExisting: Bool
    var name: String
    var amount: String
    var freq: RecurringPayment.Frequency
    var dueDay: Int
    var dueMonth: Int
    var category: String
    var note: String
    var active: Bool
    private var original: RecurringPayment?

    init() {
        id = uid()
        isExisting = false
        name = ""
        amount = ""
        freq = .monthly
        dueDay = 1
        dueMonth = 1
        category = "subscriptions"
        note = ""
        active = true
        original = nil
    }

    init(_ p: RecurringPayment) {
        id = p.id
        isExisting = true
        name = p.name
        amount = String(format: "%.2f", p.amount)
        freq = p.freq
        dueDay = p.dueDay
        dueMonth = p.dueMonth
        category = p.category
        note = p.note
        active = p.active
        original = p
    }

    /// `nil` when there is nothing worth saving: no name, or an amount that is not a positive
    /// number. The same two rules the web app enforces.
    func toPayment() -> RecurringPayment? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Accept a comma for the decimal point, and ignore a £ typed out of habit.
        let cleaned = amount
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "£", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned), value > 0 else { return nil }

        var out = original ?? RecurringPayment(id: id)
        out.id = id
        out.name = trimmed
        out.amount = value
        out.freq = freq
        out.dueDay = clamp(dueDay, 1, 31)
        out.dueMonth = clamp(dueMonth, 1, 12)
        out.category = category
        out.note = note
        out.active = active
        out.mortgageId = nil
        return out
    }
}

// MARK: - The editor

private struct RecurringEditor: View {
    @State var draft: RecurringDraft
    let onSave: (RecurringDraft) -> Void
    let onDelete: (RecurringPayment) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Car insurance", text: $draft.name)
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("£").foregroundStyle(Color.fsDim)
                        TextField("0.00", text: $draft.amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(FSFont.number(16))
                            .frame(maxWidth: 120)
                    }
                    Picker("Frequency", selection: $draft.freq) {
                        ForEach(RecurringPayment.Frequency.allCases, id: \.self) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    Picker("Category", selection: $draft.category) {
                        ForEach(Categories.spending) { c in
                            Text(c.label).tag(c.id)
                        }
                    }
                }

                Section {
                    Picker("Day of the month", selection: $draft.dueDay) {
                        ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                    }
                    if draft.freq == .yearly {
                        Picker("Month", selection: $draft.dueMonth) {
                            ForEach(1...12, id: \.self) { m in
                                Text(MonthKey.longNames[m - 1]).tag(m)
                            }
                        }
                    }
                } header: {
                    Text("When it goes out")
                } footer: {
                    // Worth saying, because it is the one place the stored day and the shown date
                    // legitimately differ.
                    Text(draft.dueDay > 28
                         ? "Months are not all the same length, so a payment set after the 28th is shown as due on the 28th."
                         : "")
                }

                Section {
                    TextField("Note (optional)", text: $draft.note, axis: .vertical)
                        .lineLimit(1...3)
                    Toggle("Counting towards your bills", isOn: $draft.active)
                } footer: {
                    Text("Switching a payment off keeps it here but takes it out of your totals and the calendar.")
                }

                if draft.isExisting, let existing = draft.toPayment() {
                    Section {
                        // The place people look for it: a word in the sheet they already opened to
                        // change the thing, rather than a glyph in a list.
                        Button(role: .destructive) { onDelete(existing) } label: {
                            Label("Delete this payment", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(draft.isExisting ? "Edit payment" : "Track a payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(draft.isExisting ? "Save" : "Add") { onSave(draft) }
                        .disabled(draft.toPayment() == nil)
                }
            }
        }
    }
}
