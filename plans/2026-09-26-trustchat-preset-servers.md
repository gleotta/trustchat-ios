# TrustChat: preset SMP and XFTP servers (IT-06)

Date: 2026-09-26. Branch: `mvp0`. Spec: `../trustchat-docs/TRUSTCHAT-SPEC.md` v1.2 (D-02, D-05), `TRUSTCHAT-IOS-TASKS.md` IT-06, decisions of 2026-09-25 (own SMP + own XFTP, push deferred).

## Problem

The iOS app inherits SimpleX's preset operators (SimpleX Chat, Flux) and their SMP/XFTP servers from the Haskell core (`src/Simplex/Chat/Operators/Presets.hs`). The demo must use only the TrustChat SMP for messaging and the TrustChat XFTP for files, with no user-editable server configuration and no fallback to public servers (`docs/trustchat/ios-network-map.md` §1 items 1-4, 6). The core starts the chat before the onboarding step where operators are chosen, and the onboarding conditions step re-enables the SimpleX operator.

## Solution

A bundled configuration file `apps/ios/Shared/TrustChat/TrustChatConfig.plist` holds the public server data (host, port, fingerprint) for SMP and XFTP and the push flag. The SMP queue-creation password is injected at build time from the gitignored `apps/ios/Local.xcconfig` (`TRUSTCHAT_SMP_PASSWORD`) into the app `Info.plist` key `TrustChatSMPPassword`; it never enters git.

`TrustChatConfig.swift` loads the file and, on every `startChat`, right after `apiStartChat` (the core's `APIGetUserServers`/`APISetUserServers` handlers use `withUser`, which requires a started chat; a new profile has no queues so nothing connects in between), rewrites the current user's server configuration through the existing `APISetUserServers` command: preset operators disabled, TrustChat SMP and XFTP added as custom servers (enabled, storage + proxy roles), any other custom server deleted. The core persists this in `protocol_servers` / `server_operators`, so the NSE and SE inherit it. Because both protocols have an enabled TrustChat server, the core's random-preset fallback (`useServerCfgs`) never triggers and `validateUserServers` passes.

Network transport defaults are pinned before `setNetworkConfig`: no SOCKS, public hosts only, private routing `unknown` (known TrustChat server direct, anything else only via the TrustChat SMP as proxy) and fallback `prohibit` (never a direct connection to a foreign relay).

Onboarding steps 3 and 4 (operators, conditions, notification mode) are skipped after profile creation when the config is present. APNs registration is skipped when `pushNotifications` is false, so no token is ever sent to SimpleX's NTF servers.

No core rebuild is needed. NTF preset servers, chat relays, the SimpleX team contact card and short-link preset domains remain in the core without network contact; they are documented as known limitations.

## Technical design

- `TrustChatConfig` (Decodable): `smpServer`, `xftpServer` (`host`, `port`, `fingerprint`), `pushNotifications: Bool`. `static let shared: TrustChatConfig?` is `nil` when the plist is absent, which restores upstream behaviour.
- Addresses are built as `smp://<fingerprint>[:<password>]@<host>:<port>` and `xftp://<fingerprint>@<host>:<port>` and validated with `parseServerAddress` (FFI `chat_parse_server`); protocol, host, port and key hash must match the config, otherwise `startChat` throws and the app does not start (fail closed).
- `applyTrustChatServerPolicy()` (sync, called from `startChat` after `apiStartChat`; first attempt before it failed with `chatNotStarted`): `getUserServersSync` → compute desired `[UserOperatorServers]` → if unchanged, return → `validateServersSync` → `setUserServersSync`. Existing entries are compared by parsed components, not by string.
- Sync twins `getUserServersSync`, `setUserServersSync`, `validateServersSync` follow the existing `getServerOperatorsSync` pattern in `SimpleXAPI.swift`.
- `enforceNetworkDefaults()` writes the pinned values with the existing group-default setters before `setNetworkConfig(getNetCfg())`.
- `CreateFirstProfile.createProfile` and `CreateProfile.createProfile` set `.onboardingComplete` instead of `.step3_ChooseServerOperators` when the config is present; the `startChat` recovery path that forced `.step4_NetworkCommitments` does the same.
- `AppDelegate.didFinishLaunching` calls `registerForRemoteNotifications()` only when `pushNotifications` is true.
- Xcode: new group `Shared/TrustChat` with the Swift file (app target Sources) and the plist (app target Resources). NSE and SE do not link the file.

## Implementation steps

1. Add `TrustChatConfig.plist`, `TrustChatConfig.swift`, `Local.xcconfig.example`; add `TrustChatSMPPassword` to `SimpleX--iOS--Info.plist`; register files in `project.pbxproj`.
2. Add sync wrappers and the two `startChat` hooks in `SimpleXAPI.swift`; gate APNs in `AppDelegate.swift`; skip onboarding steps in `CreateProfile.swift`.
3. Build the `SimpleX (iOS)` scheme for the simulator.
4. UI test in `Tests iOS`: fresh install → onboarding → create 1-time link → assert the link host is the TrustChat SMP and no `simplex.im` host appears.
5. Update `apps/ios/spec/architecture.md`, `spec/impact.md`, `product/rules.md`, `product/views/onboarding.md`, `product/concepts.md`, `CODE.md` Document Map, `README.trustchat.md`.
6. Record evidence in `~/trustchat-evidence/mvp0/it-06/` and commit on `mvp0`.
