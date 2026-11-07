# Meditation — competitive survey and feature spec

**Status:** proposal, August 2026. Written against the `MeditationKit` scaffold on
`revamp/design` (`MeditationStyle`, `MeditationScreen`, `MeditationSessionCreatorScreen`).

This document does two things: it records what the meditation apps people actually
use ship today, and then argues for a specific, much smaller feature set for
PhayarSar. The second half matters more than the first. Most of what the category
does is unavailable to a solo developer and wrong for this app anyway.

---

## 1. The landscape

### 1.1 Where the money and the users are

| App | The bet it makes | Library | Unguided timer | Free tier | Price |
| --- | --- | --- | --- | --- | --- |
| **Insight Timer** | Volume + community. 250k+ sessions, 17k+ teachers, hourly live events, groups. | Enormous | Yes — the app is *named* after it. Interval bells, ambient sound, custom durations. | Genuinely large, no ads | $59.99/yr |
| **Calm** | Relaxation and sleep, celebrity-narrated. Sleep Stories are the franchise. | Large | Minimal | Thin | $69.99/yr |
| **Headspace** | Structured curriculum. Courses, animation, education-first. | 500+ guided, course-shaped | Minimal | Thin | $69.99/yr |
| **Balance** | Adaptive personalisation. 10-day plans that adjust to skill and frequency. | Medium | Some | 1-year free trial | $69.99/yr |
| **Waking Up** | Theory *and* practice. 28-day intro course, daily meditation, philosophy, plus a plain timer up to 2h. | Medium | Yes | Free on request | Subscription |
| **Ten Percent Happier** | Secular teachers, 500+ guided, sceptic-friendly framing. | Large | Some | Thin | Subscription |
| **buddhify** | Meditations indexed by *what you're doing* (commuting, can't sleep, work break) rather than by topic. 200+. | Medium | No | — | One-time purchase |
| **Oak** | Free, small, tasteful. Breathing (box, deep calm, awake) with animation, unguided up to 24h, ambient sound bank. | Small | Yes | All of it | Free |
| **Medito** | Nonprofit, open source, no account, no ads, no premium tier. Courses, dailies, sleep, breathing, SOS. Offline downloads. | Medium | Yes | All of it | Free forever |
| **Plum Village** | A monastery's own app. 100+ guided, 300+ talks, and the **Bell of Mindfulness** — random or scheduled bells through the day. | Medium | Yes | All of it | Free |
| **Vipassana / Ensō / Timefully / Center** | Timer only. Warm-up and cool-down phases, interval bells, bell *selection* (singing bowl, gong, temple bell), one strike to open and three to close, haptics, Live Activity, streaks. | None | The whole app | Mostly | Small or free |

### 1.2 The feature taxonomy

Everything above decomposes into these. Ticks are what PhayarSar should build; see §3.

**Timer (the unguided sit)**
- Duration presets and a custom picker; open-ended sits; long ceilings (2h–24h)
- Preparation / warm-up phase before the clock starts, cool-down after
- Interval bells at fixed spacing or at named points
- Bell selection — singing bowl, gong, temple bell, prayer bowl — with volume
- Convention: one strike to open, three to close
- Silent mode, haptics-only mode, haptic intensity (Apple's Mindfulness offers None / Minimal / Prominent)
- Ambient background audio during the sit

**Guided content**
- Courses and progressive plans; a daily; SOS / emergency sessions; sleep; kids
- Teacher libraries; talks and Q&As; theory separated from practice (Waking Up's structural idea)
- Indexing by *situation* rather than topic (buddhify's idea)
- Offline download

**Breathwork**
- Animated pacers — box breathing, 4-7-8 — with configurable breath rate and haptics on the inhale/exhale boundary

**Tracking**
- Session history, total minutes, streaks
- Mood check-in before and after a sit
- HealthKit `mindfulSession` write (this is the one integration users notice missing)
- Notes / journalling on a session

**Reminders**
- Scheduled daily reminder
- Plum Village's **random bell within a window** — the only genuinely novel reminder design in the category
- Quiet hours

**Platform surface**
- Apple Watch app; heart rate during and after the session
- Live Activity + Dynamic Island for the running timer
- Home screen widgets, StandBy, Control Center controls, Lock Screen controls
- Background audio with lock screen / Control Centre transport
- App Intents and Shortcuts, Focus filters
- Offline-first

**Social**
- Groups, live events, friend activity, leaderboards

**Business**
- Subscription with a 7-day trial is the category default; ~$5–10/mo, ~$30–70/yr. Onboarding is where trials start — almost all of them start on install day.
- The counter-position (Medito, Plum Village, Oak) is free forever, no account, funded by donation or by nothing.

### 1.3 What the Burmese / Theravada apps do

This is the neighbourhood PhayarSar actually lives in, and it is thin.

- **Dhamma Payeik** — an *Anapana exercise*: guided breathing with bell cues and a completion summary. Also a **live prayer counter** showing how many people are praying right now, a mini player, bookmarks and favourites.
- **Myanmar Dhamma** — Burmese-script Pali with Myanmar translation, audio with background play and lock-screen transport, read-only / listen-only / both modes.
- **iDhamma** — Sayadaw audio kept specifically so users get Pali pronunciation right.
- **Mala counters** (Mantra Mala, Japa-Mala, iMala) — tap-to-count beads, automatic rounds of 108.
- Nothing in this group ships: a real unguided timer with bell selection, a watch app, HealthKit, Live Activities, sync, or a considered visual design.

### 1.4 The one thing to not copy

Streaks. The research on them is consistent and unkind: loss aversion means breaking a streak hurts more than extending one rewards, so a long streak converts from motivation into dread, and one missed day becomes a reason to delete the app. For a *meditation* app the failure is sharper than usual — the app adds guilt to whatever the user already came in carrying. For a Buddhist app it is close to a category error.

The fix is well understood: count what happened, never count what didn't. See §3.6.

---

## 2. What PhayarSar is, and what follows from it

PhayarSar is a Burmese Buddhist prayer app with a reader, a watch remote, Live Activities, CloudKit sync and full Burmese/English localisation already built. The meditation tab is not a new app; it is a second thing the existing machinery can do.

Three constraints decide the whole spec:

1. **There is no content library and there will not be one.** Recording, licensing and hosting hundreds of guided sessions is a full-time content operation. Competing with Insight Timer's 250,000 sessions is not a plan.
2. **The differentiator is already in the scaffold.** `MeditationStyle`'s doc comment is the product thesis: *"the incense stick burns down, the candle gutters"* — a style is a screen, not a row of JSON. Nobody else ships a timer whose face is a burning incense stick. Every timer app in §1.1 shows a ring or a number.
3. **The practice frame is Theravada, and specifically Burmese.** Sitting and walking alternated in the Mahasi manner, anapana and metta as named practices, precepts before and sharing of merit after, the uposatha calendar. No app in §1.1 has any of this, and the apps in §1.3 have the vocabulary but none of the craft.

So the position is: **the best-made unguided sit in the Burmese tradition, on the best-integrated Apple platform surface in the category.** Depth on the timer, depth on the practice frame, zero content library.

---

## 3. The spec

### 3.1 v1 — the sit

The minimum that makes the tab real.

- **Style selection** — the existing swipe-through creator. `incenseStick` and `candleStick` ship; each is a full-screen field with its own tint (`AppColor.Meditation.*`).
- **Duration** — presets (5 / 10 / 15 / 20 / 30 / 45 / 60) plus a custom picker, and **open-ended** (count up, no end bell until stopped). Ceiling of 2 hours for the fixed case.
- **The burning object as the progress indicator.** The stick shortens; the candle's wax drops. This is the timer UI — a numeric readout is secondary and should be dimmable or hideable, because watching the clock is the thing practitioners are trying to stop doing.
- **Preparation phase** — a settle-in interval (0 / 15s / 30s / 1m) before the clock starts, closed by the opening bell. Every serious timer app has this and it is cheap.
- **Bells** — a small, well-recorded set. A Burmese temple bell (ခေါင်းလောင်း) and a singing bowl at minimum. **One strike to open, three to close** as the default, both configurable. Volume control. Bells must be recorded, not synthesised; this is the single most-judged asset in a timer app.
- **Interval bells** — every N minutes, or at explicit offsets.
- **Silent and haptics-only modes**, with a None / Minimal / Prominent haptic setting mirroring Apple's Mindfulness vocabulary.
- **Background audio and screen behaviour** — the session must survive lock and backgrounding, keep the audio session alive, and hold the screen awake when the user wants to watch the object burn.
- **A completion screen** — duration, style, and the option to dedicate. Not a score.
- **Session persistence** — a `MeditationSession` KloudKit entity so history and sync come free.

### 3.2 v1 — the practice frame

This is the part no competitor has, and it is mostly text and timing, not content production.

- **Precepts before the sit** (ငါးပါးသီလ) — an optional opening step: the five precepts in Pali with Burmese and English, tappable to acknowledge. Off by default, one toggle to make it part of every sit.
- **Dedication of merit after** (အမျှဝေ) — the closing counterpart on the completion screen. A short recitation, and a tap to share.
- **Named practices** — the session is labelled as **anapana**, **vipassana** (body sweep / noting), or **metta**, purely as framing and history. No audio needed for v1; a line of text at the top of the sit is enough. If guided audio ever arrives, these are the slots it drops into.
- **Sitting and walking alternated** — a session can be composed of segments: 30 sit / 10 walk / 30 sit, with a bell at each transition. This is how Burmese retreat practice is actually structured and *no mainstream app supports it*. It is a small extension of the interval-bell code and it is the most defensible feature in this document.

### 3.3 v1 — platform integration

All of this reuses machinery the app already has, which is why it belongs in v1 rather than later.

- **Live Activity + Dynamic Island** for the running sit — remaining time, style, stop. `ActivitiesKit` already holds `PrayerReadingAttributes`; this is a second attributes type in the same dependency-free module. Same rule as the reader: iOS hides it while the app is frontmost, so the in-app equivalent is a `PrayerIslandBar` sibling.
- **Apple Watch** — start, stop, remaining time, and the bell as a haptic on the wrist. `RemoteLink` and `WristRuntimeSession` already exist; the `.mindfulness` extended runtime session it takes is *literally* the right session type for this. A `MeditationRemoteState` alongside `PrayerRemoteState`, kept just as small.
- **HealthKit** — write an `HKCategorySample` of type `.mindfulSession` for every completed sit. Read authorisation is not needed. This is roughly forty lines and it is the integration users complain about most when it is missing.
- **Widgets and Control Center** — a "start a sit" control and a small widget showing this week's sits.
- **App Intents / Shortcuts** — "start a 20 minute sit" from Siri, and an automation hook so a sit can be tied to an alarm or a Focus.
- **Offline by definition.** Bells are bundled. Nothing here needs a network.

### 3.4 v1 — reminders

- A scheduled daily reminder with quiet hours.
- **The bell of mindfulness.** Plum Village's design: a bell at random intervals inside a window the user sets (say 9am–6pm, four times). It is the best idea in the category, it costs a local notification schedule, and it fits a Burmese Buddhist app better than it fits a Zen one.
- Optional: a bell on **uposatha days** (ဥပုသ်နေ့) from the Burmese lunar calendar. This requires a calendar computation, so it may slip to v1.1 — but it is the kind of detail that makes Burmese users trust the app.

### 3.5 v1.1 and beyond

Ordered by value, not by effort.

1. **A third and fourth style.** The scaffold's whole design is that a style is a screen; the tab gets more interesting per style than per feature. Candidates: an oil lamp, a water bowl, a lotus opening, a sand-filled hourglass. Each needs artwork.
2. **Uposatha and lunar-calendar awareness** if it didn't make v1 — full moon and new moon days surfaced in the tab.
3. **Mala / bead counter** (ပုတီး) — tap or crown-turn to count, rounds of 108, held as its own session type. The Watch's Digital Crown with detents is a genuinely better bead than a touchscreen, and that is a real reason for it to exist here rather than in the four Android apps that already do it.
4. **A guided anapana**, one session, recorded well in Burmese, in the style of Dhamma Payeik's — bell cues and a completion summary. One good session is worth more than a thin library, and it is a bounded piece of content work.
5. **Ambient sound during the sit** — rain, a monastery courtyard, forest at night. Small bundled loops, not a streaming bank.
6. **Breath pacer** — an animated inhale/exhale guide with configurable rate and boundary haptics, as a distinct style rather than a mode.
7. **Mood check-in** before and after, if and only if the history screen does something honest with it.
8. **Sayadaw talks** — if talks ever ship, they belong beside the prayers, not inside the sit.

### 3.6 Tracking, done without the guilt

Explicitly rejecting the category default here.

- **Count totals, not streaks.** Lifetime sits, lifetime hours, sits this month. All monotonically increasing, none resettable by a missed day.
- **A calendar of what happened.** Filled days, empty days left plain. No red, no "broken", no "you lost your 40-day streak".
- **No push notification that references a lapse.** Reminders say what to do, never what wasn't done.
- **No leaderboards, no social feed, no friend activity.** Merit is not a leaderboard.
- If a streak number ever ships, it is opt-in from Settings and it never appears in a notification.

The one aggregate worth showing prominently is **total hours sat**, which only ever goes up and is the number a practitioner in this tradition would actually care about.

### 3.7 Explicitly not building

- A guided content library of any size, celebrity narration, sleep stories, kids' content.
- Live events, groups, community, chat.
- Adaptive/personalised plans (Balance's model) — needs a content library to adapt *over*.
- Mood/CBT tooling, journalling beyond a one-line note.
- Anything requiring an account beyond what `AuthManager` already does.

### 3.8 Business model

Given §2, the subscription playbook in §1.2 does not fit — there is no recurring content to justify recurring payment, and a paywall on a prayer app has a cultural problem that the Medito/Plum Village end of the market has already answered.

Recommendation: **free, with a tip jar or an optional one-time unlock for extra styles and bells.** The competitive set that resembles PhayarSar (Medito, Plum Village, Oak, the Burmese dhamma apps) is uniformly free, and dāna is a better frame for this app than a 7-day trial. If a paid tier is ever wanted, sell *styles* — they are the thing that costs real artwork to make, and users can see exactly what they are buying.

---

## 4. Architecture notes

Where each piece lands, so the spec is buildable without re-deciding.

| Piece | Home |
| --- | --- |
| `MeditationStyle`, session engine, screens | `MeditationKit` |
| `MeditationSession` entity + `KloudEntity` conformance | `MeditationKit`, registered in the app target's `KloudSchema` |
| Bells, haptic settings, styles' artwork | `MeditationKit` resources; tokens and any shared components in `DesignKit` |
| `.meditationSession(...)` route, creator sheet | `EnvironmentKit` — `RouterDestination` / `SheetDestination` |
| Live Activity attributes | `ActivitiesKit`, kept dependency-free like `PrayerReadingAttributes` |
| Watch remote state + commands | `RemoteKit` (`MeditationRemoteState`), rendered in `WristKit` |
| HealthKit write | New thin `HealthKit` surface — either a small module or an `#if os(iOS)` file in `MeditationKit`. Do not pull HealthKit into anything the widget extension links. |
| Every user-facing string | `strings.json`, both `En` and `Mm` |

Two things to watch:

- **The Live Activity rule from the reader applies here.** iOS hides an app's own Live Activity while it is frontmost, so the in-app session UI and the Live Activity are two drawings of the same state that can never both be visible. Build them as siblings the way `PrayerIslandBar` and `PrayerReadingAttributes` are.
- **`WristKit` still cannot import `LocalisationKit`.** Any meditation string the watch shows either joins `WristStrings` by hand or rides across in the remote state, the way `PrayerRemoteState.language` already does.

---

## 5. Open questions

1. **How many styles ship at v1?** Two are scaffolded. The tab's appeal scales with styles, but each is bespoke artwork and animation — is there illustration capacity, or does v1 ship two and lean on the practice frame instead?
2. **Segmented sit-and-walk in v1 or v1.1?** It is the most defensible feature here and technically cheap, but it complicates the creator's UI, which is currently one screen per style with nothing else on it.
3. **Does the sit belong to a style, or does a style belong to a sit?** Right now the creator picks a style and starts. If sessions are ever saved and repeated ("my morning 30"), the model inverts — a saved session that references a style. Worth deciding before `MeditationSession` is written, because it is a schema decision.
4. **Guided anapana: record it, or stay unguided forever?** Staying unguided is coherent and cheap. One well-recorded Burmese anapana is a real differentiator against every English-language app. It is the only content question that matters.
5. **Free, or paid styles?** §3.8 recommends free with optional dāna, but this is the user's call and it changes onboarding.

---

## Sources

Insight Timer: [ChoosingTherapy review](https://www.choosingtherapy.com/insight-timer-review/), [Mindkindly](https://www.mindkindly.com/articles/insight-timer-review), [Google Play](https://play.google.com/store/apps/details?id=com.spotlightsix.zentimerlite2&hl=en_US) ·
Calm / Headspace / Balance: [CarePaths](https://carepaths.com/calm-app-vs-headspace/), [ChoosingTherapy — Balance](https://www.choosingtherapy.com/balance-meditation-app-review/), [Declutter The Mind](https://declutterthemind.com/blog/best-meditation-apps) ·
Waking Up: [App Store](https://apps.apple.com/us/app/waking-up-guided-meditation/id1307736395), [mindful.technology review](https://mindful.technology/waking-up-app-review/) ·
Plum Village: [plumvillage.org](https://plumvillage.org/mindfulness/mindful-apps), [Bell of Mindfulness](https://plumvillage.app/how-and-why-to-use-the-mindfulness-bell-on-the-plum-village-app/) ·
Medito: [Medito Foundation](https://meditofoundation.org/blog/meditation-apps-free-nonprofit-open-source/), [Selfpause](https://www.selfpause.com/resources/medito) ·
Oak / buddhify / Ten Percent Happier: [TidBITS on Oak](https://tidbits.com/2022/09/23/meditate-for-free-with-the-oak-app/), [HP Tech Takes roundup](https://www.hp.com/us-en/shop/tech-takes/best-meditation-apps) ·
Timer apps: [Ensō](https://apps.apple.com/app/ens%C5%8D-meditation-timer-bell/id840637879), [Timefully](https://www.timefully.co/vipassana-meditation-timer), [Vipassana Meditation & Timer](https://apps.apple.com/us/app/vipassana-meditation-timer/id6759205295), [Center](https://apps.apple.com/us/app/center-meditation-timer/id1332483673) ·
Burmese apps: [Myanmar Dhamma](https://apps.apple.com/us/app/myanmar-dhamma/id1439010576), [Dhamma Payeik](https://apps.apple.com/sg/app/dhamma-payeik/id1447765879), [iDhamma](https://apps.apple.com/sg/app/idhamma/id420570850), [Mantra Mala](https://play.google.com/store/apps/details?id=com.riwoche.mantramala&hl=en_US) ·
Apple platform: [Mindfulness on Apple Watch](https://support.apple.com/guide/watch/start-a-reflect-or-breathe-session-apd371dfe3d7/watchos), [HealthKit mindful minutes](https://medium.com/@alfadlimaulana/working-with-healthkit-mindful-minutes-data-fefd6599f790) ·
Streaks: [Yu-kai Chou on streak design](https://yukaichou.com/gamification-analysis/streak-design-gamification-motivation-burnout/), [NerdSip](https://nerdsip.com/blog/gamification-gone-wrong-when-streaks-become-the-point) ·
Monetisation: [Indie iOS monetisation guide](https://theswiftk.it.com/blog/how-to-monetize-ios-app-indie-developer)
