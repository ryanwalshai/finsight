# FinSightNative

The native SwiftUI rewrite of the iPhone app, being built a screen at a time.

Nothing in here is in the Xcode target yet. That is deliberate: the app currently builds and runs
the web view in `ios/index.html`, that build works, and adding a few thousand lines of
never-compiled Swift to a working target is how you end up with neither.

## Status

**None of this has been compiled.** It was written on Linux, where there is no Swift toolchain and
no iOS SDK, so every line here is unverified. Expect to spend the first session in Xcode fixing
compile errors — that is the expected cost of the approach, not a sign something went wrong.

| Stage | What | State |
| --- | --- | --- |
| 1 | Data model, persistence, backups | written, uncompiled |
| 1 | Financial math (amortisation, payoff, recurring) | written, uncompiled |
| 1 | Design tokens and shared components | written, uncompiled |
| 1 | Tab shell | written, uncompiled |
| 1 | Recurring payments screen, with add/edit/delete | written, uncompiled |
| 2+ | Home, Accounts, Income, Spending, Goals, Mortgage, Strategies, Calendar, Settings | not started |
| 2+ | Charts (~12 kinds, currently hand-drawn SVG) | not started |
| 2+ | Payslip PDF reading (currently pdf.js) | not started |

## Layout

```
Core/Formatting.swift    money, percentages, month keys, ISO dates
Core/Finance.swift       the arithmetic, ported function for function from index.html
Model/FinState.swift     the saved document as Codable types
Model/Store.swift        loading, saving, import/export — the only writer
Model/BackupDocument.swift
Design/Theme.swift       the palette, both themes, as dynamic colours
Design/Components.swift  card, tile, section head, empty state
Views/RootView.swift     tab shell + Menu (backup import/export)
Views/RecurringView.swift
```

## Wiring it into Xcode

1. Drag the `FinSightNative` folder into the project navigator, ticked for the **FinSight** target
   ("Create groups", not folder references).
2. In `FinSight/FinSightApp.swift`, swap the web view for the native root:

   ```swift
   struct ContentView: View {
       var body: some View { RootView() }
   }
   ```

   Keep the old body around while the rewrite is in progress — being able to flip back to the web
   view in one line is worth more than a tidy file.
3. Build. Fix what it complains about. Paste the errors back into the session and they get fixed
   properly rather than guessed at.

## Two rules worth keeping

**The math is the app.** `Core/Finance.swift` is a faithful port, including the parts that look
odd — the next-due day clamped to 28, `payoffMonths` returning nil rather than infinity when the
payment does not cover the interest, money in `Double` rather than `Decimal`. Where this app and
the web app disagree about a figure, this app is wrong. Money is `Double` for exactly that reason:
`Decimal` would be more correct in the abstract and would make the two disagree in the last penny.

**Nothing gets dropped on the way through.** `FinState` and every type under it keep the keys they
do not recognise and write them back out on save, so a backup that has been through this app is
the backup that went in. The collections without native screens yet — accounts, transactions,
holdings, snapshots, payslips — are held as raw JSON rather than half-modelled structs, because an
approximate struct is how you lose a column nobody noticed. Type them when their screen is built,
not before.

## Moving your figures across

The web app's `localStorage` cannot be read from native code in any way worth relying on, so the
two apps each keep their own copy and a backup file moves data between them: export from one,
import into the other. Menu → Your figures, in both.
