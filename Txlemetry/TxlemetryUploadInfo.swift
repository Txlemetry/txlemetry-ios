//
//  TxlemetryUploadInfo.swift
//  Txlemetry
//
//  Created by Manoel Aranda Neto on 13.10.23.
//

import Foundation

struct TxlemetryUploadInfo {
    let statusCode: Int?
    let error: Error?
    let retryAfter: TimeInterval?

    init(statusCode: Int?, error: Error?, retryAfter: TimeInterval? = nil) {
        self.statusCode = statusCode
        self.error = error
        self.retryAfter = retryAfter
    }
}
