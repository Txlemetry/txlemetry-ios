//
//  TxlemetryAppLifeCycleIntegration.swift
//  Txlemetry
//
//  Created by Ioannis Josephides on 19/02/2025.
//

import Foundation

/**
 Add capability to capture application lifecycle events.

 This integration:
 - captures an `App Installed` event on the first launch of the app
 - captures an `App Updated` event on any subsequent launch with a different version
 - captures an `App Opened` event when the app is opened (including the first launch)
 - captures an `App Backgrounded` event when the app moves to the background
 */
final class TxlemetryAppLifeCycleIntegration: TxlemetryIntegration {
    var requiresSwizzling: Bool { false }

    private static let integrationInstallState = TxlemetryIntegrationInstallState()
    private static let versionLock = NSLock()
    private static var didRecordAppVersion = false
    private static var pendingInstallOrUpdate: (event: String, properties: [String: Any])?

    private weak var txlemetry: TxlemetrySDK?
    private var ownsLifecycleCapture = false

    // True if the app is launched for the first time
    private var isFreshAppLaunch = true
    // Manually maintained flag to determine background status of the app
    private var isAppBackgrounded: Bool = true

    private var didBecomeActiveToken: RegistrationToken?
    private var didEnterBackgroundToken: RegistrationToken?
    private var didFinishLaunchingToken: RegistrationToken?

    func install(_ txlemetry: TxlemetrySDK) -> TxlemetryIntegrationInstallResult {
        Self.versionLock.withLock {
            Self.recordAppVersion()
        }
        guard txlemetry.config.captureApplicationLifecycleEvents else {
            return .installed
        }

        return installIfNeeded(using: Self.integrationInstallState) {
            ownsLifecycleCapture = true
            self.txlemetry = txlemetry

            start()
            captureAppInstallOrUpdated()
        }
    }

    func uninstall(_ txlemetry: TxlemetrySDK) {
        // The weak SDK reference is already nil when uninstall runs from SDK deinit.
        guard ownsLifecycleCapture else { return }

        uninstallIfNeeded(from: txlemetry, installedTxlemetry: self.txlemetry, state: Self.integrationInstallState) {
            // uninstall only for integration instance
            stop()
            self.txlemetry = nil
            ownsLifecycleCapture = false
        }
    }

    /**
     Start capturing app lifecycles events
     */
    func start() {
        let publisher = DI.main.appLifecyclePublisher
        didFinishLaunchingToken = publisher.onDidFinishLaunching.subscribe { [weak self] in
            self?.captureAppInstallOrUpdated()
        }
        didBecomeActiveToken = publisher.onDidBecomeActive.subscribe { [weak self] in
            self?.captureAppOpened()
        }
        didEnterBackgroundToken = publisher.onDidEnterBackground.subscribe { [weak self] in
            self?.captureAppBackgrounded()
        }
    }

    /**
     Stop capturing app lifecycle events
     */
    func stop() {
        didFinishLaunchingToken = nil
        didBecomeActiveToken = nil
        didEnterBackgroundToken = nil
    }

    private func captureAppInstallOrUpdated() {
        guard let txlemetry, txlemetry.config.captureApplicationLifecycleEvents else { return }

        let pending = Self.versionLock.withLock {
            let pending = Self.pendingInstallOrUpdate
            Self.pendingInstallOrUpdate = nil
            return pending
        }
        if let pending {
            txlemetry.capture(pending.event, properties: pending.properties)
        }
    }

    private static func recordAppVersion() {
        guard !didRecordAppVersion else { return }
        didRecordAppVersion = true

        let bundle = Bundle.main

        let versionName = appVersionString()
        let versionCode = bundle.infoDictionary?["CFBundleVersion"] as? String

        // capture app installed/updated
        let userDefaults = UserDefaults.standard

        let previousVersion = userDefaults.string(forKey: "PHGVersionKey")
        let previousVersionCode = userDefaults.string(forKey: "PHGBuildKeyV2")

        // Save this launch even when event capture is disabled, comparing against the previous values below.
        var syncDefaults = false
        if let versionName {
            userDefaults.setValue(versionName, forKey: "PHGVersionKey")
            syncDefaults = true
        }
        if let versionCode {
            userDefaults.setValue(versionCode, forKey: "PHGBuildKeyV2")
            syncDefaults = true
        }
        if syncDefaults {
            userDefaults.synchronize()
        }

        var props: [String: Any] = [:]
        var event: String
        if previousVersionCode == nil {
            // installed
            event = "Application Installed"
        } else {
            event = "Application Updated"

            // Do not send version updates if its the same
            if previousVersionCode == versionCode {
                return
            }

            if previousVersion != nil {
                props["previous_version"] = previousVersion
            }
            if let previousVersionCode {
                props["previous_build"] = parseBundleVersion(previousVersionCode)
            }
        }

        if let versionName {
            props["version"] = versionName
        }
        if let versionCode {
            props["build"] = parseBundleVersion(versionCode)
        }

        // Keep the launch comparison for the first capture-enabled client in this process.
        pendingInstallOrUpdate = (event, props)
    }

    private func captureAppOpened() {
        guard let txlemetry else { return }

        guard isAppBackgrounded else {
            hedgeLog("Skipping Application Opened event - app already in foreground")
            return
        }

        isAppBackgrounded = false

        if !txlemetry.config.captureApplicationLifecycleEvents {
            hedgeLog("Skipping Application Opened event - captureApplicationLifecycleEvents is disabled in configuration")
            return
        }

        var props: [String: Any] = [:]
        props["from_background"] = !isFreshAppLaunch

        if isFreshAppLaunch {
            let bundle = Bundle.main

            let versionName = appVersionString()
            let versionCode = bundle.infoDictionary?["CFBundleVersion"] as? String

            if versionName != nil {
                props["version"] = versionName
            }
            if let versionCode {
                props["build"] = parseBundleVersion(versionCode)
            }

            isFreshAppLaunch = false
        }

        txlemetry.capture("Application Opened", properties: props)
    }

    private func captureAppBackgrounded() {
        guard let txlemetry else { return }

        guard !isAppBackgrounded else {
            hedgeLog("Skipping Application Opened event - app already in background")
            return
        }

        isAppBackgrounded = true

        if !txlemetry.config.captureApplicationLifecycleEvents {
            hedgeLog("Skipping Application Backgrounded event - captureApplicationLifecycleEvents is disabled in configuration")
            return
        }

        txlemetry.capture("Application Backgrounded")
    }
}

#if TESTING
    extension TxlemetryAppLifeCycleIntegration {
        static func clearInstalls() {
            versionLock.withLock {
                didRecordAppVersion = false
                pendingInstallOrUpdate = nil
            }
            integrationInstallState.clear()
        }
    }
#endif
