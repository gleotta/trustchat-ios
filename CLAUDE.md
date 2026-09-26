# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

TrustChat iOS is a private fork of [SimpleX Chat](https://github.com/simplex-chat/simplex-chat) (`upstream` remote) focused on the iOS client in `apps/ios/`. The rest of the monorepo (Haskell core in `src/`, Android/desktop in `apps/multiplatform/`, bots, website) is upstream code kept in sync; only touch it when a change genuinely needs it.

`README.trustchat.md` (Spanish) is the fork's operational guide: validated build baseline, SMP server setup, signing/distribution plan, and troubleshooting. Read it before doing any build-pipeline or release work. The root `README.md` is upstream marketing and not useful for development.

## Project documentation (spec, architecture, tasks)

The product specification, architecture and work guides live in a separate sibling repository, **`../trustchat-docs`** (`/Users/links/git/trustchat-docs`, remote `github.com/gleotta/trustchat-docs`). All documents are in Spanish. Read the relevant ones before any feature or security work in this repo; they are the source of truth for scope and design, and this CLAUDE.md does not duplicate them.

| Document | Role |
|---|---|
| `TRUSTCHAT-SPEC.md` | **Master document** (v1.3; §14 records the demo decisions). Functional and technical spec, approved decisions D-01…D-12, user stories US-001…US-055, demo deliverables and acceptance criteria, open questions. |
| `TRUSTCHAT-ARCHITECTURE.md` | Technical and security architecture for the demo (v1.0): ADRs, trust boundaries, server-identity and application-authentication contracts, SMP gate coverage, threat model, acceptance tests. Binding design; it never changes scope. |
| `TRUSTCHAT-IOS-TASKS.md` | **Executable guide for this repository**: iOS reconnaissance, branding, embedded server config, application identity and transport gate, capability restrictions, tests, three-day plan, Definition of Done. |
| `TRUSTCHAT-SMP-TASKS.md` | Same for the SMP server fork (a separate repo). Read it for the client/server auth contract and integration gates; do not implement server work here. |
| `TRUSTCHAT-PRODUCT-BACKLOG.md` | Full-product backlog (v1.0) by epic EP-01…EP-12. Predates the spec. |

Precedence and rules that the documents themselves impose:

- SPEC (v1.3) overrides the backlog. In particular, the backlog's per-device credentials and allowlists are obsolete; the approved model is a **shared application identity** (one key pair per app build, cryptographic proof of possession per transport session, no server-side user or device registry).
- ARCHITECTURE and both TASKS guides derive from SPEC and cannot add scope or user stories. If code and docs disagree, note the discrepancy rather than silently choosing.
- The iOS tasks guide instructs: implement only what the spec defines, never invent paths, symbols, FFI functions or CLI options, inspect the repository first, and record evidence (paths, symbols, commits, test output). If the SMP auth contract is not closed, run the compatibility spike before coding the final solution.
- Demo MVP scope (SPEC v1.3): one TrustChat SMP and one TrustChat XFTP, 1:1 encrypted text and files, QR contacts; no push, groups, calls, Tor or proxying to external relays. Target demo date is 27 September 2026.
- Current state and next steps: `TRUSTCHAT-IOS-SPRINT-PLAN.md` §11 in `../trustchat-docs` (local, not committed). Evidence lives outside the repo in `~/trustchat-evidence/mvp0/<task>/`.

Upstream's project docs are the canonical reference for structure and coding style and are imported here:

@docs/contributing/PROJECT.md
@docs/contributing/CODE.md
@apps/ios/README.md

**Before changing iOS code, read `apps/ios/CODE.md`.** It defines the three-layer navigation (`apps/ios/product/` → `apps/ios/spec/` → source) starting at `apps/ios/product/concepts.md`, and the change protocol that requires updating `spec/` (and `product/` for user-visible changes) alongside code. Non-trivial features get a plan in `plans/` first; existing plans use `YYYY-MM-DD-slug.md` names.

## iOS build pipeline (the non-obvious part)

Xcode does not compile the Haskell core. The core is built by Nix into static `.a` libraries, patched with `mac2ios`, dropped into `apps/ios/Libraries/{sim,ios}/` (gitignored), and linked by `SimpleX.xcodeproj`. Simulator and device libraries are different platforms even when both are arm64; never copy `sim/` to `ios/` or vice versa.

Validated baseline (see `README.trustchat.md`): Intel Mac, iOS Simulator only, output `x86_64-darwin-ios:lib:simplex-chat`. The device (`aarch64-darwin-ios`) path is defined in `flake.nix` but not yet validated for this fork.

```bash
# 1. Build the core for the Intel simulator (first run is very slow)
nix --extra-experimental-features "nix-command flakes" \
  build '.#x86_64-darwin-ios:lib:simplex-chat' --no-update-lock-file --out-link result-ios-sim -L

# 2. Unpack and patch for the simulator (-s = simulator; omit -s for device libs)
mkdir -p apps/ios/Libraries/sim
unzip -o result-ios-sim/pkg-ios-x86_64-swift-json.zip -d apps/ios/Libraries/sim
chmod u+w apps/ios/Libraries/sim/*.a
for lib in apps/ios/Libraries/sim/*.a; do "$HOME/.local/bin/mac2ios" -s "$lib" > /dev/null; done

# 3. Point project.pbxproj at the new libHSsimplex-chat-<version>-<hash>.a names.
#    The script defaults to Libraries/ios; override LIB_DIR for the simulator.
sed 's|^LIB_DIR=.*|LIB_DIR=./apps/ios/Libraries/sim|' scripts/ios/update-pbxproj.sh | sh
plutil -lint apps/ios/SimpleX.xcodeproj/project.pbxproj   # must print OK
```

Library file names embed the core version and a hash, so step 3 (and a Clean Build Folder in Xcode) is required after every core rebuild. The resulting `project.pbxproj` diff is committed. `scripts/ios/prepare.sh` / `prepare-x86_64.sh` are upstream's equivalents of step 2 and expect zips in `~/Downloads`.

Swift/SwiftUI-only changes never need a core rebuild: just build in Xcode.

### Xcode commands

```bash
open apps/ios/SimpleX.xcodeproj    # scheme "SimpleX (iOS)", pick an iPhone Simulator

xcodebuild build -project apps/ios/SimpleX.xcodeproj -scheme "SimpleX (iOS)" \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Tests ("Tests iOS" target, XCUITest)
xcodebuild test -project apps/ios/SimpleX.xcodeproj -scheme "SimpleX (iOS)" \
  -destination 'platform=iOS Simulator,name=iPhone 15'
# Single test
xcodebuild test ... -only-testing:"Tests iOS/Tests_iOS/testExample"

# Version bump (edits 10+10 lines in project.pbxproj, refuses if counts differ)
./scripts/ios/update-version.sh <build_number> <marketing_version>

# Localizations (run from repo root; see apps/ios/LOCALIZATION.md for how keys are generated)
./scripts/ios/export-localizations.sh
./scripts/ios/import-localizations.sh
```

Local, uncommitted Xcode overrides go in `apps/ios/Local.xcconfig` (gitignored, included by both `Debug.xcconfig` and `Release.xcconfig`).

## Haskell core commands

```bash
cabal build                                   # library + CLI (add --ghc-options -O0 for speed)
cabal build exe:simplex-chat && cabal list-bin exe:simplex-chat
cabal build -j --enable-tests                 # what CI does
cabal test --test-show-details=direct         # full hspec suite
cabal test --test-show-details=direct --test-options='-m "direct tests"'   # by hspec description
cabal test --test-show-details=direct --test-options='-m "delete contact keeping conversation"'
fourmolu -i src/Simplex/Chat/Some/File.hs     # format before committing (config: fourmolu.yaml)
```

- macOS needs OpenSSL from Homebrew and a `cabal.project.local` copied from `scripts/cabal.project.local.mac` for SQLCipher.
- Tests spin up SMP/XFTP servers in-process (`tests/ChatClient.hs`, port 7001) and write to `tests/tmp`; no external services needed.
- `chat_schema.sql` under `src/Simplex/Chat/Store/*/Migrations/` is regenerated by the test suite; never edit it by hand.
- The iOS libraries are built with the `swift` cabal flag (the `*-swift-json` Nix outputs), which selects the JSON encoding the Swift `Codable` types expect. A plain host `cabal build` produces the tagged-JSON variant used by CLI/desktop and is not linkable by the iOS app.
- For local work against a modified `simplexmq`, uncomment the `packages: . ../simplexmq` line in `cabal.project` (sibling checkout).

## Architecture in one screen

- **Swift ↔ Haskell boundary**: `apps/ios/SimpleXChat/SimpleX.h` declares the C FFI (`chat_migrate_init_key`, `chat_send_cmd_retry`, `chat_recv_msg_wait`, file/media crypto helpers). `SimpleXChat/API.swift` wraps them; `Shared/Model/SimpleXAPI.swift` is the app-level command layer (`chatSendCmd`, `apiSendMessages`, …) and the event loop (`chatRecvMsg` → `processReceivedMsg`). Commands are `ChatCommand` values serialized via `cmdString`; responses and events are JSON decoded into types in `SimpleXChat/APITypes.swift`, `Shared/Model/AppAPITypes.swift`, and `SimpleXChat/ChatTypes.swift`. On the Haskell side the same commands are handled in `src/Simplex/Chat/Library/Commands.hs`, and agent events in `Library/Subscriber.hs`; `Mobile.hs` is the FFI export module.
- **State**: `Shared/Model/ChatModel.swift` is the app-wide `ObservableObject` singleton; `ItemsModel` holds the open chat's items. Views under `Shared/Views/` are organized by feature.
- **Three targets, one database**: the app, Notification Service Extension (`SimpleX NSE`) and Share Extension (`SimpleX SE`) share the database and preferences through the App Group and Keychain (`SimpleXChat/AppGroup.swift`, `KeyChain.swift`). Each target starts its own Haskell runtime with a different heap budget in `SimpleXChat/hs_init.c` (NSE is tiny); keep NSE code paths lean.
- **Identity is still upstream's**: bundle IDs are `chat.simplex.app`, `chat.simplex.app.SimpleX-NSE`, `chat.simplex.app.SimpleX-SE`, and the App Group is `group.chat.simplex.app` (in `project.pbxproj` and the three `.entitlements` files). These must be replaced consistently across all targets before any device build, TestFlight, or App Store submission; the checklist is in `README.trustchat.md`.

## Fork-specific rules

- Never commit `apps/ios/Libraries/`, `result-ios-*` symlinks, DerivedData, `.xcarchive`/`.ipa`, signing material, or a full `smp://<fingerprint>:<password>@host:port` address. The SMP address contains a credential; use placeholders in docs, issues and tests.
- The TrustChat SMP server address format is `smp://<FINGERPRINT>:<PASS>@host:port` with no scheme prefix other than `smp://`, no trailing slash, and the public port (not the container-internal 5223). From the simulator, `127.0.0.1` reaches a server on the Mac; from a physical iPhone it does not.
- On branch `mvp0`, `apps/ios/Shared/TrustChat/TrustChatConfig.{plist,swift}` impose the TrustChat SMP and XFTP at runtime (operators disabled, other servers removed) and reject links/QR codes naming any other server (RULE-24, RULE-25 in `apps/ios/product/rules.md`). NTF presets, chat relays and short-link preset domains still live in the core binary without network contact; do not describe traffic as fully under TrustChat control beyond what is verified.
- SMP and XFTP create passwords live only in the gitignored `apps/ios/Local.xcconfig` (`TRUSTCHAT_SMP_PASSWORD`, `TRUSTCHAT_XFTP_PASSWORD`); never print, log or commit them.
- Do not disable App Transport Security or TLS validation to work around a development problem.
- Before committing run `git diff --check` and review `git status --short`; `update-pbxproj.sh` and `update-version.sh` edit `project.pbxproj` and their diffs should be inspected.

## Upstream conventions that still apply

- Commit and PR titles start with a scope (`ios:`, `core:`, `android:`, `desktop:`, `docs:`, `ci:`), lowercase, present tense, describing the user problem solved. PRs are squashed; do not rewrite branch history after review.
- Every change must address a concrete user problem; no refactoring for its own sake, no moving existing code, minimal diffs (see `docs/contributing/CODE.md` and `apps/ios/CODE.md`).
- New Haskell types used in JSON must stay forward compatible for the remote-desktop link: add fields as optional and provide `omittedField` defaults (details in `docs/CONTRIBUTING.md`).
- New Swift strings must be localizable: use `Text`/`LocalizedStringKey` or `NSLocalizedString` with `String.localizedStringWithFormat` for interpolation (`apps/ios/LOCALIZATION.md`).
