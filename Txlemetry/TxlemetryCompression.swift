import Foundation

/// How the SDK compresses request bodies before sending them to the Txlemetry API.
@objc(TxlemetryCompression) public enum TxlemetryCompression: Int {
    /// Gzip request bodies. If gzipping fails on device, the body is sent uncompressed.
    case gzip
    /// Send request bodies uncompressed, with no `Content-Encoding` header.
    case none
}
