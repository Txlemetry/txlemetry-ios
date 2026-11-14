Pod::Spec.new do |s|
  s.name             = "Txlemetry"
  s.version          = "4.0.0"
  s.summary          = "The hassle-free way to add Txlemetry to your iOS app."

  s.description      = <<-DESC
                       Txlemetry for iOS provides a single API that lets you
                       integrate with over 100s of tools.
                       DESC

  s.homepage         = "http://txlemetry.com/"
  s.license          =  { :type => 'MIT' }
  s.author           = { "Txlemetry" => "support@txlemetry.com" }
  s.source           = { :git => "https://github.com/hectorvss/txlemetry-ios.git", :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.tvos.deployment_target = '13.0'
  s.osx.deployment_target = "10.15"
  s.watchos.deployment_target = "6.0"
  s.visionos.deployment_target = "1.0"
  s.swift_versions = "5.3"

  s.frameworks = 'Foundation'

  # Vendored PLCrashReporter source (not available on watchOS/visionOS)
  s.libraries = 'c++'
  s.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) PLCR_PRIVATE PLCF_RELEASE_BUILD PLCRASHREPORTER_PREFIX=PH SWIFT_PACKAGE',
    # Static-library source pods cannot resolve the underlying Objective-C module
    # while verifying the emitted Swift interface. Xcode 16.2 still schedules
    # verification when the build setting is NO, so pass the compiler flag as well.
    'SWIFT_VERIFY_EMITTED_MODULE_INTERFACE' => 'NO',
    'OTHER_SWIFT_FLAGS' => '$(inherited) -no-verify-emitted-module-interface',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/vendor/PHPLCrashReporter/Source"',
    'SWIFT_INCLUDE_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/Txlemetry/PrivateModules/phlibwebp" "${PODS_TARGET_SRCROOT}/Txlemetry/PrivateModules/PHPLCrashReporter" "${PODS_TARGET_SRCROOT}/Txlemetry/PrivateModules/TxlemetryObjCExceptionSupport"'
  }

  s.source_files = [
    'Txlemetry/**/*.{swift,h,hpp,m,mm,c,cpp}',
    'vendor/libwebp/**/*.{h,c}',
    'vendor/PHPLCrashReporter/Source/**/*.{h,hpp,m,mm,c,cpp,S}'
  ]

  # Only Txlemetry's umbrella header should be public; vendored implementation headers stay private.
  s.public_header_files = 'Txlemetry/Txlemetry.h'
  s.private_header_files = [
    'Txlemetry/ObjCExceptionSupport/PHObjCExceptionCatcher.h',
    'Txlemetry/ObjCExceptionSupport/PHURLSessionTaskSafeAccess.h',
    'vendor/libwebp/**/*.h',
    'vendor/PHPLCrashReporter/Source/**/*.{h,hpp}'
  ]

  # Crash reporting is not supported on watchOS/visionOS
  s.watchos.exclude_files = [
    'vendor/PHPLCrashReporter/Source/**/*',
    'vendor/PHPLCrashReporter/Dependencies/**/*'
  ]
  s.visionos.exclude_files = [
    'vendor/PHPLCrashReporter/Source/**/*',
    'vendor/PHPLCrashReporter/Dependencies/**/*'
  ]
  s.exclude_files = [
    'vendor/PHPLCrashReporter/Source/PLCrashReport.proto'
  ]
  s.resource_bundles = {
    'Txlemetry' => 'Txlemetry/Resources/PrivacyInfo.xcprivacy',
    'PHPLCrashReporter' => 'vendor/PHPLCrashReporter/Resources/PrivacyInfo.xcprivacy'
  }
  
  # Include the upload script and vendored notices in source distributions
  s.preserve_paths = ['build-tools/upload-symbols.sh', 'vendor/PHPLCrashReporter/LICENSE', 'vendor/libwebp/COPYING', 'vendor/libwebp/PATENTS', 'Txlemetry/PrivateModules/**/*.modulemap']
end
