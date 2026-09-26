//
//  TrustChatConfig.swift
//  SimpleX (iOS)
//
//  TrustChat: preset servers loaded from TrustChatConfig.plist and applied before the chat starts.
//

import Foundation
import SimpleXChat

struct TrustChatConfig: Decodable {
    struct Server: Decodable {
        var host: String
        var port: String
        var fingerprint: String
    }

    var smpServer: Server
    var xftpServer: Server
    var pushNotifications: Bool

    // nil when TrustChatConfig.plist is not bundled: the app then behaves as upstream SimpleX
    static let shared: TrustChatConfig? = load()

    private static func load() -> TrustChatConfig? {
        guard let url = Bundle.main.url(forResource: "TrustChatConfig", withExtension: "plist") else { return nil }
        do {
            return try PropertyListDecoder().decode(TrustChatConfig.self, from: try Data(contentsOf: url))
        } catch {
            logger.error("TrustChatConfig: invalid TrustChatConfig.plist: \(error.localizedDescription)")
            return nil
        }
    }

    // Create passwords (SMP queues, XFTP files) are injected by Local.xcconfig (TRUSTCHAT_SMP_PASSWORD,
    // TRUSTCHAT_XFTP_PASSWORD) into Info.plist at build time; never committed.
    private func password(_ infoKey: String) -> String? {
        let p = (Bundle.main.object(forInfoDictionaryKey: infoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return p.isEmpty ? nil : p
    }

    func smpAddress() throws -> TrustChatServerAddress {
        try address(.smp, smpServer, password("TrustChatSMPPassword"))
    }

    func xftpAddress() throws -> TrustChatServerAddress {
        try address(.xftp, xftpServer, password("TrustChatXFTPPassword"))
    }

    private func address(_ serverProtocol: ServerProtocol, _ s: Server, _ pass: String?) throws -> TrustChatServerAddress {
        let auth = pass.map { ":" + $0 } ?? ""
        return try TrustChatServerAddress(serverProtocol, "\(serverProtocol.rawValue)://\(s.fingerprint)\(auth)@\(s.host):\(s.port)", s)
    }

    // Transport settings the user must not be able to change: no SOCKS, public hosts only,
    // private routing only through the TrustChat SMP, never a direct connection to a foreign relay.
    func enforceNetworkDefaults() {
        groupDefaults.set(nil, forKey: GROUP_DEFAULT_NETWORK_SOCKS_PROXY)
        networkUseOnionHostsGroupDefault.set(.no)
        networkSMPProxyModeGroupDefault.set(.unknown)
        networkSMPProxyFallbackGroupDefault.set(.prohibit)
    }
}

struct TrustChatServerAddress {
    let address: String
    let parsed: ServerAddress

    init(_ serverProtocol: ServerProtocol, _ address: String, _ server: TrustChatConfig.Server) throws {
        guard let parsed = parseServerAddress(address),
              parsed.serverProtocol == serverProtocol,
              parsed.hostnames == [server.host],
              parsed.port == server.port,
              parsed.keyHash == server.fingerprint
        else { throw TrustChatConfigError.invalidServer(serverProtocol, server.host) }
        self.address = address
        self.parsed = parsed
    }

    func matches(_ server: String) -> Bool {
        guard let p = parseServerAddress(server) else { return false }
        return p.serverProtocol == parsed.serverProtocol
            && p.hostnames == parsed.hostnames
            && p.port == parsed.port
            && p.keyHash == parsed.keyHash
            && p.basicAuth == parsed.basicAuth
    }
}

enum TrustChatConfigError: LocalizedError {
    case invalidServer(ServerProtocol, String)
    case validation([UserServersError])

    var errorDescription: String? {
        switch self {
        case let .invalidServer(p, host): "TrustChat: invalid \(p.rawValue.uppercased()) server configuration for \(host)"
        case let .validation(errs): "TrustChat: server validation failed: \(errs)"
        }
    }
}

// Rewrites the current user's servers so that only the TrustChat servers are used for new connections:
// preset operators disabled, TrustChat SMP and XFTP enabled, any other custom server removed.
// The core's server commands require a started chat, so this runs right after apiStartChat, before the UI is usable;
// a new profile has no queues at that point. The result is persisted by the core and shared with the NSE and SE.
func applyTrustChatServerPolicy() throws {
    guard let cfg = TrustChatConfig.shared, ChatModel.shared.currentUser != nil else { return }
    let smp = try cfg.smpAddress()
    let xftp = try cfg.xftpAddress()
    var servers = try getUserServersSync()
    var changed = false
    for i in servers.indices {
        if var op = servers[i].operator, op.enabled {
            op.enabled = false
            servers[i].operator = op
            changed = true
        }
    }
    if let i = servers.firstIndex(where: { $0.operator == nil }) {
        changed = syncTrustChatServers(&servers[i].smpServers, smp) || changed
        changed = syncTrustChatServers(&servers[i].xftpServers, xftp) || changed
    } else {
        servers.append(UserOperatorServers(
            operator: nil,
            smpServers: [trustChatUserServer(smp)],
            xftpServers: [trustChatUserServer(xftp)],
            chatRelays: []
        ))
        changed = true
    }
    if !changed {
        logger.info("TrustChat servers already applied")
        return
    }
    let (errors, warnings) = try validateServersSync(userServers: servers)
    if !errors.isEmpty { throw TrustChatConfigError.validation(errors) }
    try setUserServersSync(userServers: servers)
    let disabled = servers.compactMap { $0.operator?.tradeName }
    logger.info("TrustChat servers applied: smp=\(smp.parsed.hostnames):\(smp.parsed.port) xftp=\(xftp.parsed.hostnames):\(xftp.parsed.port) operatorsDisabled=\(disabled) warnings=\(warnings.count)")
}

private func trustChatUserServer(_ srv: TrustChatServerAddress) -> UserServer {
    UserServer(serverId: nil, server: srv.address, preset: false, tested: nil, enabled: true, deleted: false)
}

// Returns true when the list had to change.
private func syncTrustChatServers(_ list: inout [UserServer], _ srv: TrustChatServerAddress) -> Bool {
    var changed = false
    var found = false
    for i in list.indices where !list[i].deleted {
        if !found && srv.matches(list[i].server) {
            found = true
            if !list[i].enabled {
                list[i].enabled = true
                changed = true
            }
        } else if !list[i].preset {
            list[i].deleted = true
            changed = true
        }
    }
    if !found {
        list.append(trustChatUserServer(srv))
        changed = true
    }
    return changed
}

// MARK: - Incoming links (IT-07)

enum TrustChatLinkError: LocalizedError {
    case notLink
    case foreignServer(String)
    case wrongIdentity(String)

    var errorDescription: String? {
        switch self {
        case .notLink:
            NSLocalizedString("Only TrustChat links can be used to connect.", comment: "alert message")
        case let .foreignServer(host):
            String.localizedStringWithFormat(
                NSLocalizedString("This link uses the server %@, which is not the TrustChat server. Ask your contact for a TrustChat link.", comment: "alert message"),
                host
            )
        case let .wrongIdentity(host):
            String.localizedStringWithFormat(
                NSLocalizedString("This link names the TrustChat server %@ with a different port or fingerprint. Ask your contact for a new TrustChat link.", comment: "alert message"),
                host
            )
        }
    }
}

extension TrustChatConfig {
    // Rejects any connection link whose servers are not exactly the TrustChat SMP (host, port and fingerprint)
    // before the core sees it, so no name is resolved and no socket is opened for a foreign link.
    // SimpleX names (@name) are rejected too: they resolve on the network.
    func validateLink(_ text: String) throws {
        let smp = try smpAddress().parsed
        for s in try trustChatLinkServers(text) {
            let host = s.hostnames.first ?? "?"
            guard s.hostnames == smp.hostnames else { throw TrustChatLinkError.foreignServer(host) }
            guard s.port == smp.port, base64Unpadded(s.keyHash) == base64Unpadded(smp.keyHash)
            else { throw TrustChatLinkError.wrongIdentity(host) }
        }
    }
}

private func base64Unpadded(_ s: String) -> String {
    s.trimmingCharacters(in: CharacterSet(charactersIn: "="))
}

// Servers named by a link, parsed offline. Full links (simplex:/invitation#/?v=…&smp=q1;q2, simplex:/contact#…, or their
// https://simplex.chat/… form) name their queues in `smp`; short links (https://host/i#…?p=…&c=…, simplex:/i#…?h=…&p=…&c=…)
// name the server by authority or `h`, with port `p` and key hash `c` (both absent for SimpleX preset domains).
private func trustChatLinkServers(_ text: String) throws -> [ServerAddress] {
    let link = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let hash = link.firstIndex(of: "#") else { throw TrustChatLinkError.notLink }
    let head = String(link[..<hash])
    let fragment = String(link[link.index(after: hash)...])
    var host: String? = nil
    let path: String
    if head.hasPrefix("simplex:/") {
        path = String(head.dropFirst("simplex:/".count))
    } else if head.hasPrefix("https://") {
        let rest = head.dropFirst("https://".count)
        guard let slash = rest.firstIndex(of: "/") else { throw TrustChatLinkError.notLink }
        host = String(rest[..<slash])
        path = String(rest[rest.index(after: slash)...])
    } else {
        throw TrustChatLinkError.notLink
    }
    let params = trustChatLinkParams(fragment)
    switch path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) {
    case "invitation", "contact":
        guard let smp = params["smp"], !smp.isEmpty else { throw TrustChatLinkError.notLink }
        return try smp.split(separator: ";").map { q in
            guard let s = trustChatQueueServer(String(q)) else { throw TrustChatLinkError.notLink }
            return s
        }
    case let t where t.count == 1:
        var hosts: [String] = []
        if let host { hosts.append(host) }
        if let h = params["h"] { hosts += h.split(separator: ",").map(String.init) }
        guard !hosts.isEmpty else { throw TrustChatLinkError.notLink }
        return [ServerAddress(serverProtocol: .smp, hostnames: hosts, port: params["p"] ?? "", keyHash: params["c"] ?? "")]
    default:
        throw TrustChatLinkError.notLink
    }
}

private func trustChatLinkParams(_ fragment: String) -> [String: String] {
    guard let q = fragment.firstIndex(of: "?") else { return [:] }
    var params: [String: String] = [:]
    for kv in fragment[fragment.index(after: q)...].split(separator: "&") {
        let parts = kv.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { continue }
        params[String(parts[0])] = String(parts[1]).removingPercentEncoding ?? String(parts[1])
    }
    return params
}

// smp://<keyHash>@<hosts>:<port>/<queueId>#… → the server part, parsed by the core's offline parser
private func trustChatQueueServer(_ queueUri: String) -> ServerAddress? {
    guard queueUri.hasPrefix("smp://") else { return nil }
    let authority = queueUri.dropFirst("smp://".count).prefix { $0 != "/" }
    return parseServerAddress("smp://" + authority)
}
