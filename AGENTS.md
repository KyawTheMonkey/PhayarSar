# PhayarSar

A Burmese Buddhist prayer (ဘုရားစာ) app for iOS and watchOS. All meaningful code
lives in `PhayarSarLibrary/`, a SwiftPM package of 14 modules. The Xcode targets
(`PhayarSar`, `PhayarSarWatch`, `PhayarSarWidgets`,
`PhayarSarNotificationService`) are thin shells that link package products and
compose them — **document and work in the package, not the app target.**

> The current contents of `PhayarSar/` (the app target) are being deleted and
> rewritten. Do not treat anything there as a reference for conventions.

## Build & verify

```bash
cd PhayarSarLibrary
swift build                      # ~10s incremental; builds every module for macOS
swift build --target HomeKit     # one module
```

`swift build` is the fast feedback loop and catches almost everything. Modules
guarded by `#if os(iOS)` / `#if os(watchOS)` (ActivitiesKit's ActivityKit
surface, RemoteKit's `WatchConnectivity`, all of WristKit) compile to
near-nothing on macOS — verify those in Xcode against a simulator.

There are no automated tests. The user verifies changes by hand in the app.

## Module graph

Dependencies flow strictly downward; nothing below imports anything above it.

```
Features   AuthKit   HomeKit   PrayersKit   SettingsKit   MiscKit   WristKit
              │         │           │            │           │         │
Shell     ComponentKit  └───────────┴────────────┴───────────┘         │
              │                     │                                  │
Platform  EnvironmentKit ──────► DesignKit ──► UtilKit          RemoteKit
              │                                                  KloudKit
          LocalisationKit  (+ LocalisationKitCodeGen plugin)   ActivitiesKit
```

**Helper modules**

| Module | What it owns |
| --- | --- |
| `UtilKit` | `Color.dynamic`, `View` extensions, scroll-offset reading. No dependencies. |
| `DesignKit` | Design tokens (`AppColor`, `AppFont`, `Typography`, `ThemeSwitcher`) and every `App*` component. Bundles the fonts. |
| `LocalisationKit` | `LocalisationManager`, `Language`, and the generated `L10n` enum. |
| `EnvironmentKit` | `AppNavigatorModel`, `AppTab`, `RouterDestination`, `SheetDestination`. Re-exports LocalisationKit + UtilKit. |
| `ComponentKit` | JSON-driven `Component`/`ComponentsRegistry`. Built out but not yet linked by any feature. |
| `KloudKit` | Core Data + CloudKit stack. Re-exports `CoreData`. |
| `RemoteKit` | `RemoteLink` (the only `WCSession` in the app), `PrayerRemoteState`, `PrayerRemoteCommand`. |
| `ActivitiesKit` | `PrayerReadingAttributes` and its App Intents. **Deliberately dependency-free** — the widget extension links this and nothing else. |

**Feature modules**

| Module | What it owns |
| --- | --- |
| `AuthKit` | `AuthManager`, Sign in with Apple, guest mode, the `.authGate()` modifier, profile screens. |
| `HomeKit` | The largest module: home screen, prayer detail, the UIKit reader (`PrayerViewController`), the Nissaya study screen, per-prayer theming, the watch host. |
| `PrayersKit` | The prayer catalog — 35 bundled JSON prayers plus `manifest.json`, `PrayerLoader`, `PrayerCatalog`, and per-prayer `PrayerConfiguration` persisted through KloudKit. |
| `SettingsKit` | Settings screen, `AppInfo`, support mail, external links. |
| `MiscKit` | Full-screen status states: error, offline, maintenance, force-update, announcement, what's-new, tutorial. |
| `WristKit` | The whole watch app. Also `#if os(watchOS)`-guarded throughout. |

### Two dependency edges that look wrong and aren't

Both are load-bearing and explained at length in `Package.swift` and in the
source; **do not "fix" them.**

- **`ActivitiesKit` depends on nothing.** Adding a dependency drags the prayer
  catalog and the CloudKit stack into the widget extension's binary just to draw
  a title on a Live Activity card. See `PrayerReadingAttributes`.
- **`WristKit` does not depend on `LocalisationKit`.** The localisation
  build-tool plugin gets one output directory per *target*, not per platform, so
  a build that compiles it for both iOS and watchOS (unavoidable once the watch
  app is embedded) has two commands writing the same `L10n+Generated.swift` and
  fails. The watch also has its own `UserDefaults`, so it could not read the
  chosen language anyway — the language arrives over the wire in
  `PrayerRemoteState.language`. `WristStrings` is a hand-written twelve-string
  table; the doc comment there is the full argument.

## Localisation

`Sources/LocalisationKit/Localisations/strings.json` is the single source of
truth — a flat map of `snake_case` key → `{"En": ..., "Mm": ...}` (148 keys).
The `LocalisationKitPlugin` build-tool plugin runs `LocalisationKitCodeGen` at
build time to generate `L10n+Generated.swift`, a `lowerCamelCase` enum.

To add a string: edit `strings.json`, build, then use `L10n.myNewKey`. Never
edit the generated file, and never hardcode a user-facing string. Placeholders
are `{0}`, `{1}` — pass them as `args`.

## Persistence (KloudKit)

There is no `.xcdatamodeld`. Each module declares its own entities in code by
conforming to `KloudEntity` and returning an `NSEntityDescription` from
`makeEntity()`, so a feature's schema stays in the feature's package. The app
target is the only place that links every module, so it assembles the
`KloudSchema` at launch:

```swift
KloudStack.shared.start(schema: KloudSchema([...]), mode: AuthManager.shared.preferredSyncMode)
```

An entity missing from that list traps on first fetch — deliberately, since a
silently absent table looks like an empty one.

Feature code never holds an `NSManagedObjectContext`; it goes through
`KloudStack.shared.store(for:)` → `KloudStore<Entity>`, which saves before every
write returns. `@objc(ClassName)` on an entity is required — Core Data resolves
by Objective-C name and a mangled Swift class in a package won't be found.

`KloudSyncMode` is `.local` for guests and `.cloud(containerIdentifier:)` once
signed in; signing in migrates guest data across, which is why the whole
sequence lives inside `AuthManager.signInWithApple()`.

## Navigation

`AppNavigatorModel` (in EnvironmentKit) is the single source of truth. No
`NavigationLink(value:)`, no local `@State` push flags — a view that mutates a
stack directly desynchronises the model, and deep links and tab re-taps can no
longer reason about where the user is.

```swift
@EnvironmentObject private var navigator: AppNavigatorModel
navigator.navigate(to: .prayerDetail(prayerID: prayer.id))
```

One path per tab (`paths: [AppTab: [RouterDestination]]`) because `TabView`
keeps all stacks alive at once. Routes carry ids, never model objects — the
destination screen resolves its own id, so a route survives encoding into a
notification payload. Name new cases `<subject><Screen>(<id>:)`.

## UI conventions

- **SwiftUI by default; UIKit where SwiftUI can't deliver.** The reader
  (`PrayerViewController`) and the Nissaya list are `UITableView` +
  diffable data sources, because they need to hold a scroll position across a
  settings change, scroll to a precise offset on playback, and keep a thousand
  rows of reshaped Burmese smooth. Diffable `Item`s carry *identity only* (never
  text) so a type-size change reconfigures rows instead of animating the whole
  prayer out and back.
- **Never hardcode colours, fonts, or spacing.** Use `AppColor.*`, `AppFont.*`,
  and each component's `*Metrics` enum. Colours are built with
  `Color.dynamic(light:dark:)` from `Palette` — both schemes always.
- **Reuse DesignKit components** (`AppButton`, `AppCard`, `AppListSection`,
  `AppSettingsRow`, `AppEmptyStateView`, …) before writing a new one. New shared
  components go in `DesignKit/Components/` with a public `*Metrics` enum for
  their constants.
- **Burmese text needs vertical room.** Stacked diacritics are why padding
  values look generous; don't tighten them to match a Latin-only mock.
- **`Inject` for live reload.** Screens and non-trivial views carry
  `@ObserveInjection private var injectionObserver` and end their body with
  `.enableInjection()`. Match the surrounding files.
- **Previews call `Typography.registerFonts()`** in a wrapper struct's `init`,
  since previews skip the app's startup registration.
- **Shared state is a `@MainActor` singleton** exposed as `@Published`:
  `AuthManager.shared`, `KloudStack.shared`, `PrayerCatalog.shared`,
  `PrayerConfigurationStore.shared`, `LocalisationManager.shared`,
  `ThemeSwitcher.shared`, `RemoteLink.shared`. Follow that shape rather than
  introducing a DI container.

## Watch & Live Activities

The watch holds no model of its own. It renders `PrayerRemoteState` pushed from
the phone and sends `PrayerRemoteCommand` back, so scrolling the phone by hand
and turning the crown end in the same place. `RemoteLink` uses `sendMessage` for
live events (a tap forty seconds late is worse than a dropped tap) and
`updateApplicationContext` for the durable snapshot a cold-launched watch reads.

`WristRuntimeSession` takes a `.mindfulness` `WKExtendedRuntimeSession` to keep
the remote up for the length of a prayer — the watch target's `WKBackgroundModes`
must agree.

iOS hides an app's own Live Activity while that app is frontmost, so
`PrayerReadingAttributes` is the reading *as seen from outside*. Inside the app
the same controls are drawn by `PrayerIslandBar`; the two are deliberately alike
and can never both be on screen.

## Swift style

- Swift 6.2 tools, strict concurrency. iOS 16 / macOS 13 / watchOS 10 minimums;
  anything newer needs `@available` and a fallback.
- Two-space indent. `// MARK: -` to section a file.
- **Doc comments explain *why*, not *what*.** This codebase's distinguishing
  habit is long `///` blocks recording the reasoning behind a non-obvious
  choice, including approaches that were tried and failed. When you make a
  decision a future reader would want to undo, write down why it's there. Match
  the density of the file you're editing.
- Public API needs `public` explicitly — module boundaries are real, and a type
  used across modules must be exported deliberately.
- Prefer `Sendable` value types crossing module boundaries; wire types
  (`PrayerRemoteState`, `PrayerReadingAttributes`) stay small and free of domain
  types on purpose.
- `#if os(iOS)` / `#if os(watchOS)`, not `#if canImport(ActivityKit)` — the
  latter imports fine on macOS and then fails a line later on unavailability.
