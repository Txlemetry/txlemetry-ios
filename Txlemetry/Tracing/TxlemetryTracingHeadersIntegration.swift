#if os(iOS)
    import Foundation

    private enum TxlemetryTracingHeaders {
        static let distinctId = "X-POSTHOG-DISTINCT-ID"
        static let sessionId = "X-POSTHOG-SESSION-ID"

        static func addingHeaders(
            to request: URLRequest,
            hostnames: Set<String>,
            distinctId: String,
            sessionId: String?
        ) -> URLRequest {
            guard shouldAddHeaders(to: request.url, hostnames: hostnames) else {
                return request
            }

            var request = request

            if let sessionId, !sessionId.isEmpty {
                request.setValue(sessionId, forHTTPHeaderField: Self.sessionId)
            }

            if !distinctId.isEmpty {
                request.setValue(distinctId, forHTTPHeaderField: Self.distinctId)
            }

            return request
        }

        static func normalizeHostnames(_ hostnames: [String]) -> Set<String> {
            Set(
                hostnames
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        }

        private static func shouldAddHeaders(to url: URL?, hostnames: Set<String>) -> Bool {
            guard let requestHost = url?.host?.lowercased(), !hostnames.isEmpty else {
                return false
            }

            return hostnames.contains(requestHost)
        }
    }

    final class TxlemetryTracingHeadersIntegration: TxlemetryIntegration {
        var requiresSwizzling: Bool { true }

        private static let integrationInstallState = TxlemetryIntegrationInstallState()

        private weak var txlemetry: TxlemetrySDK?
        private var registrationId: UUID?
        private var normalizedHostnames = Set<String>()

        func install(_ txlemetry: TxlemetrySDK) -> TxlemetryIntegrationInstallResult {
            installIfNeeded(using: Self.integrationInstallState) {
                self.txlemetry = txlemetry
                normalizedHostnames = TxlemetryTracingHeaders.normalizeHostnames(txlemetry.config.tracingHeaders ?? [])
                start()
            }
        }

        func uninstall(_ txlemetry: TxlemetrySDK) {
            uninstallIfNeeded(from: txlemetry, installedTxlemetry: self.txlemetry, state: Self.integrationInstallState) {
                stop()
                self.txlemetry = nil
                normalizedHostnames = []
            }
        }

        func start() {
            do {
                try startInstrumentation()
            } catch {
                hedgeLog("Tracing headers integration failed to start: \(error)")
            }
        }

        func stop() {
            guard let registrationId else {
                return
            }

            URLSessionInstrumentation.shared.unregister(registrationId)
            self.registrationId = nil
        }

        private func startInstrumentation() throws {
            guard registrationId == nil else {
                return
            }

            registrationId = try URLSessionInstrumentation.shared.register(requestModifier: { [weak self] request in
                self?.addTracingHeaders(to: request) ?? request
            })
        }

        private func addTracingHeaders(to request: URLRequest) -> URLRequest {
            guard let txlemetry else {
                return request
            }

            return TxlemetryTracingHeaders.addingHeaders(
                to: request,
                hostnames: normalizedHostnames,
                distinctId: txlemetry.getDistinctId(),
                sessionId: txlemetry.sessionManager.getSessionId(readOnly: true)
            )
        }
    }

    #if TESTING
        extension TxlemetryTracingHeadersIntegration {
            static func clearInstalls() {
                integrationInstallState.clear()
            }
        }
    #endif
#endif
