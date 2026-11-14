//
//  TxlemetryScreenViewIntegration.swift
//  Txlemetry
//
//  Created by Ioannis Josephides on 20/02/2025.
//

import Foundation

final class TxlemetryScreenViewIntegration: TxlemetryIntegration {
    var requiresSwizzling: Bool { true }

    private static let integrationInstallState = TxlemetryIntegrationInstallState()

    private weak var txlemetry: TxlemetrySDK?

    func install(_ txlemetry: TxlemetrySDK) -> TxlemetryIntegrationInstallResult {
        installIfNeeded(using: Self.integrationInstallState) {
            self.txlemetry = txlemetry

            start()
        }
    }

    func uninstall(_ txlemetry: TxlemetrySDK) {
        uninstallIfNeeded(from: txlemetry, installedTxlemetry: self.txlemetry, state: Self.integrationInstallState) {
            // uninstall only for integration instance
            stop()
            self.txlemetry = nil
        }
    }

    func start() {
        // We own the swizzle directly via startAutoCapture rather than
        // subscribing to onScreenView. Subscribing would put us downstream of
        // TxlemetrySDK.screen()'s own publisher invoke, so every manual
        // screen() call would fire two events instead of one.
        DI.main.screenViewPublisher.startAutoCapture { [weak self] screenName in
            self?.txlemetry?.screen(screenName)
        }
    }

    func stop() {
        DI.main.screenViewPublisher.stopAutoCapture()
    }
}

#if TESTING
    extension TxlemetryScreenViewIntegration {
        static func clearInstalls() {
            integrationInstallState.clear()
        }
    }
#endif
