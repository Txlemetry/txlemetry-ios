# Txlemetry Apple SDK

Maintained Swift, Objective-C bridge and vendored native source for iOS, macOS, tvOS, watchOS and visionOS.
The Swift package, library, CocoaPod and public API use the Txlemetry name.
Version `4.0.0` is a migration candidate and is not published yet.

```swift
import Txlemetry

let config = TxlemetryConfig(projectToken: projectToken, host: "https://app.txlemetry.com")
TxlemetrySDK.shared.setup(config)
```

During local validation, add this directory as a local Swift package or use a local CocoaPods path for `Txlemetry.podspec`.
Run the SDK build and tests on macOS with Xcode using `make buildSdk`, `make test` and `make lint`.
Validate supported platforms individually; replay is platform dependent.
The Swift package and the CocoaPods source are published from https://github.com/hectorvss/txlemetry-ios (tag `4.0.0`).
The React Native and Flutter SwiftPM integrations use that repository by default; set `TXLEMETRY_SWIFT_PACKAGE_URL` to build against a local or mirrored copy.

Existing `posthog.*` storage keys, push payload/audience and tracing headers remain compatible.
The retained keys preserve identity, opt-out state and offline queues when updating an installed app.
Validate that continuity explicitly before release.
Third-party libwebp and crash-reporter names and licenses remain intact.
See `upstream-provenance.json`, `NOTICE`, `LICENSE` and the notices under `vendor/`.
