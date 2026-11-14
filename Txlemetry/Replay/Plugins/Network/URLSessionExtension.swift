#if os(iOS)
    import Foundation

    /// Convenience URLSession APIs that capture session replay network telemetry for manual requests.
    public extension URLSession {
        private func getMonotonicTimeInMilliseconds() -> UInt64 {
            // Get the raw mach time
            let machTime = mach_absolute_time()

            // Get timebase info to convert to nanoseconds
            var timebaseInfo = mach_timebase_info_data_t()
            mach_timebase_info(&timebaseInfo)

            // Convert mach time to nanoseconds
            let nanoTime = machTime * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)

            // Convert nanoseconds to milliseconds
            return nanoTime / 1_000_000
        }

        private func executeRequest<Result>(request: URLRequest? = nil,
                                            action: () async throws -> (Result, URLResponse),
                                            txlemetry: TxlemetrySDK?) async throws -> (Result, URLResponse)
        {
            let timestamp = Date()
            let startMillis = getMonotonicTimeInMilliseconds()
            var endMillis: UInt64?
            let sessionId = txlemetry?.sessionManager.getSessionId(at: timestamp)
            do {
                let (result, response) = try await action()
                endMillis = getMonotonicTimeInMilliseconds()
                captureData(request: request,
                            response: response,
                            sessionId: sessionId,
                            timestamp: timestamp,
                            start: startMillis,
                            end: endMillis,
                            txlemetry: txlemetry)
                return (result, response)
            } catch {
                captureData(request: request,
                            response: nil,
                            sessionId: sessionId,
                            timestamp: timestamp,
                            start: startMillis,
                            end: endMillis,
                            txlemetry: txlemetry)
                throw error
            }
        }

        /// Performs `data(for:)` and captures network telemetry for session replay.
        ///
        /// - Parameters:
        ///   - request: Request to execute.
        ///   - txlemetry: SDK instance used to read the session ID and emit telemetry.
        ///     Pass an initialized instance; `nil` performs the request without capturing replay telemetry.
        /// - Returns: The data and URL response returned by `URLSession`.
        /// - Throws: Any error thrown by `URLSession.data(for:)`.
        func txlemetryData(for request: URLRequest, txlemetry: TxlemetrySDK? = nil) async throws -> (Data, URLResponse) {
            try await executeRequest(request: request, action: { try await data(for: request) }, txlemetry: txlemetry)
        }

        /// Performs `data(from:)` and captures network telemetry for session replay.
        ///
        /// - Parameters:
        ///   - url: URL to request.
        ///   - txlemetry: SDK instance used to read the session ID and emit telemetry.
        ///     Pass an initialized instance; `nil` performs the request without capturing replay telemetry.
        /// - Returns: The data and URL response returned by `URLSession`.
        /// - Throws: Any error thrown by `URLSession.data(from:)`.
        func txlemetryData(from url: URL, txlemetry: TxlemetrySDK? = nil) async throws -> (Data, URLResponse) {
            try await executeRequest(action: { try await data(from: url) }, txlemetry: txlemetry)
        }

        /// Performs `upload(for:fromFile:)` and captures network telemetry for session replay.
        ///
        /// - Parameters:
        ///   - request: Upload request to execute.
        ///   - fileURL: File URL to upload.
        ///   - txlemetry: SDK instance used to read the session ID and emit telemetry.
        ///     Pass an initialized instance; `nil` performs the request without capturing replay telemetry.
        /// - Returns: The data and URL response returned by `URLSession`.
        /// - Throws: Any error thrown by `URLSession.upload(for:fromFile:)`.
        func txlemetryUpload(
            for request: URLRequest,
            fromFile fileURL: URL,
            txlemetry: TxlemetrySDK? = nil
        ) async throws -> (Data, URLResponse) {
            try await executeRequest(request: request, action: { try await upload(for: request, fromFile: fileURL) }, txlemetry: txlemetry)
        }

        /// Performs `upload(for:from:)` and captures network telemetry for session replay.
        ///
        /// - Parameters:
        ///   - request: Upload request to execute.
        ///   - bodyData: Request body data to upload.
        ///   - txlemetry: SDK instance used to read the session ID and emit telemetry.
        ///     Pass an initialized instance; `nil` performs the request without capturing replay telemetry.
        /// - Returns: The data and URL response returned by `URLSession`.
        /// - Throws: Any error thrown by `URLSession.upload(for:from:)`.
        func txlemetryUpload(
            for request: URLRequest,
            from bodyData: Data,
            txlemetry: TxlemetrySDK? = nil
        ) async throws -> (Data, URLResponse) {
            try await executeRequest(request: request, action: { try await upload(for: request, from: bodyData) }, txlemetry: txlemetry)
        }

        /// Performs `data(for:delegate:)` and captures network telemetry for session replay.
        ///
        /// - Parameters:
        ///   - request: Request to execute.
        ///   - delegate: Task delegate for the request.
        ///   - txlemetry: SDK instance used to read the session ID and emit telemetry.
        ///     Pass an initialized instance; `nil` performs the request without capturing replay telemetry.
        /// - Returns: The data and URL response returned by `URLSession`.
        /// - Throws: Any error thrown by `URLSession.data(for:delegate:)`.
        @available(iOS 15.0, *)
        func txlemetryData(
            for request: URLRequest,
            delegate: (any URLSessionTaskDelegate)? = nil,
            txlemetry: TxlemetrySDK? = nil
        ) async throws -> (Data, URLResponse) {
            try await executeRequest(request: request, action: { try await data(for: request, delegate: delegate) }, txlemetry: txlemetry)
        }

        /// Performs `data(from:delegate:)` and captures network telemetry for session replay.
        ///
        /// - Parameters:
        ///   - url: URL to request.
        ///   - delegate: Task delegate for the request.
        ///   - txlemetry: SDK instance used to read the session ID and emit telemetry.
        ///     Pass an initialized instance; `nil` performs the request without capturing replay telemetry.
        /// - Returns: The data and URL response returned by `URLSession`.
        /// - Throws: Any error thrown by `URLSession.data(from:delegate:)`.
        @available(iOS 15.0, *)
        func txlemetryData(
            from url: URL,
            delegate: (any URLSessionTaskDelegate)? = nil,
            txlemetry: TxlemetrySDK? = nil
        ) async throws -> (Data, URLResponse) {
            try await executeRequest(action: { try await data(from: url, delegate: delegate) }, txlemetry: txlemetry)
        }

        /// Performs `upload(for:fromFile:delegate:)` and captures network telemetry for session replay.
        ///
        /// - Parameters:
        ///   - request: Upload request to execute.
        ///   - fileURL: File URL to upload.
        ///   - delegate: Task delegate for the request.
        ///   - txlemetry: SDK instance used to read the session ID and emit telemetry.
        ///     Pass an initialized instance; `nil` performs the request without capturing replay telemetry.
        /// - Returns: The data and URL response returned by `URLSession`.
        /// - Throws: Any error thrown by `URLSession.upload(for:fromFile:delegate:)`.
        @available(iOS 15.0, *)
        func txlemetryUpload(
            for request: URLRequest,
            fromFile fileURL: URL,
            delegate: (any URLSessionTaskDelegate)? = nil,
            txlemetry: TxlemetrySDK? = nil
        ) async throws -> (Data, URLResponse) {
            try await executeRequest(request: request, action: { try await upload(for: request, fromFile: fileURL, delegate: delegate) }, txlemetry: txlemetry)
        }

        /// Performs `upload(for:from:delegate:)` and captures network telemetry for session replay.
        ///
        /// - Parameters:
        ///   - request: Upload request to execute.
        ///   - bodyData: Request body data to upload.
        ///   - delegate: Task delegate for the request.
        ///   - txlemetry: SDK instance used to read the session ID and emit telemetry.
        ///     Pass an initialized instance; `nil` performs the request without capturing replay telemetry.
        /// - Returns: The data and URL response returned by `URLSession`.
        /// - Throws: Any error thrown by `URLSession.upload(for:from:delegate:)`.
        @available(iOS 15.0, *)
        func txlemetryUpload(
            for request: URLRequest,
            from bodyData: Data,
            delegate: (any URLSessionTaskDelegate)? = nil,
            txlemetry: TxlemetrySDK? = nil
        ) async throws -> (Data, URLResponse) {
            try await executeRequest(request: request, action: { try await upload(for: request, from: bodyData, delegate: delegate) }, txlemetry: txlemetry)
        }

        /// Performs `download(for:delegate:)` and captures network telemetry for session replay.
        ///
        /// - Parameters:
        ///   - request: Download request to execute.
        ///   - delegate: Task delegate for the request.
        ///   - txlemetry: SDK instance used to read the session ID and emit telemetry.
        ///     Pass an initialized instance; `nil` performs the request without capturing replay telemetry.
        /// - Returns: The downloaded file URL and URL response returned by `URLSession`.
        /// - Throws: Any error thrown by `URLSession.download(for:delegate:)`.
        @available(iOS 15.0, *)
        func txlemetryDownload(
            for request: URLRequest,
            delegate: (any URLSessionTaskDelegate)? = nil,
            txlemetry: TxlemetrySDK? = nil
        ) async throws -> (URL, URLResponse) {
            try await executeRequest(request: request, action: { try await download(for: request, delegate: delegate) }, txlemetry: txlemetry)
        }

        /// Performs `download(from:delegate:)` and captures network telemetry for session replay.
        ///
        /// - Parameters:
        ///   - url: URL to download.
        ///   - delegate: Task delegate for the request.
        ///   - txlemetry: SDK instance used to read the session ID and emit telemetry.
        ///     Pass an initialized instance; `nil` performs the request without capturing replay telemetry.
        /// - Returns: The downloaded file URL and URL response returned by `URLSession`.
        /// - Throws: Any error thrown by `URLSession.download(from:delegate:)`.
        @available(iOS 15.0, *)
        func txlemetryDownload(
            from url: URL,
            delegate: (any URLSessionTaskDelegate)? = nil,
            txlemetry: TxlemetrySDK? = nil
        ) async throws -> (URL, URLResponse) {
            try await executeRequest(action: { try await download(from: url, delegate: delegate) }, txlemetry: txlemetry)
        }

        /// Performs `download(resumeFrom:delegate:)` and captures network telemetry for session replay.
        ///
        /// - Parameters:
        ///   - resumeData: Resume data from a previously cancelled download.
        ///   - delegate: Task delegate for the request.
        ///   - txlemetry: SDK instance used to read the session ID and emit telemetry.
        ///     Pass an initialized instance; `nil` performs the request without capturing replay telemetry.
        /// - Returns: The downloaded file URL and URL response returned by `URLSession`.
        /// - Throws: Any error thrown by `URLSession.download(resumeFrom:delegate:)`.
        @available(iOS 15.0, *)
        func txlemetryDownload(
            resumeFrom resumeData: Data,
            delegate: (any URLSessionTaskDelegate)? = nil,
            txlemetry: TxlemetrySDK? = nil
        ) async throws -> (URL, URLResponse) {
            try await executeRequest(action: { try await download(resumeFrom: resumeData, delegate: delegate) }, txlemetry: txlemetry)
        }

        // MARK: Private methods

        private func captureData(
            request: URLRequest? = nil,
            response: URLResponse? = nil,
            sessionId: String?,
            timestamp: Date,
            start: UInt64,
            end: UInt64? = nil,
            txlemetry: TxlemetrySDK?
        ) {
            let instance = txlemetry ?? TxlemetrySDK.shared

            // we don't check config.sessionReplayConfig.captureNetworkTelemetry here since this extension
            // has to be called manually anyway
            guard let sessionId, instance.isSessionReplayActive() else {
                return
            }
            let currentEnd = end ?? getMonotonicTimeInMilliseconds()

            TxlemetryReplayIntegration.dispatchQueue.async {
                var snapshotsData: [Any] = []

                var requestsData: [String: Any] = ["duration": currentEnd - start,
                                                   "method": request?.httpMethod ?? "GET",
                                                   "name": request?.url?.absoluteString ?? (response?.url?.absoluteString ?? ""),
                                                   "initiatorType": "fetch",
                                                   "entryType": "resource",
                                                   "timestamp": timestamp.toMillis()]

                // the UI special case if the transferSize is 0 as coming from cache
                let transferSize = Int64(request?.httpBody?.count ?? 0) + (response?.expectedContentLength ?? 0)
                if transferSize > 0 {
                    requestsData["transferSize"] = transferSize
                }

                if let urlResponse = response as? HTTPURLResponse {
                    requestsData["responseStatus"] = urlResponse.statusCode
                }

                let payloadData: [String: Any] = ["requests": [requestsData]]
                let pluginData: [String: Any] = ["plugin": "rrweb/network@1", "payload": payloadData]

                let recordingData: [String: Any] = ["type": 6, "data": pluginData, "timestamp": timestamp.toMillis()]
                snapshotsData.append(recordingData)

                instance.capture(
                    "$snapshot",
                    properties: [
                        "$snapshot_source": "mobile",
                        "$snapshot_data": snapshotsData,
                        "$session_id": sessionId,
                    ],
                    timestamp: timestamp
                )
            }
        }
    }
#endif
