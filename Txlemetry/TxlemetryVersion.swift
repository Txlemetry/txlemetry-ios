//
//  TxlemetryVersion.swift
//  Txlemetry
//
//  Created by Manoel Aranda Neto on 13.10.23.
//

import Foundation

// if you change this, make sure to also change it in the podspec and check if the script scripts/bump-version.sh still works
/// Current SDK version string.
///
/// - Warning: This is intended for SDK internals and integrations. Application code should not mutate it.
public var txlemetryVersion = "4.0.0"

/// Default SDK name reported by the native iOS SDK.
public let txlemetryiOSSdkName = "txlemetry-ios"

/// SDK name included in captured event context.
///
/// - Warning: This is intended for SDK internals and wrapper SDKs. Application code should not mutate it.
public var txlemetrySdkName = txlemetryiOSSdkName
