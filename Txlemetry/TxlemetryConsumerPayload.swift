//
//  TxlemetryConsumerPayload.swift
//  Txlemetry
//
//  Created by Manoel Aranda Neto on 13.10.23.
//

import Foundation

/// Payload handed from `TxlemetryQueue.take` to the send pipeline. Generic over
/// the record type so the same queue infrastructure can ship `TxlemetryEvent`
/// (events / replay snapshots) and `TxlemetryLogRecord` (logs).
struct TxlemetryConsumerPayload<Record> {
    let records: [Record]
    let completion: (Bool) -> Void
}
