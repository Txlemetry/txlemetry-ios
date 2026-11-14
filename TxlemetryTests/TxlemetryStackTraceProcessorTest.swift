//
//  TxlemetryStackTraceProcessorTest.swift
//  TxlemetryTests
//
//  Created by Ioannis Josephides on 22/12/2025.
//

import Foundation
@testable import Txlemetry
import Testing

@Suite("TxlemetryStackTraceProcessor Tests")
struct TxlemetryStackTraceProcessorTest {
    // MARK: - In-App Detection Tests

    @Suite("In-App Detection")
    struct InAppDetectionTests {
        @Test("marks module as in-app when in inAppIncludes")
        func marksInAppWhenInIncludes() {
            let config = TxlemetryErrorTrackingConfig()
            config.inAppIncludes = ["MyApp", "SharedModule"]

            #expect(TxlemetryStackTraceProcessor.isInApp(module: "MyApp", config: config) == true)
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "MyAppExtension", config: config) == true)
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "SharedModule", config: config) == true)
        }

        @Test("marks module as not in-app when in inAppExcludes")
        func marksNotInAppWhenInExcludes() {
            let config = TxlemetryErrorTrackingConfig()
            config.inAppExcludes = ["Alamofire", "SDWebImage"]

            #expect(TxlemetryStackTraceProcessor.isInApp(module: "Alamofire", config: config) == false)
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "SDWebImage", config: config) == false)
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "SDWebImageSwiftUI", config: config) == false)
        }

        @Test("inAppIncludes takes precedence over inAppExcludes")
        func includesTakesPrecedenceOverExcludes() {
            let config = TxlemetryErrorTrackingConfig()
            config.inAppIncludes = ["MyModule"]
            config.inAppExcludes = ["MyModule"]

            #expect(TxlemetryStackTraceProcessor.isInApp(module: "MyModule", config: config) == true)
        }

        @Test("marks system frameworks as not in-app")
        func marksSystemFrameworksAsNotInApp() {
            let config = TxlemetryErrorTrackingConfig()

            #expect(TxlemetryStackTraceProcessor.isInApp(module: "Foundation", config: config) == false)
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "UIKit", config: config) == false)
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "CoreFoundation", config: config) == false)
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "SwiftUI", config: config) == false)
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "libsystem_kernel.dylib", config: config) == false)
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "libswiftCore.dylib", config: config) == false)
        }

        @Test("uses inAppByDefault for unknown modules")
        func usesInAppByDefault() {
            let config = TxlemetryErrorTrackingConfig()

            config.inAppByDefault = true
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "UnknownModule", config: config) == true)

            config.inAppByDefault = false
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "UnknownModule", config: config) == false)
        }

        @Test("uses prefix matching for includes")
        func usesPrefixMatchingForIncludes() {
            let config = TxlemetryErrorTrackingConfig()
            config.inAppIncludes = ["com.txlemetry"]
            config.inAppByDefault = false

            #expect(TxlemetryStackTraceProcessor.isInApp(module: "com.txlemetry.sdk", config: config) == true)
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "com.txlemetry", config: config) == true)
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "com.other", config: config) == false)
        }

        @Test("uses prefix matching for excludes")
        func usesPrefixMatchingForExcludes() {
            let config = TxlemetryErrorTrackingConfig()
            config.inAppExcludes = ["Firebase"]

            #expect(TxlemetryStackTraceProcessor.isInApp(module: "FirebaseCore", config: config) == false)
            #expect(TxlemetryStackTraceProcessor.isInApp(module: "FirebaseAnalytics", config: config) == false)
        }
    }

    // MARK: - Stack Trace Capture Tests

    @Suite("Stack Trace Capture")
    struct StackTraceCaptureTests {
        @Test("captures current stack trace")
        func capturesCurrentStackTrace() {
            let config = TxlemetryErrorTrackingConfig()
            let frames = TxlemetryStackTraceProcessor.captureCurrentStackTraceWithMetadata(config: config)

            #expect(frames.count > 0)
        }

        @Test("captured frames have instruction addresses")
        func framesHaveInstructionAddresses() {
            let config = TxlemetryErrorTrackingConfig()
            let frames = TxlemetryStackTraceProcessor.captureCurrentStackTraceWithMetadata(config: config)

            for frame in frames {
                #expect(frame.instructionAddress > 0)
            }
        }

        @Test("captured frames have module info")
        func framesHaveModuleInfo() {
            let config = TxlemetryErrorTrackingConfig()
            let frames = TxlemetryStackTraceProcessor.captureCurrentStackTraceWithMetadata(config: config)

            let framesWithModule = frames.filter { $0.module != nil }
            #expect(framesWithModule.count > 0)
        }

        @Test("strips Txlemetry frames from top of stack")
        func stripsTxlemetryFrames() {
            let config = TxlemetryErrorTrackingConfig()
            let frames = TxlemetryStackTraceProcessor.captureCurrentStackTraceWithMetadata(config: config)

            let topFrame = frames.first
            #expect(topFrame?.module != "Txlemetry")
        }
    }

    // MARK: - Symbolicate Addresses Tests

    @Suite("Symbolicate Addresses")
    struct SymbolicateAddressesTests {
        @Test("symbolicates array of addresses")
        func symbolicatesAddresses() {
            let config = TxlemetryErrorTrackingConfig()
            let addresses = Thread.callStackReturnAddresses

            let frames = TxlemetryStackTraceProcessor.symbolicateAddresses(
                addresses,
                config: config,
                stripTopTxlemetryFrames: false
            )

            #expect(frames.count > 0)
        }

        @Test("respects stripTopTxlemetryFrames parameter")
        func respectsStripParameter() {
            let config = TxlemetryErrorTrackingConfig()
            let addresses = Thread.callStackReturnAddresses

            let framesWithStrip = TxlemetryStackTraceProcessor.symbolicateAddresses(
                addresses,
                config: config,
                stripTopTxlemetryFrames: true
            )

            let framesWithoutStrip = TxlemetryStackTraceProcessor.symbolicateAddresses(
                addresses,
                config: config,
                stripTopTxlemetryFrames: false
            )

            #expect(framesWithStrip.count <= framesWithoutStrip.count)
        }
    }

    // MARK: - Frame Dictionary Tests

    @Suite("Frame Dictionary Conversion")
    struct FrameDictionaryTests {
        @Test("converts frame to dictionary with required fields")
        func convertsToDictionaryWithRequiredFields() {
            let frame = TxlemetryStackFrame(
                instructionAddress: 0x100_0000,
                module: "TestModule",
                package: "/path/to/TestModule",
                imageAddress: 0x100_0000,
                inApp: true,
                function: "testFunction",
                symbolAddress: 0x100_0000
            )

            let dict = frame.toDictionary

            #expect(dict["instruction_addr"] as? String == "0x0000000001000000")
            #expect(dict["platform"] as? String == "apple")
            #expect(dict["in_app"] as? Bool == true)
            #expect(dict["module"] as? String == "TestModule")
            #expect(dict["package"] as? String == "/path/to/TestModule")
            #expect(dict["function"] as? String == "testFunction")
        }

        @Test("omits nil fields from dictionary")
        func omitsNilFields() {
            let frame = TxlemetryStackFrame(
                instructionAddress: 0x100_0000,
                module: nil,
                package: nil,
                imageAddress: nil,
                inApp: false,
                function: nil,
                symbolAddress: nil
            )

            let dict = frame.toDictionary

            #expect(dict["instruction_addr"] != nil)
            #expect(dict["platform"] != nil)
            #expect(dict["in_app"] != nil)
            #expect(dict["module"] == nil)
            #expect(dict["package"] == nil)
            #expect(dict["function"] == nil)
            #expect(dict["image_addr"] == nil)
            #expect(dict["symbol_addr"] == nil)
        }

        @Test("formats addresses as hex strings")
        func formatsAddressesAsHex() {
            let frame = TxlemetryStackFrame(
                instructionAddress: 0x7FFF_1234_5678,
                module: "Test",
                package: nil,
                imageAddress: 0x7FFF_0000_0000,
                inApp: true,
                function: nil,
                symbolAddress: 0x7FFF_1234_5000
            )

            let dict = frame.toDictionary

            #expect((dict["instruction_addr"] as? String)?.hasPrefix("0x") == true)
            #expect((dict["image_addr"] as? String)?.hasPrefix("0x") == true)
            #expect((dict["symbol_addr"] as? String)?.hasPrefix("0x") == true)
        }
    }
}
