//
//  TxlemetryDeepLinkListener.swift
//  Txlemetry
//
//  Created by Jeremiah Erinola on 23.02.26.
//

#if canImport(SwiftUI)
    import Foundation
    import SwiftUI

    /// A SwiftUI ViewModifier that listens for deep link events and forwards them to Txlemetry.
    private struct TxlemetryDeepLinkListener: ViewModifier {
        let txlemetry: TxlemetrySDK?

        func body(content: Content) -> some View {
            #if os(iOS) || os(tvOS) || os(macOS)
                if #available(iOS 14.0, tvOS 14.0, macOS 11.0, *) {
                    content
                        .onOpenURL { url in
                            txlemetry?.captureDeepLink(url: url)
                        }
                        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                            txlemetry?.captureDeepLink(userActivity: activity)
                        }
                } else {
                    content
                }
            #else
                content
            #endif
        }
    }

    /// SwiftUI deep link capture helpers.
    public extension View {
        /// Attach a Txlemetry deep link listener to this view.
        ///
        /// The listener forwards `.onOpenURL` and `.onContinueUserActivity` events to Txlemetry.
        ///
        /// - Parameter txlemetry: SDK instance to use for tracking. Defaults to `TxlemetrySDK.shared`.
        /// - Returns: A modified view that captures supported deep link events.
        func txlemetryDeepLinkListener(_ txlemetry: TxlemetrySDK? = nil) -> some View {
            let sdk = txlemetry ?? TxlemetrySDK.shared
            return modifier(TxlemetryDeepLinkListener(txlemetry: sdk))
        }
    }
#endif
