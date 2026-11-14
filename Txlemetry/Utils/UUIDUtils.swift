//
//  UUIDUtils.swift
//  Txlemetry
//
//  Created by Manoel Aranda Neto on 17.06.24.
//

// Inspired and adapted from https://github.com/nthState/UUIDV7/blob/main/Sources/UUIDV7/UUIDV7.swift
// but using SecRandomCopyBytes

import Foundation

extension UUID {
    static func v7() -> Self {
        TimeBasedEpochGenerator.shared.v7()
    }

    static func v7String() -> String {
        v7().txlemetryUuidString
    }

    var txlemetryUuidString: String {
        uuidString.lowercased()
    }
}
