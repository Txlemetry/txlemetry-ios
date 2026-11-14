.PHONY: testSurveyUI build buildSdk buildExamples format swiftLint swiftFormat swiftLintCheck swiftFormatCheck installSwiftLint installSwiftFormat test testUploadSymbols recordEventShapeSnapshots testDowngradeCompatibility testOniOSSimulator testOnMacSimulator maskSnapshots recordMaskSnapshots checkMaskSnapshotRuntime lint bootstrap releaseCocoaPods api apiCheck apiUpdate buildIOS

build: buildSdk buildExamples

buildIOS:
	set -o pipefail && xcrun xcodebuild clean build -scheme Txlemetry -destination generic/platform=ios | xcpretty #ios

buildSdk:
	set -o pipefail && xcrun xcodebuild clean build -scheme Txlemetry -destination generic/platform=ios | xcpretty #ios
	set -o pipefail && xcrun swift build --arch arm64 #macOS
	set -o pipefail && xcrun xcodebuild clean build -scheme Txlemetry -destination generic/platform=macos | xcpretty #macOS
	set -o pipefail && xcrun xcodebuild clean build -scheme Txlemetry -destination 'platform=macOS,variant=Mac Catalyst' | xcpretty #Mac Catalyst
	set -o pipefail && xcrun xcodebuild clean build -scheme Txlemetry -destination generic/platform=tvos | xcpretty #tvOS
	set -o pipefail && xcrun xcodebuild clean build -scheme Txlemetry -destination generic/platform=watchos | xcpretty #watchOS
	set -o pipefail && xcrun xcodebuild clean build -scheme Txlemetry -destination generic/platform=xros | xcpretty #visionOS

buildExamples: \
	buildExamplesPlatforms \
	buildExampleXCFramework \
	buildExamplePods \

buildExamplePods: \
	buildExamplePodsStaticLib \
	buildExamplePodsStaticFramework \
	buildExamplePodsDynamicFramework \

buildExamplesPlatforms:
	set -o pipefail && xcrun xcodebuild clean build -scheme TxlemetryExample -destination generic/platform=ios | xcpretty #ios
	set -o pipefail && xcrun xcodebuild clean build -scheme TxlemetryExampleVisionOS -destination generic/platform=xros | xcpretty #visionOS
	set -o pipefail && xcrun xcodebuild clean build -scheme TxlemetryObjCExample -destination generic/platform=ios | xcpretty #ObjC
	set -o pipefail && xcrun xcodebuild clean build -scheme TxlemetryExampleMacOS -destination generic/platform=macos | xcpretty #macOS
	set -o pipefail && xcrun xcodebuild clean build -scheme 'TxlemetryExampleWatchOS Watch App' -destination generic/platform=watchos | xcpretty #watchOS
	set -o pipefail && xcrun xcodebuild clean build -scheme TxlemetryExampleTvOS -destination generic/platform=tvos | xcpretty #watchOS
	set -o pipefail && xcrun xcodebuild clean build -scheme TxlemetryExampleWithSPM -destination generic/platform=ios | xcpretty #SPM
	set -o pipefail && xcrun xcodebuild clean build -scheme TxlemetryExampleWithSPM -destination 'platform=macOS,variant=Mac Catalyst' | xcpretty #Mac Catalyst SPM

buildExamplePodsDynamicFramework:
	cd TxlemetryExampleWithPods && \
	USE_FRAMEWORKS=dynamic pod install && cd .. && \
	set -o pipefail && xcrun xcodebuild clean build \
		-workspace TxlemetryExampleWithPods/TxlemetryExampleWithPods.xcworkspace \
		-scheme TxlemetryExampleWithPods \
		-destination generic/platform=ios | xcpretty

buildExamplePodsStaticFramework:
	cd TxlemetryExampleWithPods && \
	USE_FRAMEWORKS=static pod install && cd .. && \
	set -o pipefail && xcrun xcodebuild clean build \
		-workspace TxlemetryExampleWithPods/TxlemetryExampleWithPods.xcworkspace \
		-scheme TxlemetryExampleWithPods \
		-destination generic/platform=ios | xcpretty

buildExamplePodsStaticLib:
	cd TxlemetryExampleWithPods && \
	pod install && cd .. && \
	set -o pipefail && xcrun xcodebuild clean archive \
		-workspace TxlemetryExampleWithPods/TxlemetryExampleWithPods.xcworkspace \
		-scheme TxlemetryExampleWithPods \
		-destination generic/platform=ios | xcpretty

buildExampleXCFramework:
	./TxlemetryExampleExternalSDK/build_xcframework.sh
	set -o pipefail && xcrun xcodebuild clean build \
		-project ./TxlemetryExampleExternalSDK/SDKClient/TxlemetryExampleExternalSDKClient.xcodeproj \
		-scheme ExternalSDKClient \
		-destination "generic/platform=iOS Simulator" | xcpretty

format: swiftLint swiftFormat

installSwiftLint:
	@if ! command -v swiftlint >/dev/null 2>&1; then \
		brew install swiftlint; \
	fi

installSwiftFormat:
	@if ! command -v swiftformat >/dev/null 2>&1; then \
		brew install swiftformat; \
	fi

swiftLint: installSwiftLint
	swiftlint --fix

swiftFormat: installSwiftFormat
	swiftformat . --swiftversion 5.3

swiftLintCheck: installSwiftLint
	swiftlint

swiftFormatCheck: installSwiftFormat
	swiftformat . --lint --swiftversion 5.3

# use -only-testing:TxlemetryTests/TxlemetryQueueTest to run only a specific test
# -retry-tests-on-failure -test-iterations 3: a few tests assert real-time behaviour (autocapture
# debounce/flush windows) that can't be made deterministic; on slow, load-variable CI runners those
# windows occasionally slip. Rerun a *failed* test up to 3 times so a transient miss doesn't fail the
# job — a genuinely broken test fails all 3 and stays red. Retries can *mask* flakiness, so we tee the
# raw log to xcodebuild-ios.log; CI reads it back to surface tests that only passed after a retry (the
# macOS `test` job runs without retries, so a genuine flake still hard-fails there).
testOniOSSimulator:
	@device="$$(xcrun simctl list devices available | grep -E '^[[:space:]]*iPhone' | head -1 | sed -E 's/^[[:space:]]*//; s/ \(.*//')"; \
	[ -n "$$device" ] || { echo "No available iPhone simulator found; install one via Xcode or 'xcrun simctl create'."; exit 1; }; \
	echo "Testing on simulator: $$device"; \
	set -o pipefail; \
	xcrun xcodebuild test -scheme Txlemetry -destination "platform=iOS Simulator,name=$$device" -retry-tests-on-failure -test-iterations 3 | tee xcodebuild-ios.log | xcpretty; \
	status=$$?; \
	scripts/check-ios-test-result.sh "$$status" xcodebuild-ios.log

# Mounted interaction tests use a small test host and the SDK's real survey views.
# Override SURVEY_UI_DESTINATION to select an installed simulator explicitly.
SURVEY_UI_DESTINATION ?= platform=iOS Simulator,name=$$(xcrun simctl list devices available | grep -E '^[[:space:]]*iPhone' | head -1 | sed -E 's/^[[:space:]]*//; s/ \(.*//')
testSurveyUI:
	set -o pipefail && xcrun xcodebuild test -project Txlemetry.xcodeproj -scheme TxlemetrySurveyUI \
	  -destination "$(SURVEY_UI_DESTINATION)" -parallel-testing-enabled NO \
	  $(SURVEY_UI_XCODEBUILD_ARGS) | tee survey-ui-tests.log | xcpretty
	@grep -qE "Test Case .*SurveyAutoSubmitUITests.* passed" survey-ui-tests.log || { \
	  echo "error: no survey UI tests executed."; exit 1; }

.PHONY: testPresentationMasks

# UIKit presentation needs an app host. Keep the rest of the suite hostless: it relies on
# xctest's bundle identity and app-group entitlements. Override the destination for a specific OS.
testPresentationMasks:
	@device="$$(xcrun simctl list devices available | grep -E '^[[:space:]]*iPhone' | head -1 | sed -E 's/^[[:space:]]*//; s/ \(.*//')"; \
	[ -n "$$device" ] || { echo "No available iPhone simulator found."; exit 1; }; \
	set -o pipefail; \
	xcrun xcodebuild test -project Txlemetry.xcodeproj -scheme Txlemetry \
	  -destination "$${PRESENTATION_TEST_DESTINATION:-platform=iOS Simulator,name=$$device}" \
	  -parallel-testing-enabled NO \
	  TXLEMETRY_PRESENTATION_TEST_HOST='$$(BUILT_PRODUCTS_DIR)/TxlemetryExample.app/TxlemetryExample' \
	  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$$(inherited) TEST_PRESENTATION_MASKS' \
	  -only-testing:TxlemetryTests/TxlemetryMaskPresentationTest \
	  -only-testing:TxlemetryTests/TxlemetryMaskPresentationPrivacyTest \
	  2>&1 | tee presentation-masks.log | xcpretty
	@grep -q 'Suite "Replay masking behind a cover" passed' presentation-masks.log
	@grep -q 'Suite "Replay presentation privacy" passed' presentation-masks.log

testOnMacSimulator:
	set -o pipefail && xcrun xcodebuild test -scheme Txlemetry -destination 'platform=macOS' | xcpretty

# Golden-image masking snapshots (TxlemetryMaskSnapshotTest). The test forces the render
# environment (see forceDeviceIndependentEnvironment), so any iPhone on the pinned OS
# produces identical output — the OS version is the only pin. If the runner's runtime
# rotates or a masking change is intentional: make recordMaskSnapshots, review, commit.
MASK_SNAPSHOT_OS ?= 26.2
# Pinned alongside the OS: latest-stable can bump the compiler/SDK while the sim OS stays
# fixed, and the goldens are byte-sensitive. Bump this with MASK_SNAPSHOT_OS and re-record.
MASK_SNAPSHOT_XCODE ?= 26.3
# First available iPhone on the pinned runtime, by UDID (any iPhone renders identically).
MASK_SNAPSHOT_UDID = $$(xcrun simctl list devices available | awk '/-- iOS $(MASK_SNAPSHOT_OS) --/{f=1;next} /^--/{f=0} f && /iPhone/' | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')

checkMaskSnapshotRuntime:
	@xcrun simctl list runtimes | grep -q "iOS $(MASK_SNAPSHOT_OS)" || { \
	  echo "error: pinned iOS $(MASK_SNAPSHOT_OS) simulator runtime is not installed (CI runner image likely rotated)."; \
	  echo "Fix: bump MASK_SNAPSHOT_OS in the Makefile, run 'make recordMaskSnapshots', then review + commit the refreshed goldens."; \
	  exit 1; }
	@[ -n "$(MASK_SNAPSHOT_UDID)" ] || { \
	  echo "error: no available iPhone simulator on the iOS $(MASK_SNAPSHOT_OS) runtime; create one via Xcode or 'xcrun simctl create'."; \
	  exit 1; }
	@xcodebuild -version | grep -q "Xcode $(MASK_SNAPSHOT_XCODE)" || { \
	  echo "error: pinned Xcode $(MASK_SNAPSHOT_XCODE) is not selected (found: $$(xcodebuild -version | head -1)); goldens are byte-sensitive to the compiler/SDK."; \
	  echo "Fix: select Xcode $(MASK_SNAPSHOT_XCODE), or bump MASK_SNAPSHOT_XCODE alongside MASK_SNAPSHOT_OS and re-record."; \
	  exit 1; }

# xcpretty collapses a Swift Testing run to a summary that reads green even at 0 tests, so a
# broken compile gate or -only-testing selector could pass silently. Tee the raw log and
# assert verifyGoldens() actually ran.
maskSnapshots: checkMaskSnapshotRuntime
	set -o pipefail && xcrun xcodebuild test -scheme Txlemetry \
	  -destination "platform=iOS Simulator,id=$(MASK_SNAPSHOT_UDID)" \
	  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$$(inherited) TEST_MASK_SNAPSHOTS' \
	  "-only-testing:TxlemetryTests/TxlemetryMaskSnapshotTest/verifyGoldens()" 2>&1 | tee mask-snapshots.log | xcpretty
	@grep -qE 'Test "[^"]+" passed' mask-snapshots.log || { \
	  echo "error: no masking snapshot test executed (0-test run); the TEST_MASK_SNAPSHOTS gate or -only-testing selector likely broke."; \
	  exit 1; }

recordMaskSnapshots: checkMaskSnapshotRuntime
	set -o pipefail && xcrun xcodebuild test -scheme Txlemetry \
	  -destination "platform=iOS Simulator,id=$(MASK_SNAPSHOT_UDID)" \
	  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$$(inherited) TEST_MASK_SNAPSHOTS RECORD_MASK_SNAPSHOTS' \
	  "-only-testing:TxlemetryTests/TxlemetryMaskSnapshotTest/recordGoldens()" | xcpretty

# Usage: make test filter=<pattern>
# Examples:
#   make test                              						# Run all tests
#   make test filter=TxlemetryPropertiesSerializationTests        # Run specific test suite, class or method
testUploadSymbols:
	build-tools/upload-symbols.test.sh

test: testUploadSymbols
	set -o pipefail && swift test --no-parallel -Xswiftc -DTESTING $(if $(filter),--filter $(filter))

recordEventShapeSnapshots:
	UPDATE_EVENT_SHAPE_SNAPSHOTS=1 $(MAKE) test filter=TxlemetryEventSnapshotTests

testDowngradeCompatibility:
	DOWNGRADE_REF="$${DOWNGRADE_REF:-3.48.0}" ./scripts/test-downgrade-compatibility.sh


lint: swiftFormatCheck swiftLintCheck

# periphery scan --setup
# TODO: add periphery to the CI/commit prehooks
api:
	periphery scan

apiCheck:
	scripts/check-public-api.sh

apiUpdate:
	scripts/check-public-api.sh --update

# requires gem and brew
# xcpretty needs 'export LANG=en_US.UTF-8'
bootstrap:
	gem install cocoapods
	gem install xcpretty
	brew install swiftlint
	brew install swiftformat
	brew install peripheryapp/periphery/periphery

# download SDKs and runtimes
# create Apple Vision Pro simulator if missing
# release pod
releaseCocoaPods:
	set -o pipefail && xcrun xcodebuild -downloadAllPlatforms 
	@if ! xcrun simctl list devices | grep -q "Apple Vision Pro"; then \
		LATEST_RUNTIME=$$(xcrun simctl list runtimes | grep "com.apple.CoreSimulator.SimRuntime.xrOS" | sort -r | head -n 1 | awk '{print $$NF}') && \
		xcrun simctl create "Apple Vision Pro" "Apple Vision Pro" "$$LATEST_RUNTIME"; \
	fi
	pod trunk push Txlemetry.podspec --allow-warnings