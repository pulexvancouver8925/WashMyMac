<div align="center">

<img src="docs/icon.png" width="128" alt="WashMyMac">

# WashMyMac

**Black screen, dead keyboard. Wipe your MacBook without typing garbage into it.**

[![Release](https://img.shields.io/github/v/release/AppsGanin/WashMyMac?style=flat-square&color=2f6bf0)](https://github.com/AppsGanin/WashMyMac/releases/latest)
[![Build](https://img.shields.io/github/actions/workflow/status/AppsGanin/WashMyMac/build.yml?branch=main&style=flat-square)](https://github.com/AppsGanin/WashMyMac/actions)
[![Downloads](https://img.shields.io/github/downloads/AppsGanin/WashMyMac/total?style=flat-square&color=2f6bf0)](https://github.com/AppsGanin/WashMyMac/releases)
[![macOS](https://img.shields.io/badge/macOS-13%2B-000?style=flat-square&logo=apple)](#requirements)
[![License](https://img.shields.io/github/license/AppsGanin/WashMyMac?style=flat-square)](LICENSE)

[Русская версия](README.ru.md)

</div>

---

Cleaning a MacBook is two problems at once. A lit screen hides the very smudges you are
trying to remove, so you wipe blind and find the streaks an hour later in a dark room. And a
cloth dragged across the keyboard types into whatever is open — renames files, fires
shortcuts, occasionally deletes something you will miss.

Closing the lid solves neither, since you cannot clean the glass with the lid shut. Locking
the screen leaves the keyboard live too — now you are just wiping crumbs into a password
field.

WashMyMac blacks out every display, kills the keyboard, trackpad and mouse, and gives the
Mac back when you hold a combination that a cloth cannot press.

<img src="docs/screen.png" alt="The black cleaning screen with a countdown ring">

## Features

- **Pure black on every display.** Not a screensaver, not a dimmed desktop — a flat black
  field where every smudge, fingerprint and dust speck shows up.
- **Input goes dead.** Keyboard, trackpad and mouse, system shortcuts included: ⌘Space,
  ⌘Tab, ⌘Q, volume, brightness, trackpad gestures.
- **An exit a cloth cannot trigger.** ⌃⌥⌘U, held — and only while not a single other key
  is down.
- **Auto-exit, always on.** One to thirty minutes. There is deliberately no "never": it is
  the one guaranteed way out.
- **The display cannot doze off.** A power assertion plus a heartbeat, because with every
  event swallowed macOS is convinced nobody is home.
- **A beacon, so you know it is alive.** Once the hint fades, a dim pulsing dot keeps the
  exit combination on screen — an empty black display looks exactly like a dead one.
- **Kiosk mode.** Dock and menu bar stay hidden even if you shove the cloth into the edge
  of the screen.
- **Nothing can get stuck.** Both layers live only as long as the process: kill the app and
  the lock lifts itself.
- **English and Russian**, following your system language.
- **Plain Swift and AppKit.** No dependencies, no daemon, no telemetry, no network.
- **Universal binary**, Apple Silicon and Intel.

## Install

Grab the `.zip` from the [latest release](https://github.com/AppsGanin/WashMyMac/releases/latest),
unzip it and drag `WashMyMac.app` into `/Applications`.

> [!NOTE]
> The app is not signed with an Apple Developer certificate, so macOS blocks the first
> open. Right-click the app → **Open** → **Open** again. One-time.

The app lives in the menu bar and has no Dock icon. First time you start cleaning mode it
will ask for Accessibility access — see [below](#accessibility-permission) for what changes
if you decline.

## Usage

| Action | How |
| --- | --- |
| Start cleaning mode | **⌃⌥⌘W**, or menu bar → **Wipe My Mac** |
| Exit | **⌃⌥⌘U**, held for 1.5 s |
| Bring the hint back | **⌃⌥⌘** without U, held briefly |
| Exit when nothing else works | wait for auto-exit — five minutes out of the box |

For the first few seconds the ring in the middle counts down to auto-exit. Then the hint
dissolves and the screen goes properly black, leaving only the beacon at the bottom.

## The exit combination

<img src="docs/unlock.png" alt="The unlock ring filling while the combination is held">

Hold ⌃⌥⌘U and the same ring fills up over 1.5 seconds. Let go early and it drops to zero.

The combination counts only when exactly three modifiers and the U key are down — **not one
extra key**. A cloth always presses neighbours, so it can never satisfy the rule no matter
where you drag it. Shift held, or any second letter down, and the countdown resets.

The same logic guards the hint gesture: ⌃⌥⌘ with nothing else brings the text back, so you
can remind yourself of the combination without ending the session.

## How it works

Three layers, because macOS hands out input at three different depths:

| Layer | Blocks | Needs permission |
| --- | --- | --- |
| `CGEventTap` at session level | Everything — keys, mouse, scroll, gestures, media keys, system shortcuts | Accessibility |
| Window at `CGShieldingWindowLevel()` | Everything routed to the app; covers the menu bar, the Dock and the notch | No |
| `NSApplicationPresentationOptions` | ⌘Tab, ⌘⌥⎋, Dock, menu bar, shutdown from the Apple menu | No |

The tap sits at the head of the event stream, ahead of the WindowServer, so it consumes
system hotkeys before anything else sees them. It also means macOS stops seeing user
activity entirely — hence `DisplayKeeper`, which holds a `NoDisplaySleep` assertion and
declares user activity every 20 seconds so the screen never dims mid-wipe.

Every layer is owned by the process. If the app crashes, the tap dies, the presentation
options revert and the window disappears — the lock cannot outlive the thing that created
it.

## Accessibility permission

Full input blocking needs one permission:

**System Settings → Privacy & Security → Accessibility → WashMyMac**

The app offers to open that pane the first time you start cleaning mode.

Without it WashMyMac still works — the screen goes black, the shield window covers
everything, ordinary keystrokes do nothing. But system shortcuts are handled by the
WindowServer before any app sees them, so ⌘Space opens Spotlight behind the black screen and
Ctrl+↑ throws you into Mission Control, blind. The overlay shows an orange warning while
running in that mode.

> [!IMPORTANT]
> The app is ad-hoc signed, so its code hash changes on every rebuild — and macOS keys the
> permission to that hash. After building a new version, remove the old entry with **−** and
> grant it again. `tccutil reset Accessibility com.ganin.washmymac` clears any leftovers.

## What it cannot block

macOS limits, not missing features:

- **Power button and Touch ID** put the Mac to sleep or lock it. Handled in hardware, no
  API intercepts it — and that makes it your emergency exit.
- **Holding the power button** force-restarts, same story.
- **Secure Input.** If the frontmost app has secure input enabled — an open password field,
  some terminals — the tap never receives keystrokes. Close the password field first.
- **Caps Lock** toggles its LED; the keystroke itself is swallowed.

## Build from source

```bash
./build.sh --install          # → /Applications/WashMyMac.app
./build.sh                    # → .build/bundle/WashMyMac.app
```

Xcode or the Command Line Tools is the only requirement. The universal binary, the bundle,
the localizations and the icon are all assembled by that one script — the icon is drawn in
code by [`tools/make_icon.swift`](tools/make_icon.swift), so no binary asset ships in the
source tree. A missing translation fails the build:
[`tools/check-localization.sh`](tools/check-localization.sh) diffs the `L.t("…")` keys in the
sources against every `Localizable.strings`.

To look at the design without locking anything up:

```bash
/Applications/WashMyMac.app/Contents/MacOS/WashMyMac --preview
```

Add `--unlocking` for the unlock ring, `--beacon` for the state after the hint fades,
`--degraded` for the missing-permission warning, and `-AppleLanguages '(en)'` to force a
language.

Releases are cut by [release-please](https://github.com/googleapis/release-please) from
[Conventional Commits](https://www.conventionalcommits.org): merge a `feat:` or `fix:`
commit to `main`, and it opens a release PR that bumps the version and writes the changelog.
Merging that PR tags the release and attaches the built `.zip`.

## Requirements

macOS 13 Ventura or newer. Apple Silicon and Intel. The interface follows your system
language — English or Russian.

## License

[MIT](LICENSE)
