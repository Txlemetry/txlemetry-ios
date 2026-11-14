//
//  TxlemetrySessionReplayConsoleLogsPlugin.swift
//  Txlemetry
//
//  Created by Ioannis Josephides on 09/05/2025.
//

#if os(iOS)
    import Foundation

    final class TxlemetrySessionReplayConsoleLogsPlugin: TxlemetrySessionReplayPlugin {
        private weak var txlemetry: TxlemetrySDK?
        private var isActive = false

        required init() { /**/ }

        func start(txlemetry: TxlemetrySDK) {
            self.txlemetry = txlemetry
            isActive = true
            TxlemetryConsoleLogInterceptor.shared.startCapturing(config: txlemetry.config) { [weak self] output in
                self?.handleConsoleLog(output)
            }
            hedgeLog("[Session Replay] Console logs plugin started")
        }

        func stop() {
            txlemetry = nil
            isActive = false
            TxlemetryConsoleLogInterceptor.shared.stopCapturing()
            hedgeLog("[Session Replay] Console logs plugin stopped")
        }

        func resume() {
            guard !isActive, let txlemetry else { return }
            isActive = true
            TxlemetryConsoleLogInterceptor.shared.startCapturing(config: txlemetry.config) { [weak self] output in
                self?.handleConsoleLog(output)
            }
            hedgeLog("[Session Replay] Console logs plugin resumed")
        }

        func pause() {
            guard isActive else { return }
            isActive = false
            TxlemetryConsoleLogInterceptor.shared.stopCapturing()
            hedgeLog("[Session Replay] Console logs plugin paused")
        }

        // see: https://github.com/Txlemetry/txlemetry-js/blob/c81ee34096a780b13e97a862197d4a6fdedb749a/packages/browser/src/extensions/replay/external/lazy-loaded-session-recorder.ts#L462-L466
        static func isEnabledRemotely(remoteConfig: [String: Any]?) -> Bool {
            guard let sessionRecording = remoteConfig?["sessionRecording"] as? [String: Any] else {
                return false
            }
            return sessionRecording["consoleLogRecordingEnabled"] as? Bool ?? false
        }

        private func handleConsoleLog(_ output: TxlemetryConsoleLogInterceptor.ConsoleOutput) {
            guard
                isActive,
                let txlemetry,
                txlemetry.isSessionReplayActive(),
                let sessionId = txlemetry.sessionManager.getSessionId(at: output.timestamp)
            else {
                return
            }

            // `TxlemetryLogLevel`` needs to be an Int enum for objc interop
            // So we need to convert this to a String before sending upstream
            let level = switch output.level {
            case .error: "error"
            case .info: "info"
            case .warn: "warn"
            }

            var snapshotsData: [Any] = []
            let payloadData: [String: Any] = ["level": level, "payload": output.text]
            let pluginData: [String: Any] = ["plugin": "rrweb/console@1", "payload": payloadData]

            snapshotsData.append([
                "type": 6,
                "data": pluginData,
                "timestamp": output.timestamp.toMillis(),
            ])

            txlemetry.capture(
                "$snapshot",
                properties: [
                    "$snapshot_source": "mobile",
                    "$snapshot_data": snapshotsData,
                    "$session_id": sessionId,
                ],
                timestamp: output.timestamp
            )
        }
    }
#endif
