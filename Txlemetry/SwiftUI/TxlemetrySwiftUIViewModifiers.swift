//
//  TxlemetrySwiftUIViewModifiers.swift
//  Txlemetry
//
//  Created by Manoel Aranda Neto on 05.09.24.
//

#if canImport(SwiftUI)
    import Foundation
    import SwiftUI

    /// SwiftUI analytics capture helpers.
    public extension View {
        /// Marks a SwiftUI view to be tracked as a `$screen` event when `onAppear` runs.
        ///
        /// - Parameters:
        ///   - screenName: The screen name. Defaults to the view's type name.
        ///   - properties: Additional properties to attach to the `$screen` event.
        ///   - txlemetry: SDK instance used to send the event. Defaults to `TxlemetrySDK.shared`.
        /// - Returns: A modified view that captures a screen view when it appears.
        func txlemetryScreenView(_ screenName: String? = nil,
                               _ properties: [String: Any]? = nil,
                               txlemetry: TxlemetrySDK? = nil) -> some View
        {
            let viewEventName = screenName ?? "\(type(of: self))"
            return modifier(TxlemetrySwiftUIViewModifier(viewEventName: viewEventName,
                                                       screenEvent: true,
                                                       properties: properties,
                                                       txlemetry: txlemetry))
        }

        /// Captures a custom event when this SwiftUI view appears.
        ///
        /// - Parameters:
        ///   - event: Event name to capture.
        ///   - properties: Additional event properties.
        ///   - txlemetry: SDK instance used to send the event. Defaults to `TxlemetrySDK.shared`.
        /// - Returns: A modified view that captures the event when it appears.
        func txlemetryViewSeen(_ event: String,
                             _ properties: [String: Any]? = nil,
                             txlemetry: TxlemetrySDK? = nil) -> some View
        {
            modifier(TxlemetrySwiftUIViewModifier(viewEventName: event,
                                                screenEvent: false,
                                                properties: properties,
                                                txlemetry: txlemetry))
        }
    }

    private struct TxlemetrySwiftUIViewModifier: ViewModifier {
        let viewEventName: String

        let screenEvent: Bool

        let properties: [String: Any]?

        let txlemetry: TxlemetrySDK?

        func body(content: Content) -> some View {
            content.onAppear {
                if screenEvent {
                    instance.screen(viewEventName, properties: properties)
                } else {
                    instance.capture(viewEventName, properties: properties)
                }
            }
        }

        private var instance: TxlemetrySDK {
            txlemetry ?? TxlemetrySDK.shared
        }
    }

#endif
