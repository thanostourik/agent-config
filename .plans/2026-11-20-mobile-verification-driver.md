# Mobile verification: sign in once, and a Maestro driver in the generator

The generator ships drivers for the web (Playwright) and APIs (curl) only. Mobile apps get
whatever the generating agent invents: cinova wrote a UI Automator driver, and wovies left
its phone app undriven without asking.

Measured on cinova (`simulated-relays`, 3 runs each, 2026-11-20):

- Today's driver: 108–111 s per feature. The session reset (wipe app and Chrome, cold
  start) takes about 27 s and the Keycloak login about 45 s, in every feature. That is
  about 48% of a full drive.
- Maestro: 94–105 s. Checks inside a flow take 0.1–0.2 s against about 2 s per
  `uiautomator dump`, but each `maestro test` call costs 4.5–7 s to start.
- Reopening an app that is already signed in reaches Home in 14–16 s.
- Maestro always uses ADB server port 5037 and driver port 7001. Run in a private network
  namespace (`unshare --user --map-root-user --net`) with `socat` bridges to the run's
  ADB server and emulator ports, it stays inside the run.

## 1. cinova: sign in once per run

A feature needs fresh app data, not a fresh login. `ui session FEATURE` stops wiping the
login: it deletes the app's own data except the Keychain token, restarts the app, and
lands on Home signed in as the owner. When the app shows Login instead (first feature,
expired token), it signs in through the real Keycloak form as today. `pm clear` cannot be
used for this: it also deletes the app's Keystore keys, so the kept token could not be read.

Features about signing in itself start signed out (`ui session FEATURE signed-out`, the
full wipe of today). Recipes that call `ui login` only to get signed in drop that call.

Verify: `verify all` passes, the suite time before and after, and a run longer than the
access token's lifetime still signs in.

Lands in `eworx-org/cinova-iot-mobile`, its own PR.

## 2. Generator

- Step 1: a surface the shipped drivers cannot drive is a question to the user: build a
  driver for it, or leave it undriven and say so in `PROJECT.md`.
- Sign-in once per run becomes a rule for every UI driver, not only the web one.
- A "For a mobile app" driver section for Android: Maestro, pinned in a `maestro-version`
  file like `pw-version`, called through a shipped wrapper that runs it in the private
  network namespace. Recipes group steps into a few flows, because each call costs
  seconds to start.
- `SETUP.md`: Maestro needs Java 17+, and the wrapper needs unprivileged user namespaces
  (`kernel.apparmor_restrict_unprivileged_userns = 0`; stock Ubuntu 24.04 sets 1).

## 3. Wovies trial

Add the phone app (`apps/mobile`, Expo dev client, Clerk, Convex) to `verify-wovies` with
`/maintain-project-verification-skill`: the mobile environment and one recipe (sign in,
open the watchlist), driven through the new section. Measure `up` and the drive. Recording
the rest of the mobile features is a later decision.
