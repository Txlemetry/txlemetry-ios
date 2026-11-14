//
//  TxlemetryConfigTest.swift
//  TxlemetryTests
//
//  Created by Manoel Aranda Neto on 30.10.23.
//

import Foundation
import Nimble
@_spi(TxlemetryInternal) @testable import Txlemetry
import Quick

class TxlemetryConfigTest: QuickSpec {
    override func spec() {
        it("init config with default values") {
            let config = TxlemetryConfig(projectToken: testProjectToken)

            expect(config.host) == URL(string: TxlemetryConfig.defaultHost)
            expect(config.flushAt) == 20
            expect(config.maxQueueSize) == 1000
            expect(config.maxBatchSize) == 50
            expect(config.flushIntervalSeconds) == 30
            expect(config.dataMode) == .any
            expect(config.sendFeatureFlagEvent) == true
            expect(config.preloadFeatureFlags) == true
            expect(config.captureApplicationLifecycleEvents) == true
            expect(config.captureScreenViews) == true
            expect(config.debug) == false
            expect(config.optOut) == false
            expect(config.persistOptOut) == true

            #if os(iOS) || os(macOS)
                expect(config.capturePushNotificationSubscriptions) == true
                expect(config.capturePushNotificationOpened) == true
            #endif
            expect(config.pushIdentityProvider).to(beNil())
        }

        it("init takes project token") {
            let config = TxlemetryConfig(projectToken: testProjectToken)

            expect(config.projectToken) == testProjectToken
            expect(config.apiKey) == testProjectToken
        }

        it("deprecated init(apiKey:) maps to project token") {
            let config = TxlemetryConfig(apiKey: testProjectToken)

            expect(config.projectToken) == testProjectToken
            expect(config.apiKey) == testProjectToken
            expect(config.host) == URL(string: TxlemetryConfig.defaultHost)
        }

        it("deprecated init(apiKey:host:) maps to project token and host") {
            let config = TxlemetryConfig(apiKey: testProjectToken, host: "localhost:9000")

            expect(config.projectToken) == testProjectToken
            expect(config.apiKey) == testProjectToken
            expect(config.host) == URL(string: "localhost:9000")!
        }

        it("deprecated init(apiKey:host:) trims whitespace-sensitive values") {
            let config = TxlemetryConfig(
                apiKey: " \n\(testProjectToken)\t ",
                host: " \nhttps://app.txlemetry.com/\t "
            )

            expect(config.projectToken) == testProjectToken
            expect(config.apiKey) == testProjectToken
            expect(config.host) == URL(string: "https://app.txlemetry.com/")
        }

        it("trims whitespace-sensitive config values") {
            let config = TxlemetryConfig(
                projectToken: " \n\(testProjectToken)\t ",
                host: " \nhttps://app.txlemetry.com/\t "
            )

            expect(config.projectToken) == testProjectToken
            expect(config.apiKey) == testProjectToken
            expect(config.host) == URL(string: "https://app.txlemetry.com/")
        }

        it("defaults a blank host after trimming whitespace") {
            let config = TxlemetryConfig(projectToken: testProjectToken, host: " \n\t ")

            expect(config.host) == URL(string: TxlemetryConfig.defaultHost)
        }

        it("init takes host") {
            let config = TxlemetryConfig(projectToken: testProjectToken, host: "localhost:9000")

            expect(config.host) == URL(string: "localhost:9000")!
        }

        #if os(iOS)
            context("when initialized with default values for captureElementInteractions") {
                it("should enable autocapture by default") {
                    let sut = TxlemetryConfig(projectToken: testProjectToken)
                    expect(sut.captureElementInteractions).to(beFalse())
                }
            }

            context("when initialized with default tracing headers configuration") {
                it("should disable tracing headers by default") {
                    let sut = TxlemetryConfig(projectToken: testProjectToken)
                    expect(sut.tracingHeaders).to(beNil())
                }
            }

            context("when customized") {
                it("should allow disabling autocapture") {
                    let config = TxlemetryConfig(projectToken: testProjectToken)
                    config.captureElementInteractions = false
                    expect(config.captureElementInteractions).to(beFalse())
                }
            }
        #endif
    }
}
