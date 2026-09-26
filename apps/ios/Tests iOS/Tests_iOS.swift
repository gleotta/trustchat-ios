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
