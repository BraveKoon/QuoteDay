# QuoteDay

*[한국어](README.md) · **English***

An iOS app that ties a daily quote to your schedule. Add an event and, at that time, a
notification arrives carrying **a quote that fits the event's category**. Tap the
notification or a home-screen widget and you land directly on the quote detail and the
person behind it. Events can **repeat** (daily / weekdays / weekly / biweekly / monthly / yearly).

The UI keeps its pastel palette but drops gradients and blur — flat surfaces and thin
lines only.

- Swift 5 / SwiftUI / SwiftData / WidgetKit / AppIntents / UserNotifications / EventKit
- Minimum version: **iOS 17.0**
- Quote and author data ship in the bundle, so **every feature works with no network**
- The quote of the day can optionally refresh from [ZenQuotes](https://zenquotes.io/) `/today` (turn it off and the app is fully offline)
- Per-version changes live in [CHANGELOG.md](CHANGELOG.md)
- **No ads.** Revenue comes from exactly one place: the **Quote Plus** paid plan (StoreKit 2)
- Quote **hearts** are tallied across every user through the CloudKit public database (no sign-up)

---

## 1. Open and run

```bash
open QuoteDay.xcodeproj
```

Open it in Xcode 15 or later. Two settings and it runs.

1. **Pick a signing team** — under Signing & Capabilities for both the `QuoteDay` and
   `QuoteDayWidgetExtension` targets.
2. **App Group** — both targets already carry `group.com.quoteday.app` in their
   entitlements. A personal account may not be allowed to use that identifier; if so,
   change it to your own and change `AppGroup.identifier` in
   `Shared/Services/SharedStore.swift` to match.
   (The app still runs without an App Group. The widget just won't show your events —
   see "Failing safely" below.)

**Heart sync (CloudKit) ships turned off.** Leave it that way and hearts stay on the
device while everything else works. See "Turning heart sync on" below to enable it.

To regenerate the project file, either way works:

```bash
python tools/generate_xcodeproj.py   # anywhere, macOS or Windows
xcodegen generate                    # if you have brew install xcodegen
```

---

## 2. Screens

| Tab | What's there |
|---|---|
| 🏠 Home | Today's date, the quote of the day (large card), time until the next event, today's schedule |
| 📅 Calendar | Monthly grid (days with events get a category-colored dot), the selected day's events, iOS Calendar events |
| 💬 Quotes | Search across all quotes + category filter, with a heart and a card button per quote |
| 🏆 Challenge | Quote quiz. 2 modes × 5 difficulty levels, 10 questions per round, best score per level, and ranking |
| ⚙️ Settings | Notifications / daily quote / default category / appearance / calendar sync / widget guide / about |

Quote detail opens as a sheet: portrait, birth and death years, occupation, nationality,
biography, notable achievements, and the person's other quotes.

---

## 3. Layout

```
QuoteDay/
├── Shared/              Code the app and the widget both use
│   ├── Models/          AppCategory, Quote, Author, DeepLink, WidgetSnapshot, StableHash
│   │                    ChallengeMode/Difficulty, ChallengeQuestion (quiz value types)
│   │                    HeartSnapshot (total count + whether I tapped it)
│   │                    ChallengeScore / RankBucket / RankStanding (points and rank)
│   ├── Data/            QuoteLibrary (index) + QuoteLibraryData (201 quotes) + AuthorLibrary (116 people)
│   │                    BehindStoryLibrary (41) + DisputedAttribution (30 unverified attributions)
│   ├── Services/        QuoteService (selection), RemoteQuoteService (ZenQuotes), SharedStore
│   │                    ChallengeGenerator (question building) + BlankMaker (Korean word blanks)
│   │                    HeartSyncing · RankSyncing (sync protocols) + CloudKitConfiguration
│   ├── Design/          ClayTheme (color and size tokens) + ClayStyle (.clayCard/.clayButton/.clayBackground)
│   ├── Support/         Formatters
│   └── AppIntents/      Widget configuration intent
├── App/
│   ├── Models/          ScheduleItem (SwiftData @Model) + ScheduleValidator
│   │                    ShareCardDesign (card background, note)
│   │                    RecurrenceRule (rules and occurrence math) + ScheduleOccurrence
│   │                    QuoteNote (journaling note, @Model)
│   ├── Services/        Persistence, ScheduleStore, NotificationService, CalendarService, AppSettings
│   │                    PlusStore (purchase state), NoteStore, QuoteCardRenderer, NotePDFExporter
│   │                    ChallengeSession (one round) + ChallengeStore (records per level)
│   │                    HeartStore (local state + pending queue) + CloudKitHeartService
│   │                    RankStore + CloudKitRankService (rank from bucket counts)
│   ├── ViewModels/      HomeViewModel, CalendarViewModel
│   ├── Components/      QuoteCard, CategoryChip, RecurrencePicker, ScheduleRow, CalendarDayCell,
│   │                    AuthorPortrait, EmptyState, HeartButton
│   └── Views/           Home / Calendar / Schedule / Quote / Notes / Plus / Challenge /
│                         Settings / RootTabView
├── Widget/              Home screen (Small·Medium·Large) + lock screen (accessory) widgets
├── Tests/               194 XCTest cases
└── tools/               Project generator + static checker + CHANGELOG section extractor
```

Views never touch the SwiftData context directly. Every write goes through `ScheduleStore`,
where saving → rescheduling notifications → refreshing the widget snapshot → (if enabled)
mirroring to iOS Calendar all happen in one place.

---

## 4. How it works

### Quote Plus — what gets sold instead of ads
> **Sales are currently switched off.** `AppFeatureFlags.isPlusEnabled` is `false`, so
> every Plus feature in the table below is **open for free**, the paywall, purchase buttons
> and PLUS badges never appear, and StoreKit is never called at all.
> Locking features you have no way to buy leaves the user staring at a lock that cannot
> be opened. To start selling, flip that value to `true` and register the
> `PlusStore.ProductID` products in App Store Connect. The code stays as it is; only the
> switch moves.

No ad SDK. No banners, no interstitials, no tracking. What gets sold is **depth of
content**. With sales on, the line falls here:

| | Free | Quote Plus |
|---|---|---|
| Quote text, author name, portrait | ○ | ○ |
| All events, notifications, widgets | ○ | ○ |
| **Writing and reading** notes | ○ | ○ |
| Sharing an image card | ○ | ○ |
| Card themes | 2 | 6 + serif |
| Author profile (life, era, achievements) | ✕ | ○ |
| Behind-the-quote story | ✕ | ○ |
| Related works and people | ✕ | ○ |
| Exporting notes to PDF | ✕ | ○ |

Four principles, enforced in code.

1. **What you wrote is never locked.** Notes stay readable and writable even after a
   subscription lapses. What's for sale is a way to get them *out* (PDF), not the right to
   reach your own record.
2. **No paywall over content that doesn't exist.** A quote with no behind-the-quote story
   shows "not ready yet" (`ComingSoonCard`) instead of a lock card. Only quotes that
   actually have one get locked.
3. **One place decides what's locked.** Views only ever ask
   `PlusStore.isUnlocked(_ feature:)`. Counting `PlusFeature` tells you how many paid
   features exist, straight from the code.
4. **"Unlocked" and "for sale" are separate questions.** `isUnlocked(_:)` answers the
   first; `isStoreVisible` answers the second. With sales off, the first is true and the
   second is false.

`PlusStore` manages purchase state with StoreKit 2 — entitlements from
`Transaction.currentEntitlements`, and `Transaction.updates` to follow changes that happen
outside the app (Family Sharing approval, refunds, a purchase on another device). If the
store can't be reached the app doesn't stall; it runs as a free user. DEBUG builds get a
toggle in Settings that **opens the paid screens without paying**.

**Locked content is laid down blurred with a note underneath** (`PlusLockedPreview`).
Blurred text isn't there to be read — it signals that there's substance and length behind
it — so three things hold together: it can't be tapped (`allowsHitTesting(false)`),
VoiceOver skips it (`accessibilityHidden`), and anyone with Reduce Transparency on gets a
solid fill instead of a blur.

Subscriptions run **only through App Store in-app purchase** (monthly · yearly · lifetime).
Donations (Toss bank transfer / Buy Me a Coffee) are separate and **unlock nothing**.
Taking outside payment in exchange for features violates App Store policy, so donations
stay pure encouragement. The account number is copy-on-tap information, not a link.

### Why there are 41 behind-the-quote stories, not 201
Background notes are the easiest kind of writing to invent convincingly. Put in an
unverified anecdote and the app quietly starts teaching false history. So
`BehindStoryLibrary` has rules.

- Never leave `source` empty — date and place for a speech, title and year for a text.
- No story for a quote whose attribution is disputed.
- If you couldn't verify it, leave it blank. The UI treats a quote with no story as normal.

There are **41** right now. Each one can be pinned to a specific book, letter, speech, or
broadcast — Beethoven's letter to Wegeler of 16 November 1801, Book 5 §1 of Marcus
Aurelius' *Meditations*, Nike's 1997 "Failure" commercial. The other 89 are blank, and the
UI treats that as normal.

Checking also meant **deliberately leaving some out**. There is no record of Churchill
saying "Success is not final, failure is not fatal"; the earliest form traced is a 1938
Budweiser newspaper advertisement. Marie Curie's "Nothing in life is to be feared" has no
source confirmed before 1952. Thirty quotes like these are collected in
`DisputedAttribution.slugs`.

### Unverified attributions (`DisputedAttribution`)
Misattribution is the most common way a quote collection quietly teaches false history.
The Challenge's "who said it" mode is the sharp case: it pins a single answer, so putting
these quotes in it would have the app teach an unverified attribution as fact. They are
excluded from that mode only.

**The quotes themselves are not removed.** Nothing is wrong with the sentence; only the
label is uncertain, and "fill in the blank" — which never asks who said it — can use them
as they are. The bar for the list is one thing: **no primary source found.** When a source
turns up, remove it from the list and write the story.

### How hearts are counted
Any quote can be hearted, and the number under the heart is the **total across every user**.
This is the first write-capable backend QuoteDay has, and it runs on the CloudKit **public
database** — no server to operate, and people are told apart by their iCloud account with
no sign-up of their own.

**It never issues a query.** Record names are derived deterministically from the values:

    one heart   QuoteHeart       "<quote slug>|<my user record name>"
    the tally   QuoteHeartTally  "tally|<quote slug>"

So every read is a fetch by ID (`records(for:)`). Using a CloudKit query means turning on
an index per field in the dashboard, and forgetting that setting leaves an app that builds
fine, runs fine, and then fails silently **only on a real device**. Going through IDs
removes that trap entirely. It also means one person cannot heart the same quote twice —
the record name would be identical.

**The screen never waits on the network.** Tapping a heart fills it in and bumps the number
right there. The server write happens behind it, and a failure does **not** roll it back —
it stays queued for the next attempt. Undoing a tap because the network failed makes the
user's action vanish for no reason they can see. In the other direction, freshly fetched
server values **never overwrite something still queued**, which is what stops a heart you
just tapped from visibly un-filling itself.

**About accuracy, plainly.** CloudKit has no atomic increment. The tally record is read,
modified and written back; if someone else writes first, `serverRecordChanged` comes back
and it retries. With enough simultaneous taps a few can be lost. That is an acceptable
error for a heart count, and removing it would mean running a server.

**Hearts work without sync too.** With no iCloud account, or in a build where CloudKit
isn't configured, hearts stay on the device and one line on screen says why. A heart that
isn't counted beats a heart that does nothing when tapped.

The `HeartSyncing` protocol keeps this behind one seam. CloudKit can't be verified in the
simulator or in CI, so tests run against a fake, and swapping the backend later leaves the
screens untouched.

### Turning heart sync on
It ships **off**. Without it hearts still work; the number just counts your own, and one
line on screen explains why they stay on this device.

Turning it on needs a **paid Apple Developer Program membership ($99/year)**. A personal
(free) team cannot use the iCloud capability, and merely declaring it in the entitlements
stops a provisioning profile from being created at all — **the build fails outright**.

    Personal development teams do not support the iCloud capability.

That is why enabling it is opt-in. With a paid account, three steps:

1. Xcode → the `QuoteDay` target → **Signing & Capabilities → + Capability → iCloud**,
   tick **CloudKit**, and create the `iCloud.com.quoteday.app` container.
   (This step writes the iCloud keys into `App/Resources/QuoteDay.entitlements` for you.)
2. Put that container identifier in the **`QD_CLOUDKIT_CONTAINER`** build setting — edit
   `project.yml` and re-run `python tools/generate_xcodeproj.py`.
3. Before shipping, hit **Deploy Schema to Production** once in the CloudKit dashboard.
   Record types are created on first write, so there is no schema to author by hand.

`check_project.py` catches the two ways these drift: an identifier set but missing from the
entitlements, or sync switched off while an iCloud declaration lingers (the build failure
above).

### The share card
A quote becomes a 1080×1080 image you can **save to Photos** or share. It opens straight
from each quote in the Quotes tab, and from the quote detail.

| What you choose | |
|---|---|
| Background color | 8 swatches plus a free color picker. **Defaults to QuoteDay purple (`#5A64D8`)** |
| Photo | Pick one from the library as the background; 45% black goes over it so text stays legible |
| Your note | Up to 90 characters, set under the quote behind a vertical rule. Leave it empty and it doesn't appear |
| Preset | The existing 6 themes, serif included. Picking one steps over a color you chose |
| QuoteDay mark | At the bottom of the card. On by default |

**Text color is computed, not chosen.** Once people can pick any background, "black text on
dark purple" becomes a real failure. The background's WCAG relative luminance is measured
and, against a 0.179 threshold, either white or dark text wins on contrast. A test keeps
all 8 swatches readable.

The preview and the exported image are the **same view** (`QuoteShareCard`), handed a
different size — there is no room for "it came out different from the preview".

Saving asks for `.addOnly` permission. The app only ever puts photos in and never reads
them, so requesting the whole library would be asking for more than it needs.

### Challenge — what actually makes a level harder
A quote quiz, in two modes.

| Mode | The question |
|---|---|
| Fill in the blank | 1–2 words are removed from a quote; pick them from the choices |
| Who said it | Given only the sentence, pick the person |

Five knobs separate the levels, and **none of them work by telling you less.** All of them
work by lowering the odds of guessing right.

| Level | Points | Choices | Blanks | Hint | Where wrong answers come from | Time limit |
|---|---|---|---|---|---|---|
| 1 Beginner | 10 | 3 | 1 | Author's name | Anywhere, at random | — |
| 2 Normal | 20 | 4 | 1 | Author's name | Quotes on the same topic | — |
| 3 Hard | 35 | 4 | 1 | None | Same author · similar length | — |
| 4 Very hard | 55 | 5 | 2 | None | Same author · similar length | 20s |
| 5 Extreme | 80 | 6 | 2 | None | Same author · similar length | 15s |

From level 4 there are two blanks, so each choice becomes a **pair** of words. Half the
wrong answers then differ from the correct one by a single word — `못하면 · 없다` sitting
next to `못하면 · 수도`.

**Every level is open from the start.** Gating them would force a march through the
material, and this app is not a workbook. Progress shows up as a best score per level
instead.

Two parts of the implementation are worth a look.

- **Splitting Korean words** (`BlankMaker`) — splitting by morpheme needs a dictionary, so
  a whole **eojeol** (whitespace-delimited word) is removed instead. Take only "인생" out
  of "인생은" and the leftover particle gives away half the answer. Quotes and periods on
  either side stay outside the blank.
- **Keeping distractor pools as separate arrays** (`ChallengeGenerator`) — candidate words
  must not be concatenated into one array. There are over 1,000 words in total, so the few
  dozen "same author" candidates prepended to the front have essentially zero chance of
  being drawn, and the difference between levels disappears entirely. Pools of different
  priority are kept as separate arrays and tried in order. (It was built the wrong way
  first, then fixed.)

Question generation is **deterministic**. The same seed produces the same question. Tests
can assert "this seed yields these choices" exactly, and the choices never reshuffle
themselves when the view redraws.

### Ranking — how points are counted and rank is derived
Every correct answer is worth its level's points (table above). They rise steeply for one
reason: **if grinding an easy level beats attempting a hard one, the ranking stops
measuring skill and starts measuring hours logged.** A perfect level 1 round is 100 points;
half of a level 5 round is 400. There is a reason to try the harder thing.

Your total is **the sum of your best score per mode and level, not a running tally**
(4,000 max). A running tally can be raised by replaying the same round, and that is time
spent, not skill. Best-per-level means replaying gains nothing while trying an untouched
level gains a lot.

#### How rank is counted
Giving every player a score record and **counting** them to derive a rank needs a filtered
query, and a CloudKit query needs a per-field index turned on in the dashboard. Forget that
setting and it fails silently, only on a real device — the same trap hearts avoid.

So the distribution is kept as **counts per 200-point bucket**.

    my score       ChallengePlayerScore  "<my user record name>"
    distribution   ChallengeRankBucket   "rank-bucket|<bucket index>"

There are only 21 buckets and their names are fixed, so they come back in **one fetch by
ID**. No query. Your exact position inside your own bucket is unknowable, so it is taken as
**the middle of the bucket** — the front would flatter you, the back would shortchange you.

That a higher score never ranks worse is guaranteed by the arithmetic: moving from bucket b
to b+1 changes rank by `-⌊counts[b+1]/2⌋ - ⌈counts[b]/2⌉ ≤ 0`. It was also checked against
3,000 random distributions.

**No rank is shown until 20 players exist.** One person in three being "top 33%" is a
number without a meaning; below that threshold it says so instead.

**No other player's name or score is ever shown.** The only thing worth knowing is where
you stand, and collecting more than that only adds something to protect.

With sync off, **the score still shows and only the rank is missing.** Hiding the score too
would leave you unable to see what you scored at all.

### Why surfaces are flat
No gradients, blur, or gloss. Depth comes from two things only.

- **Brightness** — background < card. The card is lighter than the background (less dark in
  dark mode), so it lifts on its own.
- **Lines** — card borders and dividers are the same 1px `separator` color.

Shadow goes on exactly one thing that genuinely floats above the screen: **the tab bar**.
Color only carries information — category pastels, the accent, the danger color. Never
decoration. Views never hardcode a color, only `ClayTheme` tokens, so changing the palette
moves the app and the widget together.

### Why the quote of the day isn't random
The app and the widget are **separate processes**. Randomness would have the home-screen
widget and the app show different quotes. So the index comes from hashing `"yyyy-MM-dd"`
with FNV-1a (`StableHash`). Swift's `Hasher` is seeded per process and can't be used here.
For the same reason each quote's `UUID` is derived deterministically from its slug —
notification deep links stay valid across reinstalls.

### Category → quote
`QuoteService.candidatePool(for:)` collects candidates in order: ① the category itself →
② widening through `AppCategory.related` → ③ everything, if still short. Below six
candidates the same quote keeps repeating, so related categories get pulled in. The final
pick is fixed by a seed of `event ID + start time`, so the announced quote doesn't change
until the event is edited.

### Recurring events
Occurrences are not duplicated into rows. One event stores only a **recurrence rule
(frequency + optional end date)**, and the occurrences for whatever range the screen needs
are computed on the spot by `RecurrenceRule.occurrenceStarts` (`ScheduleOccurrence`).
"Daily, no end date" costs the same to store as a single event, and editing the rule
cleans up past occurrences in one move.

- Frequencies: daily / weekdays (Mon–Fri) / weekly / every two weeks / monthly / yearly.
- Math is **always relative to the first occurrence**. A monthly event starting on the 31st
  pulls back to the 28th in February but returns to the 31st in March (computing from the
  previous occurrence would let the date drift forward and stay there).
- However far in the future the window sits, the first candidate position is skipped to by
  calculation, so a recurrence that started years ago still costs only as much as the
  window size.
- Each occurrence has its own seed, so **each one gets a different quote**. Pinning a quote
  in the editor makes every occurrence use it.
- Editing and deleting apply to the **whole recurrence**, not one occurrence (there are no
  per-occurrence exceptions).
- Exporting to iOS Calendar maps to `EKRecurrenceRule`, so it shows as recurring on the
  device calendar too.

### Quote-of-the-day source (ZenQuotes)
Turn it on in Settings (on by default) and the quote of the day comes from ZenQuotes
`/today`. Its **scope is deliberately narrow**.

- It applies **only to the quote of the day**. Category-matched event notifications keep
  using bundled data. The API response carries no category, so "study event → study quote"
  can't be built from it, and notifications scheduled 14 days ahead can't know a future
  day's API response.
- Widgets set to a specific category also use bundled quotes, for the same reason.
- The app and the widget each refresh the App Group cache. It fetches once a day, and after
  a failure won't retry within 15 minutes (the free tier allows 5 calls per 30 seconds).
- If the author name matches someone in the bundle, their dates, biography and achievements
  are attached. If not, the name alone is shown.
- **The English text is translated to Korean on device** (below). It can be turned off in Settings.
- A remote quote's UUID is derived from the sentence itself, so deep links stay valid after
  the day passes.
- Attribution is shown on the quote detail and in Settings, as the free tier requires.

#### Translating the English quote
ZenQuotes only returns English. To stop one English sentence sticking out of a Korean app,
it is translated with **Apple's on-device translation** (the Translation framework).

A translation API needs a key, and a key shipped in an app cannot be kept from anyone who
wants it. A server would have to be run. On-device translation needs **no key, no server,
no cost, and the sentence never leaves the device.**

Two costs come with it.

- **iOS 18 or later only.** That is where the programmatic translation API arrived (17.4
  only presents a system sheet). The app's deployment target stays at 17.0 — dropping
  existing users over one feature isn't worth it. On iOS 17 the English shows as before,
  and Settings says why.
- **It is machine translation.** Aphorisms are hard to translate well, so the English is
  kept underneath rather than replaced (`Quote.originalText` — the same slot bundled quotes
  use for their source text). If the Korean reads badly the original is right there, and
  turning the setting off brings back English only.

**Translating never changes the `slug` or the UUID.** Both derive from the English text, and
notification and widget deep links hold them; changing them would break every link.

The translation runs once, attached to the app's root view — one sentence a day is enough.
The result goes into the App Group cache, so **the widget shows the same Korean** once the
app has been opened. If the date rolls over to a different quote before the translation
finishes, that translation is discarded.

### Notifications
- Permission is requested **when the user turns quote notifications on**, not at launch.
- Event notification: one `UNCalendarNotificationTrigger` at the start time.
- Recurring events: each occurrence needs a different quote, so repeating triggers aren't
  used. Instead **up to 8 occurrences per event within 60 days** are scheduled ahead.
  iOS caps an app at 64 pending notifications, so event notifications fill only the
  nearest 40, refilled every time the app opens.
- Daily quote: a repeating trigger can't change its body, so **14 days are scheduled one
  day at a time** and refreshed on each launch.
- If the app goes unopened long enough to exhaust the schedule, `refreshOnLaunch()` rebuilds
  all of it.
- Notification tap → `quoteday://quote/<uuid>` in `userInfo` → `AppRouter` → quote detail.

### Widgets
- Home screen: Small (quote) / Medium (quote + person + category) / Large (quote + person +
  today's events + time remaining)
- Lock screen and StandBy: Inline (next event, one line) / Circular (event time) /
  Rectangular (quote + person). The system strips color from accessory families, so those
  drop surfaces and keep only contrast and information density.
- The widget **computes the quote itself** and reads only events from the App Group
  snapshot. With no snapshot, the quote still shows.
- Timeline: hourly until midnight, plus a midnight reload.
- Long-press a widget to pick a category (`SelectQuoteCategoryIntent`).
- Tapping opens the quote detail in the app via `widgetURL`.

### Failing safely
| Situation | Behavior |
|---|---|
| Notification permission denied | Event saves normally, a notice is shown, only scheduling is skipped |
| Calendar permission denied | In-app events work as usual, only that section is empty |
| App Group not configured | Falls back to `UserDefaults.standard`, warning shown in Settings |
| SwiftData store corrupted | Falls back local → in-memory (no crash) |
| Unknown stored category | Demoted to `.etc` |
| Unknown stored recurrence | Demoted to "no repeat" |
| Products can't be loaded | Runs as a free user, paywall explains why |
| Purchase verification fails | No entitlement granted, just a notice; the app keeps running |
| Stored card theme is premium but the subscription lapsed | Reverts to the default theme |
| Store from a version before the recurrence fields | Reads as the default (`none`), opens with no migration |
| Quote slug disappeared | Recomputed from the category |
| Stale deep link | "Quote not found" empty state |
| No network | Only the ZenQuotes refresh is skipped; bundled quotes are shown. Nothing else is affected |
| ZenQuotes quota exceeded | The notice text is rejected rather than stored as a quote; bundled quotes stay |
| Not signed in to iCloud | Hearts stay on the device, with one line on screen explaining why |
| CloudKit container not configured | No `CKContainer` is ever constructed (failable init); hearts stay local |
| A heart fails to upload | Not rolled back — queued and retried on the next launch |
| Photo access denied | The card still builds and shares; only saving is blocked, with an explanation |

---

## 5. Verification

There's a static check that runs anywhere, not just on macOS.

```bash
python tools/check_project.py
```

- Parses `project.pbxproj` directly to check structure, cross-references, and that files exist on disk
- Whether every Swift file is in the right target
- Bracket and quote balance
- **Target boundary violations** — fails if the widget references an app-only type (different modules, so it would be a real compile error)
- That there is exactly one `@main` per target
- That entitlements / Info.plist / App Group identifiers agree
- That the **CloudKit container identifier** matches in both Info.plist and the entitlements
  (fix one without the other and sync fails silently, only on a device)
- That the photo-add usage description exists (without it, saving crashes the app)
- That the app icon is 1024x1024 with no alpha channel (alpha gets rejected by the App Store)
- **That the version agrees in three places** — `MARKETING_VERSION` in `project.yml`, the
  newest entry in `CHANGELOG.md`, and the first entry of the generated `ReleaseHistory.swift`
  (see "One source for the version" below)

On macOS, additionally:

```bash
xcodebuild -scheme QuoteDay -destination 'platform=iOS Simulator,name=iPhone 15' build
xcodebuild -scheme QuoteDay -destination 'platform=iOS Simulator,name=iPhone 15' test
```

### CI (`.github/workflows/ci.yml`)
Runs on PRs and pushes to `main`, in two stages.

1. **Static checks** (Linux, free) — `check_project.py` plus a **project-file drift check**.
   Add or remove a file without re-running `generate_xcodeproj.py` and this fails.
2. **Build and test** (macOS) — only starts if stage 1 passed. macOS runners burn free
   minutes at 10× the rate, so a mistake that a cheap check would catch never gets to spin
   up an expensive runner. The simulator isn't hardcoded by name; `simctl` picks an
   available iPhone at run time.

The runner image is pinned to `macos-15`. When that label is eventually retired, bump it in
the workflow.

### Release automation (`.github/workflows/release.yml`)
On a merge to `main`, it reads `MARKETING_VERSION` from `project.yml` and, if that tag
doesn't exist yet, creates the tag and a GitHub Release. The notes come from the matching
section of `CHANGELOG.md`.

So releasing is **three lines inside a PR**.

1. Bump `MARKETING_VERSION` in `project.yml` and re-run `generate_xcodeproj.py`
2. Turn `## [Unreleased]` in `CHANGELOG.md` into a version and date, e.g. `## [1.8] - 2026-09-09`
3. Run `python tools/generate_release_history.py` to rebuild the in-app changelog
4. Merge → the tag and the release appear on their own

A merge that doesn't bump the version passes quietly, since the tag already exists.
Bumping the version without writing a CHANGELOG entry fails the release job on purpose —
that's the guard against an empty release. To preview the notes, run
`python tools/changelog_section.py 1.4`.

### One source for the version
If the version shown in the app disagrees with the GitHub release tag, nobody can tell which
build they are actually running. So there is one source, and everything else is derived.

```
CHANGELOG.md ──generate_release_history.py──▶ ReleaseHistory.swift  (Settings > Changelog)
      │
      └─ MARKETING_VERSION in project.yml ──▶ Info.plist ──▶ release.yml tags v<version>
                                                  │
                                                  └─▶ AppVersion.tag  (Settings > About)
```

- The "GitHub tag" row in the app is the bundle's `CFBundleShortVersionString` with a `v`
  in front. The release workflow tags the same value, so there is no path for them to differ.
- Both `Info.plist` files take `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` rather
  than a literal. v1.1 through v1.7.1 actually shipped with `1.0` baked in, so
  `check_project.py` now verifies the substitution is there.
- `Shared/Data/ReleaseHistory.swift` is **generated**. Don't edit it; edit `CHANGELOG.md`
  and regenerate.
- `check_project.py` fails CI when the three disagree, and a test separately checks that the
  running build is the newest entry in the changelog.
- The in-app changelog carries **top-level bullets only** — nested bullets and code blocks are
  dropped — so write each CHANGELOG entry so its first paragraph stands on its own. The screen
  links out to the GitHub release for the rest.

---

## 6. Data

- **201 quotes**, **116 people**. At least 12 per category (more once secondary categories count).
- **360 Korean spellings** for people outside the bundle (`ForeignNameLibrary`), used for the
  ZenQuotes quote of the day. Names are never handed to the translator — machine translation
  renders a person's name as its meaning. A name that is not in the table stays in English.
- Only sentences widely confirmed as coming from a real person; internet text of unclear
  origin was left out. The original wording (`originalText`) is included where available.
- **41** behind-the-quote stories (`BehindStoryLibrary`), and **30** quotes excluded from
  the "who said it" mode for unverified attribution (`DisputedAttribution`).
- To add a quote, put an entry in the right category array in
  `Shared/Data/QuoteLibraryData.swift`, and add the person to `AuthorLibrary.all` if they're
  new. `slug` must be unique across the whole set and must not change after release — deep
  links depend on it.
- To add a portrait, put the image in `Assets.xcassets` and fill in `portraitAssetName`.
  Without one, an initials placeholder is drawn.

## 7. Known limits

- No portrait images are included (licensing). Initials placeholders for now.
- iOS Calendar sync is **read + export** only. Edits made in the device calendar don't come
  back to the app.
- Recurring events have no "edit/delete just this occurrence". Skipping one means adjusting
  the recurrence end date.
- 41 of 201 quotes have a behind-the-quote story. The rest need their sources confirmed first.
- Challenge records themselves stay on this device; only one total and its bucket leave it.
- Ranking rides the same CloudKit switch as hearts. Off, the score shows and the rank does not.
- Rank is counted from buckets, so it is approximate — meaningful only at "top N%" resolution.
- Heart sync **ships off.** Turning it on needs a paid Apple Developer Program membership;
  a personal (free) team cannot use the iCloud capability at all. Left off, hearts are
  stored only on the device.
- Heart totals can lose a few taps under heavy concurrency (see "How hearts are counted").
- Un-hearting reaches the server immediately, but other people's screens only catch up the
  next time they open the app.
- The photo on a share card isn't kept. Close the sheet and you pick it again.
- The donation details in `SupportOption.all` are real values. Check twice before editing
  them — one wrong digit in an account number sends someone else the money.
- Product identifiers must be registered in App Store Connect before prices appear. Until
  then the paywall shows explanatory text only.
- There are six recurrence frequencies and no more (no arbitrary intervals like "every 3
  days", no rules like "the second Tuesday of each month").
- No Live Activity / Dynamic Island yet.
- There are no localization files. UI strings are hardcoded in Korean.
- Quote-of-the-day translation works only on iOS 18 or later; below that the English shows.
- It is machine translation, and does not match the quality of the 201 hand-translated bundled quotes.
- Only the 360 names in the spelling table are shown in Korean. ZenQuotes draws on a far larger
  cast, so anyone outside the table keeps their English name.
