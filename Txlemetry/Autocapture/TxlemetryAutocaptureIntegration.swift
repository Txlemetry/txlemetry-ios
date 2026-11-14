//
//  TxlemetryAutocaptureIntegration.swift
//  Txlemetry
//
//  Created by Yiannis Josephides on 22/10/2024.
//

#if os(iOS) || targetEnvironment(macCatalyst)
    import UIKit

    class TxlemetryAutocaptureIntegration: AutocaptureEventProcessing, TxlemetryIntegration {
        var requiresSwizzling: Bool { true }

        private static let integrationInstallState = TxlemetryIntegrationInstallState()

        private weak var txlemetry: TxlemetrySDK?
        private var debounceTimers: [Int: Timer] = [:]
        private lazy var swiftUITaps = SwiftUITapAutocapture(processor: self)

        var captureSwiftUIElementInteractions: Bool {
            txlemetry?.config.captureSwiftUIElementInteractions == true
        }

        var captureElementText: Bool { txlemetry?.config.captureAutocaptureElementText ?? true }

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

        /**
         Activates the autocapture integration by routing events from TxlemetryAutocaptureEventTracker to this instance.
         */
        func start() {
            TxlemetryAutocaptureEventTracker.eventProcessor = self
            swiftUITaps.setEnabled(captureSwiftUIElementInteractions)
            TxlemetryLabelTaggerView.refreshAll()
        }

        /**
         Disables the autocapture integration by clearing the TxlemetryAutocaptureEventTracker routing
         */
        func stop() {
            swiftUITaps.setEnabled(false)
            if TxlemetryAutocaptureEventTracker.eventProcessor != nil {
                TxlemetryAutocaptureEventTracker.eventProcessor = nil
                TxlemetryLabelTaggerView.refreshAll()
                debounceTimers.values.forEach { $0.invalidate() }
                debounceTimers.removeAll()
            }
        }

        /**
         Processes an autocapture event, with optional debounce logic for controls that emit frequent events.

         - Parameters:
            - source: The source of the event (e.g., gesture recognizer, action method, or notification).
            - event: The autocapture event data, containing properties, screen name, and other metadata.

         If the event has a `debounceInterval` greater than 0, the event is debounced.
         This is useful for UIControls like `UISlider` that emit frequent value changes, ensuring only the last value is captured.
         The debounce interval is defined per UIControl by the `ph_autocaptureDebounceInterval` property of `AutoCapturable`
         */
        func process(source: TxlemetryAutocaptureEventTracker.EventSource, event: TxlemetryAutocaptureEventTracker.EventData) {
            guard txlemetry?.isAutocaptureActive() == true else {
                return
            }

            switch source {
            case .swiftUITap:
                guard captureSwiftUIElementInteractions else { return }
            default:
                guard txlemetry?.config.captureElementInteractions == true else { return }
            }

            swiftUITaps.cancel()
            let eventHash = event.viewHierarchy.map(\.targetClass).hashValue
            // debounce frequent UIControl events (e.g., UISlider) to reduce event noise
            if event.debounceInterval > 0 {
                debounceTimers[eventHash]?.invalidate() // Keep cancelling existing
                debounceTimers[eventHash] = Timer.scheduledTimer(withTimeInterval: event.debounceInterval, repeats: false) { [weak self] _ in
                    self?.handleEventProcessing(source: source, event: event)
                    self?.debounceTimers.removeValue(forKey: eventHash) // Clean up once fired
                }
            } else {
                handleEventProcessing(source: source, event: event)
            }
        }

        /**
         Handles the processing of autocapture events by extracting event details, building properties, and sending them to Txlemetry.

         - Parameters:
            - source: The source of the event (action method, gesture, or notification). Values are already mapped to `$event_type` earlier in the chain
            - event: The event data including view hierarchy, screen name, and other metadata.

         This function extracts event details such as the event type, view hierarchy, and touch coordinates.
         It creates a structured payload with relevant properties (e.g., tag_name, elements, element_chain) and sends it to the
         associated Txlemetry instance for further processing.
         */
        private func handleEventProcessing(source: TxlemetryAutocaptureEventTracker.EventSource, event: TxlemetryAutocaptureEventTracker.EventData) {
            guard let txlemetry else {
                return
            }

            let eventType: String = switch source {
            case .swiftUITap: EventType.kTouch
            case let .actionMethod(description): description
            case let .gestureRecognizer(description): description
            case let .notification(name): name
            }

            var properties: [String: Any] = [:]

            if let screenName = event.screenName {
                properties["$screen_name"] = screenName
            }

            let elementsChain = event.getElementChain(captureElementText: captureElementText)

            if let coordinates = event.touchCoordinates {
                properties["$touch_x"] = coordinates.x
                properties["$touch_y"] = coordinates.y
            }

            txlemetry.autocapture(
                eventType: eventType,
                elementsChain: elementsChain,
                properties: properties
            )
        }
    }

    #if TESTING
        extension TxlemetryAutocaptureIntegration {
            static func clearInstalls() {
                integrationInstallState.clear()
            }
        }
    #endif
#endif
