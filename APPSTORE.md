# Submitting FinSight

Everything App Store Connect asks for, answered, plus the review of where submissions actually
fail and what was done here about each one. Copy the metadata verbatim; it is written to survive
review rather than to sell.

Apple rejects roughly a quarter of submissions, and the great majority of first-round rejections
are not really about the app — they are a missing file, an unanswered question, or a URL that
returns a 404. Those are all settled below.

---

## 1. What goes in App Store Connect

### Identity

| Field | Value |
|---|---|
| Name | `FinSight` |
| Subtitle | `Your money, in your own words` |
| Bundle ID | `com.ryanwalsh.FinSight` |
| SKU | `finsight-ios-1` |
| Primary category | Finance |
| Secondary category | Productivity |
| Price | Free, no in-app purchases |
| Age rating | 4+ |
| Availability | United Kingdom (the app is written around £, ISAs, NI and the UK tax year) |
| Privacy Policy URL | `https://hvrkwd24ct-prog.github.io/finsight/privacy.html` |
| Support URL | `https://hvrkwd24ct-prog.github.io/finsight/support.html` |
| Marketing URL | leave blank |
| Copyright | `2026` |

Both URLs are in this repo (`privacy.html`, `support.html`) and are published by the same GitHub
Pages workflow as the dashboard, so they cannot rot separately from it. **Open both in a private
window before submitting** — a Support URL that 404s is one of the three most common first-round
rejections, and it is invisible from inside Xcode.

### Description

> FinSight is a personal finance dashboard you fill in yourself.
>
> No bank connection, no sign-up, no account, no server. You type what each account says, roughly
> once a month, and FinSight does the rest: net worth over time, what a month actually costs, how
> your savings rate is moving, when a card or a loan clears, and how close you are to what you are
> saving for.
>
> Because nothing is connected, nothing can leak. Everything stays on this iPhone. FinSight makes
> no network requests at all — it works the same in airplane mode as anywhere else.
>
> WHAT IT KEEPS
> • Current accounts, savings, pots, credit cards and cash ISAs
> • Stocks & Shares ISAs, general investing, bonds and crypto
> • Mortgage and loans — the rate, the term, the payment, and what an overpayment saves
> • Spending by month, bills that count themselves once you have set them up
> • Payslips: drop the PDF in and it reads gross, tax, NI and pension off it for you to check
> • Goals, and the well-known rules of thumb, measured against your own figures
>
> ON THE PHONE
> • Face ID or your passcode in front of it, checked by iOS before the app is loaded
> • Your balances hidden in the app switcher while the lock is on
> • Long-press the icon for the three jobs of the monthly sit-down
> • Back up to Files, iCloud Drive or AirDrop, and restore from any of them
>
> Try it before typing anything: the second step of setup loads fifteen months of realistic
> figures into every screen.
>
> FinSight keeps your own figures and does arithmetic on them. It is not regulated financial
> advice, it is not connected to any bank or broker, and it never moves money.

Nothing in that text names another platform, promises a feature that is not in the build, or
claims a comparison with a named app — the three ways a description alone gets a rejection under
2.3.

### Keywords (100 characters)

```
budget,net worth,savings,payslip,ISA,mortgage,loan,offline,private,tracker,spending,goals
```

No competitor names, no "best", no repetition of the app name or the category — all of which are
rejected under 2.3.7.

### Notes for App Review

> FinSight is entirely offline and needs no account. There is nothing to sign in to, so no demo
> credentials are needed.
>
> TO SEE EVERY FEATURE IN TWO TAPS: on first launch, accept the privacy screen, then on step 2 of
> setup choose "Load demo data". That fills every screen with fifteen months of realistic figures.
> It can also be loaded later from Settings > Backup & data > Danger zone > Load demo.
>
> No hidden or dormant features. Every screen is reachable from the five tabs at the bottom
> (Home, Budget, Goals, Strategies, Menu); Menu lists the rest.
>
> The app is not a financial service. It has no connection to any bank, broker or payment
> provider, cannot move money, and cannot read an account. Every figure in it was typed in by the
> user or read from a payslip PDF the user chose to open. It is a calculator over the user's own
> notes.
>
> The UI is rendered by WKWebView from an index.html inside the app bundle. Nothing is fetched or
> downloaded at runtime and there is no remote page — the file, its libraries and its typefaces
> are all in the binary, and the app has no network entitlement, so the app is fully self-contained
> per 2.5.2. The native layer around it does what a web view cannot: a LocalAuthentication gate
> evaluated before the dashboard is loaded, the app-switcher privacy shade, Home Screen quick
> actions, share-sheet export, a Files document picker for restore, haptics, and Dynamic Type
> honoured through page zoom.
>
> Face ID usage: the optional app lock only. It is off until the user turns it on, and the device
> passcode always works as the fallback.

Reviewers reject under 2.1 far more often for *not being able to see a feature* than for a bug.
The demo-data line above is the single most valuable sentence in this file.

### App Privacy (the questionnaire, not the policy)

**Data Not Collected.** Answer "No" to the first question — "Do you or your third-party partners
collect data from this app?" — and the rest of the questionnaire does not appear.

This is true of the binary and must stay true: there is no analytics SDK, no crash reporter, no
advertising identifier, and no network code. An App Privacy answer that does not match the binary
is one of the three most common first-round rejections, and the check is partly automated.

### Age rating questionnaire

Every content question: **None**. Then:

- Unrestricted web access — **No**. The web view is confined to `file:` and `about:`; a tapped
  link is handed to Safari instead of being loaded in the app.
- Gambling — **No.** Contests — **No.** User-generated content — **No.**
- Medical/treatment information — **No.**

Result: **4+**.

### Export compliance

Already answered in the binary: `ITSAppUsesNonExemptEncryption = false` in `Info.plist`. The only
cryptography is SHA-256 from the operating system's WebCrypto, used to hash the app-lock PIN.
App Store Connect will not ask again.

### Screenshots

Required: **6.9"** (1320 × 2868 or 1290 × 2796). Everything else is optional and is scaled from it.
Take them on the demo data, in dark mode, with the status bar clean.

Suggested six, in this order: Home, Budget, Mortgage & loans (with the payoff chart), Goals,
Strategies, Settings showing the Face ID lock. Do not add captions that promise anything the
screen does not show, and do not include a device frame with another platform's hardware.

---

## 2. Where submissions fail, and what was done about each

Ordered by how often each one is what actually happened, not by guideline number.

### The three that are decided before a human sees the build

| Failure | Mitigation in this repo |
|---|---|
| **Support URL missing or 404** | `support.html`, published by the same Pages workflow as the app. Real content: getting started, the monthly round, eight common questions, how to report a problem. |
| **`PrivacyInfo.xcprivacy` missing** | `FinSight/PrivacyInfo.xcprivacy`, in the Resources build phase. Declares no collected data, no tracking, and one required-reason API — `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` — for the single boolean holding whether the app lock is on. That is the only such API in the target; there are no third-party SDKs to declare. |
| **App Privacy answers contradict the binary** | Data Not Collected, and the binary contains nothing that could collect: no SDKs, no network entitlement, and a page whose CSP sets `connect-src 'none'`. |

### Guideline 2.1 — App Completeness

- **Placeholder content.** None. No Lorem Ipsum, no "coming soon", no disabled buttons, no dead
  routes — the unreachable screens and their code were removed rather than hidden.
- **Reviewer cannot see the features.** The second step of setup is *Load demo data*: fifteen
  months of realistic figures across every screen, in two taps, with no account. Said again in the
  review notes.
- **Crash on a clean install.** The first-run path is the tested path: privacy gate → onboarding →
  empty app. Every screen renders with no accounts, no payslips and no spending.
- **Broken links inside the app.** There are none to break. The support address is shown as text
  rather than as a tappable link, and the policy is readable in full inside the app rather than
  behind a link that needs a network.

### Guideline 4.2 — Minimum Functionality

The one judgement call in this submission, and the guideline written to reject a web view with an
icon on it. Each of these is something a web page cannot do, and each is a thing you would want on
a finance app you keep on your phone:

- Face ID / device passcode gate via `LAContext`, evaluated by iOS **before the dashboard is
  loaded**, with the system's own lockout rather than a counter a reload resets.
- The app-switcher shade, so the snapshot iOS takes is not your balances.
- Home Screen quick actions, on cold launch and while running.
- Share-sheet export (`<a download>` does nothing in a web view) and Files/iCloud import.
- Haptics.
- Dynamic Type, honoured by mapping the system content-size category to page zoom.
- No white screen: the page is in the bundle, so there is no remote page to fail to arrive.

### Guideline 2.5.2 — Self-contained, no downloaded code

The dashboard is compiled in-browser by a bundled copy of Babel, which is worth pre-empting
because it *looks* like runtime code loading and is not. The source it compiles is a string inside
the same bundled file; Babel itself is inlined in that file; nothing is fetched. There is no
network entitlement and no remote endpoint, so no feature can be introduced or changed after
review. Said plainly in the review notes.

### Guideline 5.1.1 — Privacy

- **Policy URL** — `privacy.html`, and the *same words* are in the app, from one array, so the two
  cannot drift apart.
- **Consent before data handling** — a non-dismissible first-run screen: no close button, no
  dismiss by backdrop, one "Accept and continue". `prefs.privacyAccepted` records the version, so
  bumping `PRIVACY_VERSION` asks everybody again.
- **Readable afterwards** — Settings → Backup & data → Privacy, in full, offline.
- **No account, no personal data required** (5.1.1(v)) — the app is fully functional without ever
  entering a name; the one name field is on the last step of setup and is labelled *Optional*.
- **Purpose strings** — `NSFaceIDUsageDescription` says what it is for in a sentence a person
  would recognise. It is the only permission the app asks for.

### Guideline 5.0 / 3.2.1 — regulated financial services

The trap for anything in the Finance category: an app that *provides* financial services must be
submitted by the institution providing them. FinSight provides none. It holds no money, moves no
money, connects to nothing, and gives no regulated advice. Stated in the review notes, in the
description, in the privacy policy, on the support page, in the first-run screen, and on the Help
card in Settings — because "not financial advice" only counts where somebody will actually read it.

### Guideline 2.3.10 — references to other platforms

The same `index.html` runs as a web page and as this app, and its copy used to say "this browser",
"Safari" and "Add to Home Screen" — inside an iPhone app, which reads as a bookmark with an icon
and is exactly what 4.2 is looking for. The wording now bends: `inApp()` and `where(web, app)`
pick the right noun, so in the app the Storage, Backup, Danger zone and Lock cards talk about this
iPhone and the app's own storage, and the advice to open it in Safari is replaced by a pointer to
the app's own Face ID card.

### Guideline 2.3.1 — hidden or dormant features

Nothing is gated, hidden, or waiting to be switched on remotely — there is no remote to switch it
from. Every screen is reachable from the tab bar or Menu, and the review notes say so.

### Guideline 3.1.1 — payments

Free, no in-app purchase, no external purchase link, nothing unlocked by anything.

### Guideline 4.3 — spam and low-effort apps

One app, one bundle ID, no near-duplicate variants. The June 2026 guideline update added teeth
here for thin apps in saturated categories; the answer is the feature list above rather than an
argument.

### Guideline 2.4.1 / 2.4.5 — hardware and resource use

- iPhone only (`TARGETED_DEVICE_FAMILY = 1`), portrait only, dark, deployment target iOS 17.
- No background modes, no location, no push, no camera, no microphone, no photo library.
- Nothing is written to Documents; a backup goes to the temporary directory and straight out
  through the share sheet, which is why `UIFileSharingEnabled` was removed — it advertised a
  folder of your data in Files that is always empty.

### Accessibility and layout quality

Not a numbered guideline, but the June 2026 update on low-quality apps makes it a live risk, and
a screenshot of overlapping text is the easiest rejection a reviewer can write.

- **Dynamic Type** — `WebHost` maps `preferredContentSizeCategory` to `webView.pageZoom`, capped
  so the dashboard is never laid out narrower than the 320pt it is tested down to. Enlarging past
  that produces a column of overlapping figures, which is the failure this is meant to prevent
  rather than cause.
- **Layout at the narrow end** — the Barefoot tiles now size their figure to the space actually
  available (a container query solving for the width the value needs) rather than at a fixed 23px
  that ran over the tile on a small phone.
- **Safe areas** — the launch screen and the web view's background are the dashboard's own
  `#0a0b0e`, so there is no white flash and no white band under the home indicator.

### The app icon

`Assets.xcassets/AppIcon.appiconset`, single 1024×1024 PNG, no alpha, no transparency, no rounded
corners of its own. A missing or alpha-carrying icon fails validation at upload.

---

## 3. Before you press Submit

- [ ] Open `privacy.html` and `support.html` in a private window. Both must load.
- [ ] Archive on a real device, not just the simulator, and delete-then-install to test first run.
- [ ] Walk the first-run path: privacy screen → Load demo data → every tab → Settings.
- [ ] Turn on the Face ID lock, background the app, check the app switcher shows the shade.
- [ ] Long-press the icon and use all three quick actions from a cold start.
- [ ] Export a backup, delete the app, reinstall, restore from Files.
- [ ] Turn iPhone text size to the largest non-accessibility setting and walk Home and Budget.
- [ ] Set a Team under Signing & Capabilities; confirm no capabilities are enabled that the app
      does not use.
- [ ] Paste the review notes above into App Store Connect. Do not paraphrase them shorter.
