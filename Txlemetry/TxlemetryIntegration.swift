//
//  TxlemetryIntegration.swift
//  Txlemetry
//
//  Created by Ioannis Josephides on 25/02/2025.
//
import Foundation

enum TxlemetryIntegrationInstallSkipReason: String, CustomStringConvertible {
    var description: String { rawValue }

    case alreadyInstalled = "Already installed to another TxlemetrySDK instance"
    case disabledByRemoteConfig = "Disabled in remote config"
    case notAvailableOnPlatform = "Not available on this platform"
}

enum TxlemetryIntegrationInstallResult: Equatable {
    case installed
    case skipped(TxlemetryIntegrationInstallSkipReason)
}

final class TxlemetryIntegrationInstallState {
    private let lock = NSLock()
    private var installed = false

    func markInstalled() -> Bool {
        lock.withLock {
            if installed {
                return false
            }
            installed = true
            return true
        }
    }

    func clear() {
        lock.withLock {
            installed = false
        }
    }
}

protocol TxlemetryIntegration: AnyObject {
    /**
     * Indicates whether this integration requires method swizzling to function.
     *
     * When `enableSwizzling` is set to `false` in TxlemetryConfig, integrations
     * that return `true` for this property will be skipped during installation.
     */
    var requiresSwizzling: Bool { get }

    /**
     * Installs and initializes the integration with a TxlemetrySDK instance.
     *
     * This method should:
     * 1. Run checks if needed to ensure that the integration is only installed once
     * 2. Initialize any required resources
     * 3. Start the integration's functionality
     *
     * - Parameter txlemetry: The TxlemetrySDK instance to integrate with
     * - Returns: `.installed` when installation succeeds, `.skipped(reason:)` when it doesn't
     */
    func install(_ txlemetry: TxlemetrySDK) -> TxlemetryIntegrationInstallResult

    /**
     * Uninstalls the integration from a specific TxlemetrySDK instance.
     *
     * This method should:
     * 1. Stop all integration functionality
     * 2. Clean up any resources
     * 3. Remove references to the Txlemetry instance
     *
     * - Parameter txlemetry: The Txlemetry SDK instance to uninstall from
     */
    func uninstall(_ txlemetry: TxlemetrySDK)

    /**
     * Starts the integration's functionality.
     *
     * Note: This is typically called automatically during installation
     * but may be called manually to restart a stopped integration.
     */
    func start()

    /**
     * Stops the integration's functionality without uninstalling.
     *
     * Note: This is typically called automatically during uninstallation
     * but may be called manually to temporarily suspend the integration
     * while maintaining its installation status (e.g manual start/stop for session recording)
     */
    func stop()
}

extension TxlemetryIntegration {
    func installIfNeeded(
        using state: TxlemetryIntegrationInstallState,
        _ install: () -> Void
    ) -> TxlemetryIntegrationInstallResult {
        guard state.markInstalled() else {
            return .skipped(.alreadyInstalled)
        }

        install()
        return .installed
    }

    func uninstallIfNeeded(
        from txlemetry: TxlemetrySDK,
        installedTxlemetry: TxlemetrySDK?,
        state: TxlemetryIntegrationInstallState,
        _ uninstall: () -> Void
    ) {
        guard installedTxlemetry === txlemetry || installedTxlemetry == nil else {
            return
        }

        uninstall()
        state.clear()
    }
}
