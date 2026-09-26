# TrustChat: validate incoming links and QR codes before connecting (IT-07)

## Problem

Every connection link the app receives (QR scan, pasted link, chat-list search, `simplex:`/`https` URL opened from another app, link tapped inside a message) goes to `planAndConnect` → `apiConnectPlan` → core `connectPlan`, which resolves short links and joins queues on **whatever server the link names**. A SimpleX QR from a stranger therefore makes a TrustChat build contact `simplex.im` (see `docs/trustchat/ios-network-map.md` §3.3). IT-07 requires rejecting such links **before** any network activity, comparing the full server identity (host, port, fingerprint), not only the visible host.

## Solution

A single Swift validator in `Shared/TrustChat/TrustChatConfig.swift`, active only when `TrustChatConfig.shared` is present, applied in `apiConnectPlan` (the one function every UI path calls before the core sees the link):

1. **Parse the link text locally** (no FFI network, no core command):
   - full links `simplex:/invitation#/?v=…&smp=<q1>;<q2>…` and `simplex:/contact#/?…` (also their `https://simplex.chat/…` form): every queue URI in `smp=` (URL-decoded, `;`-separated) is `smp://<keyHash>@<hosts>:<port>/<queueId>…`; its authority is parsed with the core's `parseServerAddress` (`chat_parse_server`), which is offline.
   - short links `https://<host>/<i|c|a|g>#…?p=<port>&c=<keyHash>` and `simplex:/<type>#…?h=<hosts>&p=…&c=…`: host from the authority (or `h`), port from `p` (empty when absent), key hash from `c` (empty when absent = SimpleX preset domain).
2. **Accept only if every server is exactly the TrustChat SMP**: hostnames == `[smpServer.host]`, port == `smpServer.port`, key hash == `smpServer.fingerprint` (base64url, padding-insensitive). Anything else, including an unparsable link or a SimpleX name (`@name`, resolved on the network unless `resolveMode == .never`), is rejected with one localized alert (“This link is not a TrustChat link…”) and the command is never sent.
3. Existing entry points are unchanged: they keep calling `planAndConnect`/`apiConnectPlan`; the rejection surfaces through the existing `nil` result path (progress stops, `cleanup` runs).

Not covered here (documented as limitations): contacts with historical queues on foreign servers (IT-07.5), group invitations received by protocol (groups out of scope, IT-12), and links opened by tapping outside the app (the SMP host has no HTTPS landing page on Railway; see `README.trustchat.md`).

## Design

- `struct TrustChatLink` (parsed servers + link kind) and `enum TrustChatLinkError: LocalizedError` (`.notLink`, `.foreignServer(host)`, `.name`).
- `TrustChatConfig.validateLink(_ text: String) throws` uses `smpAddress().parsed` for the comparison; the password never appears in links, so `basicAuth` is ignored.
- Hook: `apiConnectPlan(connLink:resolveMode:…)` calls `try TrustChatConfig.shared?.validateLink(connLink)` when `resolveMode != .never`; on error shows the alert (`AlertManager`) and returns `nil`.
- Rule RULE-25 in `product/rules.md`; spec `architecture.md` subsection extended; `impact.md` rows.

## Implementation steps

1. Validator + hook (`TrustChatConfig.swift`, `SimpleXAPI.swift`).
2. XCUITest `testTrustChatRejectsForeignLink`: paste a SimpleX-server link and a TrustChat-host link with a wrong fingerprint → rejection alert, no connect command; paste the profile's own TrustChat link → passes validation (core answers “own link”).
3. Docs: `spec/architecture.md`, `spec/impact.md`, `product/rules.md`, `README.trustchat.md`; evidence in `~/trustchat-evidence/mvp0/it-07/`.

## Verification (2026-09-26)

`testTrustChatRejectsForeignLink` and `testTrustChatRejectsForeignFullLink` pass on the simulator "TrustChat mvp0 A": the SimpleX team address (`simplex:` scheme, preset domain), the same address as an `https://smp6.simplex.im/a#…` short link, the profile's own link with an altered fingerprint, and a full link with a queue on `smp4.simplex.im` are all rejected with the alert before any command reaches the core (app log: four "link rejected" lines, no `apiConnectPlan` command); the profile's own TrustChat link passes and produces exactly one `/_connect plan`. Evidence in `~/trustchat-evidence/mvp0/it-07/`.

Test-authoring notes for this app: the compose menu entry is "Scan / Paste link" and the sheet segments are "1-time link" / "Connect via link"; a pasteboard set by the test runner triggers the iOS "Allow Paste" prompt, which blocks the app's main thread until answered from SpringBoard; typing a link into the chat-list search field connects as soon as a prefix parses as a link, so links must be pasted.
