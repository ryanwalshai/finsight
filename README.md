# FinSight for iPhone

A personal finance dashboard you fill in yourself — accounts, savings, ISAs, investments,
spending, goals and payoff strategies — built as an iPhone app.

**This branch is the iPhone app.** `main` carries the same dashboard as a web page that also
happens to run on a Mac; this one drops the Mac, drops the browser as a target, and spends the
difference on being an app. If you want the web version, it is on `main`.

**Everything stays on your device.** No account, no server, no sign-up, nothing uploaded. The
dashboard is one self-contained `index.html` in the app bundle with React, Babel, pdf.js and the
typefaces all inlined, so there is no build step and nothing to fetch — the app opens on a plane
and in a tunnel exactly as it does anywhere else.

## How it is built, and why not Capacitor

The usual answer to "turn a web app into an iOS app" is Capacitor, and for most projects it is
the right one: it keeps your web code, gives you a native project, and hands you a plugin
ecosystem for the device APIs. None of that pays off here. FinSight has no build pipeline to
preserve — it is a single HTML file, deliberately — so Capacitor would introduce `node_modules`,
a build step and its own runtime in exchange for plugins the app does not call. The thing it
sells is already what this repo has.

So: **WKWebView, loading the bundled file directly**, with a small native layer written for this
app. The part that matters is what is in that layer. Apple's Guideline 4.2 exists precisely to
reject a web view with an icon on it, and rightly — an app that is only a bookmark should be a
bookmark. Everything below is something a browser cannot do, and each one is a thing you would
actually want on a finance app you keep on your phone.

| | |
|---|---|
| **Face ID / passcode gate** | `LAContext`, evaluated by iOS, in front of the dashboard before it is loaded. Wrong attempts are locked out by the system, not by a counter in a page that a reload resets. Falls through to the device passcode, so a failed scan never locks you out of your own figures. Off until you turn it on. |
| **App switcher shade** | The snapshot iOS takes when you swipe away is covered before it is taken. A card in the switcher showing your balances is the leak that needs no attacker at all. |
| **Home Screen quick actions** | Long-press the icon for *Update balances*, *Add spending* or *Add payslip* — the three jobs of the monthly sit-down — and land on that screen. Handled on cold launch and while running. |
| **Share sheet exports** | `<a download>` does nothing inside a web view. Backups are intercepted and handed to the real share sheet: Files, iCloud Drive, AirDrop, Mail. |
| **Files import** | Restore a backup straight from Files or iCloud, which a page in a browser cannot reach. It goes through the same guarded restore as any other file. |
| **Haptics** | A confirmation you can feel without looking. |
| **Offline by construction** | The page is in the bundle. There is no remote page to fail to arrive and no white screen where one would have been. |

The same `index.html` still runs in a browser. Every native call is feature-detected against
`window.__finsightNative`, so on a laptop none of it exists and the app behaves as it always did.

### The bridge

One `WKScriptMessageHandler` named `finsight`, one `action` field, one switch statement you can
read in full — rather than a handler per feature. It carries `ready`, `save`, `import`, `haptic`
and `setLock`, and nothing in it accepts a path or a URL that Swift then acts on blindly.

```
FinSight/
  FinSightApp.swift    app entry, scene phase, quick action routing
  AppLock.swift        Face ID / passcode gate and the privacy shade
  WebHost.swift        the WKWebView, navigation policy, share sheet, Files picker
  NativeBridge.swift   the one message channel, and the script injected into the page
  Info.plist           quick actions, launch screen, Files exposure
index.html             the dashboard itself — copied into the bundle, not a duplicate
```

The Xcode project references `index.html` at the repo root rather than a copy, so there is no
sync step.

## Running it

Open `FinSight.xcodeproj`, pick an iPhone (or a simulator), Run. Xcode 16+, iOS 17+. To install
on your own device, set a Team under Signing & Capabilities.

iPhone only, portrait only, dark. `TARGETED_DEVICE_FAMILY = 1`.

## Submitting it

What is in the repo:

- **`FinSight/PrivacyInfo.xcprivacy`** — the privacy manifest, copied into the bundle by the
  Resources phase. It declares no collected data, no tracking, and one required-reason API:
  `UserDefaults` under `CA92.1`, for the single boolean saying whether the app lock is on. This
  is checked by App Store Connect before a human sees the build, so a missing one is an automated
  rejection rather than a review note. There are no third-party SDKs, so nothing else to declare.
- **`ITSAppUsesNonExemptEncryption` = false** in `Info.plist`. SHA-256 for the PIN and WebAuthn
  for Face ID are OS-provided standard cryptography, which is exempt. Answered once here rather
  than at every upload.
- **`privacy.html`** at the repo root, served from the same Pages site. That is the privacy policy
  URL App Store Connect asks for — required even for an app that collects nothing. The same words
  are a card in Settings. **Its contact address is a placeholder and must be replaced.**

What still has to be done outside the repo: screenshots, description, keywords, support URL,
privacy policy URL, and the age questionnaire. The App Privacy answer is *Data Not Collected*.

One line is worth writing in the App Review notes, because half of Guideline 2.1 rejections are
really reviewer-notes failures: **the second step of onboarding offers "Load demo data", which
fills every screen in two taps — no account, no credentials, nothing to send us.**

The judgement call at review is Guideline 4.2, which exists to reject a web view with an icon on
it. The answer is the native layer above: a Face ID gate that runs before the dashboard loads, the
app-switcher shade, Home Screen quick actions, share-sheet export, Files import, haptics, and no
white screen because the page is in the bundle.

## Security

The same posture as the web version, plus what the platform adds.

- **Nothing leaves the device.** The page's Content-Security-Policy sets `connect-src 'none'`, so
  an outbound request is refused by the browser engine. The app holds no network entitlement.
  The web view is confined to `file:` and `about:` — a tapped link opens in Safari, and a remote
  address the page navigated to itself is refused, because a remote page wearing the app's chrome
  with no address bar to contradict it is a good place to ask somebody for a PIN.
- **Files it opens are treated as hostile.** A payslip PDF is parsed with pdf.js's `eval` path
  disabled (`isEvalSupported: false`, the mitigation for CVE-2024-4367). A restored backup is
  copied key by key onto a fresh state, so it cannot introduce keys the app does not have or name
  `__proto__` to reach a prototype. Nothing over 32 MB is read at all.
- **Exports leave the lock behind.** A backup is made to travel, and the salt plus the hash of a
  four-digit PIN in one file is not a hash, it is the PIN.
- **The lock is a screen, not a safe.** Data in the app container is not encrypted. What the gate
  stops is the person holding your unlocked phone, which is the threat that actually happens.

## What it tracks

Current accounts, savings, pots, credit cards and cash ISAs under **Accounts**. Stocks & Shares
ISAs, general investing, bonds and crypto under **Investments** — a broker like Trading 212 is a
name you give an account, not a kind of account. **Mortgage** takes what you owe, the rate and the
term and works out the payment, the interest split, when it clears and what an overpayment saves.
**Goals** holds your targets; **Strategies** holds the rules of thumb and the debt payoff model,
which takes each card's rate, how you pay it and any 0% window.

Five tabs: Home, Budget, Goals, Strategies, and Menu for everything else.

## Files it will open

A **payslip PDF**, which it reads the figures off for you to check, and its own **JSON backup**.
That is the list. Accounts, balances and spending are typed in, which is why what the app holds is
always what you told it rather than what a parser guessed.
