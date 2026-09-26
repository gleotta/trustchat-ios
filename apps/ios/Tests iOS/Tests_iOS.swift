//
//  Tests_iOS.swift
//  Tests iOS
//
//  Created by Evgeny Poberezkin on 17/01/2022.
//

import XCTest

class Tests_iOS: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // TrustChat IT-06 / TC-01: a fresh install must create its first invitation link on the TrustChat SMP,
    // without any SimpleX preset server. Onboarding steps 3-4 (operators, conditions) must not appear.
    func testTrustChatServersPolicy() throws {
        let app = XCUIApplication()
        app.launch()
        let trustChatHost = "iriguchi.proxy.rlwy.net"

        let getStarted = app.buttons["Get started"]
        let newChatButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'compose' OR label CONTAINS[c] 'pencil' OR label CONTAINS[c] 'new chat'")).firstMatch
        let deadline = Date().addingTimeInterval(180)
        while Date() < deadline && !getStarted.exists && !newChatButton.exists { sleep(1) }
        attach(app, "01-first-screen")

        if getStarted.exists {
            getStarted.tap()
            let nameField = app.textFields["Enter profile name..."]
            XCTAssertTrue(nameField.waitForExistence(timeout: 30), "profile name field")
            nameField.tap()
            nameField.typeText("Alice")
            attach(app, "02-create-profile")
            app.buttons["Create profile"].tap()
        }

        XCTAssertTrue(newChatButton.waitForExistence(timeout: 180), "chat list after onboarding; buttons: \(app.buttons.allElementsBoundByIndex.map { $0.label })")
        XCTAssertFalse(app.staticTexts["Conditions of use"].exists, "operator conditions step must be skipped")
        // upstream "What's new" sheet covers the chat list on first run
        let okButton = app.buttons["Ok"]
        if okButton.waitForExistence(timeout: 5) { okButton.tap() }
        attach(app, "03-chat-list")

        let inviteCard = app.buttons["Let someone connect to you"]
        if inviteCard.waitForExistence(timeout: 10) {
            inviteCard.tap()
            // first-use invitation view asks for the link type before creating it
            let privateInvite = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Invite someone privately'")).firstMatch
            if privateInvite.waitForExistence(timeout: 15) { privateInvite.tap() }
        } else {
            app.buttons["Compose"].tap()
            let createLink = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Create 1-time link'")).firstMatch
            XCTAssertTrue(createLink.waitForExistence(timeout: 30), "new chat sheet")
            createLink.tap()
        }

        let linkText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", trustChatHost)).firstMatch
        XCTAssertTrue(linkText.waitForExistence(timeout: 120), "invitation link on TrustChat SMP; texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        attach(app, "04-invitation-link")
        let link = linkText.label
        let linkAttachment = XCTAttachment(string: link)
        linkAttachment.name = "invitation-link"
        linkAttachment.lifetime = .keepAlways
        add(linkAttachment)
        XCTAssertTrue(link.contains(trustChatHost))
        XCTAssertFalse(link.contains("simplex.im"), "link must not reference SimpleX servers")
        XCTAssertFalse(link.contains("simplexonflux.com"), "link must not reference Flux servers")
        let foreign = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'simplex.im' OR label CONTAINS[c] 'simplexonflux.com'"))
        XCTAssertEqual(foreign.count, 0, "no SimpleX host on screen")
    }

    // TrustChat IT-06 evidence: "Test server" for the preset XFTP server in Settings > Network & servers > Your servers.
    // If TEST_RUNNER_TRUSTCHAT_TEST_XFTP_ADDRESS is set (an xftp:// address, possibly with a create password),
    // it is also added manually and tested. The address never lives in the repository.
    func testTrustChatXFTPServerTest() throws {
        let app = XCUIApplication()
        app.launch()
        let trustChatHost = "iriguchi.proxy.rlwy.net"

        let newChatButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'compose' OR label CONTAINS[c] 'pencil' OR label CONTAINS[c] 'new chat'")).firstMatch
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 180), "chat list; buttons: \(app.buttons.allElementsBoundByIndex.map { $0.label })")
        let okButton = app.buttons["Ok"]
        if okButton.waitForExistence(timeout: 5) { okButton.tap() }

        openSettings(app)
        tapRow(app, "Network & servers")
        tapRow(app, "Your servers")
        attach(app, "01-your-servers")

        // SMP section comes before the XFTP section; both rows show the same host
        var hostRows = app.buttons.matching(NSPredicate(format: "label == %@", trustChatHost))
        if hostRows.count == 0 { hostRows = app.staticTexts.matching(NSPredicate(format: "label == %@", trustChatHost)) }
        let rows = hostRows.allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(rows.count, 2, "SMP and XFTP rows; texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        rows.last!.tap()
        if !app.navigationBars["XFTP server"].waitForExistence(timeout: 10) {
            app.buttons["Your servers"].firstMatch.tap()
            rows.first!.tap()
            XCTAssertTrue(app.navigationBars["XFTP server"].waitForExistence(timeout: 10), "XFTP server view")
        }
        attach(app, "02-xftp-server")
        let presetResult = runServerTest(app, "03-xftp-preset-test")
        app.buttons["Your servers"].firstMatch.tap()

        var manualResult: String? = "not run"
        if let addr = ProcessInfo.processInfo.environment["TRUSTCHAT_TEST_XFTP_ADDRESS"], !addr.isEmpty {
            app.buttons["Add server"].tap()
            let manual = app.buttons["Enter server manually"]
            XCTAssertTrue(manual.waitForExistence(timeout: 10), "add server dialog")
            manual.tap()
            let editor = app.textViews.firstMatch
            XCTAssertTrue(editor.waitForExistence(timeout: 10), "server address editor")
            editor.tap()
            editor.typeText(addr)
            attach(app, "04-xftp-manual-address")
            manualResult = runServerTest(app, "05-xftp-manual-test")
        }
        let summary = XCTAttachment(string: "preset: \(presetResult ?? "PASSED")\nmanual: \(manualResult ?? "PASSED")")
        summary.name = "xftp-test-summary"
        summary.lifetime = .keepAlways
        add(summary)
    }

    // TrustChat IT-07 / TC-07: links naming any server other than the TrustChat SMP are rejected before the core
    // sees them; a link on the TrustChat SMP passes the validator (the core then answers about the link itself).
    func testTrustChatRejectsForeignLink() throws {
        let app = XCUIApplication()
        app.launch()
        let trustChatHost = "iriguchi.proxy.rlwy.net"
        let newChatButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'compose' OR label CONTAINS[c] 'pencil' OR label CONTAINS[c] 'new chat'")).firstMatch
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 180), "chat list")
        let okButton = app.buttons["Ok"]
        if okButton.waitForExistence(timeout: 5) { okButton.tap() }

        // 1. the SimpleX team address (simplex: scheme short link, host in h=, preset domain: no port, no fingerprint)
        let msg1 = expectRejected(app, "simplex:/a#lrdvu2d8A1GumSmoKb2krQmtKhWXq-tyGpHuM7aMwsw?h=smp6.simplex.im", "01-simplex-team-link-rejected")
        XCTAssertTrue(msg1.contains("smp6.simplex.im"), "message names the foreign server: \(msg1)")

        // 2. the same address as an https short link on the SimpleX preset domain
        _ = expectRejected(app, "https://smp6.simplex.im/a#lrdvu2d8A1GumSmoKb2krQmtKhWXq-tyGpHuM7aMwsw", "02-preset-domain-link-rejected")

        // 3. the profile's own one-time link (TrustChat SMP) passes the validator. The "New chat" sheet left open by
        // the paste flow has a "Create 1-time link" segment; the chat-list card is the fallback on a fresh list.
        var ownLink: String? = nil
        let linkText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", trustChatHost)).firstMatch
        let createSegment = app.buttons.matching(NSPredicate(format: "label == '1-time link' OR label == 'Create 1-time link'")).firstMatch
        let inviteCard = app.buttons["Let someone connect to you"]
        if createSegment.waitForExistence(timeout: 5) {
            createSegment.tap()
            if linkText.waitForExistence(timeout: 120) { ownLink = linkText.label }
            attach(app, "03-own-link")
        } else if inviteCard.waitForExistence(timeout: 10) {
            inviteCard.tap()
            let privateInvite = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Invite someone privately'")).firstMatch
            if privateInvite.waitForExistence(timeout: 15) { privateInvite.tap() }
            if linkText.waitForExistence(timeout: 120) { ownLink = linkText.label }
            attach(app, "03-own-link")
            let back = app.buttons["Back"]
            if back.waitForExistence(timeout: 5) { back.tap() }
        } else {
            attach(app, "03-no-own-link-entry")
        }
        guard let ownLink, let cRange = ownLink.range(of: "c=") else {
            let a = XCTAttachment(string: "own link not available on this run; positive and wrong-fingerprint cases skipped")
            a.name = "note"; a.lifetime = .keepAlways; add(a)
            return
        }
        let ownAttachment = XCTAttachment(string: ownLink)
        ownAttachment.name = "own-link"; ownAttachment.lifetime = .keepAlways; add(ownAttachment)
        pasteLink(app, ownLink)
        let rejected = app.alerts["Not a TrustChat link"]
        XCTAssertFalse(rejected.waitForExistence(timeout: 30), "own TrustChat link must not be rejected")
        attach(app, "04-own-link-accepted")
        let anyAlert = app.alerts.firstMatch
        if anyAlert.exists { anyAlert.buttons.firstMatch.tap() }

        // 4. the own link with a different fingerprint (same host and port) is rejected; relaunch to a clean chat list
        app.terminate()
        app.launch()
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 180), "chat list after relaunch")
        if okButton.waitForExistence(timeout: 5) { okButton.tap() }
        let fpStart = cRange.upperBound
        let fpEnd = ownLink.index(fpStart, offsetBy: 4, limitedBy: ownLink.endIndex) ?? ownLink.endIndex
        let replacement = ownLink[fpStart..<fpEnd] == "AAAA" ? "BBBB" : "AAAA"
        let wrongFingerprint = ownLink.replacingCharacters(in: fpStart..<fpEnd, with: replacement)
        let msg4 = expectRejected(app, wrongFingerprint, "05-wrong-fingerprint-rejected")
        XCTAssertTrue(msg4.contains(trustChatHost), "message names the host: \(msg4)")
    }

    // Full link (simplex:/contact#/?v=…&smp=…) naming a queue on a SimpleX server: parsed via the smp= queue URIs.
    func testTrustChatRejectsForeignFullLink() throws {
        let app = XCUIApplication()
        app.launch()
        let newChatButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'compose' OR label CONTAINS[c] 'pencil' OR label CONTAINS[c] 'new chat'")).firstMatch
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 180), "chat list")
        let okButton = app.buttons["Ok"]
        if okButton.waitForExistence(timeout: 5) { okButton.tap() }
        // synthetic but well-formed queue: 32-byte key hash, 32-byte queue id, X25519 public key
        let queue = "smp://u2dS9sG8nMNURyZwqASV4yROM28Er0luVTx5X1CsMrU=@smp4.simplex.im/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=#/?v=1-4&dh=MCowBQYDK2VuAyEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        let encoded = queue.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~")))!
        let msg = expectRejected(app, "simplex:/contact#/?v=2-7&smp=\(encoded)", "01-foreign-full-link-rejected")
        XCTAssertTrue(msg.contains("smp4.simplex.im"), "message names the foreign server: \(msg)")
    }

    /// Enters the link, waits for the TrustChat rejection alert, attaches a screenshot and returns the alert text.
    private func expectRejected(_ app: XCUIApplication, _ link: String, _ name: String) -> String {
        pasteLink(app, link)
        let alert = app.alerts["Not a TrustChat link"]
        XCTAssertTrue(alert.waitForExistence(timeout: 60), "\(name): rejection alert; alerts: \(app.alerts.allElementsBoundByIndex.map { $0.label }); texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        let msg = alert.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " | ")
        attach(app, name)
        let a = XCTAttachment(string: msg)
        a.name = name + "-alert"; a.lifetime = .keepAlways; add(a)
        if alert.exists { alert.buttons.firstMatch.tap() }
        return msg
    }

    // Pastes the link through Compose → "Scan / Paste link" → "Tap to paste link". The pasteboard is set by the test
    // runner, so iOS asks the user to allow the paste (SpringBoard alert) while the app's main thread waits.
    // Typing into the search field is not usable: the app connects as soon as a prefix of the text parses as a link.
    private func pasteLink(_ app: XCUIApplication, _ link: String) {
        UIPasteboard.general.string = link
        let paste = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Tap to paste link'")).firstMatch
        let connectSegment = app.buttons["Connect via link"]
        if !paste.exists && connectSegment.exists { connectSegment.tap() }
        if !paste.waitForExistence(timeout: 5) {
            for label in ["Back", "Cancel", "Close"] {
                let b = app.buttons[label]
                if b.exists && b.isHittable { b.tap(); break }
            }
            let card = app.buttons["Connect via link or QR code"]
            let compose = app.buttons["Compose"]
            if card.waitForExistence(timeout: 5) {
                card.tap()
            } else if compose.waitForExistence(timeout: 10) {
                compose.tap()
                let scanPaste = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Scan / Paste link'")).firstMatch
                XCTAssertTrue(scanPaste.waitForExistence(timeout: 30), "Scan / Paste link entry; texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
                scanPaste.tap()
            } else {
                XCTFail("neither the connect card nor the Compose button is visible; buttons: \(app.buttons.allElementsBoundByIndex.map { $0.label })")
            }
        }
        XCTAssertTrue(paste.waitForExistence(timeout: 30), "paste button; texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        paste.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow Paste"]
        if allow.waitForExistence(timeout: 20) { allow.tap() }
    }

    private func openSettings(_ app: XCUIApplication) {
        let settings = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Settings'")).firstMatch
        let avatar = app.toolbars.firstMatch.images.firstMatch
        if avatar.exists { avatar.tap() }
        if !settings.waitForExistence(timeout: 10) {
            // profile image at the leading edge of the bottom toolbar
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.077, dy: 0.937)).tap()
        }
        XCTAssertTrue(settings.waitForExistence(timeout: 15), "user picker; texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        settings.tap()
    }

    private func tapRow(_ app: XCUIApplication, _ label: String) {
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "row \(label); texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        row.tap()
    }

    /// Taps "Test server" and returns the failure alert text, or nil when the test passed.
    private func runServerTest(_ app: XCUIApplication, _ name: String) -> String? {
        let testButton = app.buttons["Test server"]
        XCTAssertTrue(testButton.waitForExistence(timeout: 10), "Test server button")
        XCTAssertTrue(testButton.isEnabled, "Test server enabled (valid address)")
        testButton.tap()
        sleep(2)
        let alert = app.alerts.firstMatch
        let deadline = Date().addingTimeInterval(180)
        while Date() < deadline && !alert.exists && !testButton.isEnabled { sleep(1) }
        attach(app, name)
        var result: String? = nil
        if alert.exists {
            result = alert.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " | ")
            alert.buttons.firstMatch.tap()
        }
        let a = XCTAttachment(string: result ?? "PASSED (no alert)")
        a.name = name + "-result"
        a.lifetime = .keepAlways
        add(a)
        return result
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
