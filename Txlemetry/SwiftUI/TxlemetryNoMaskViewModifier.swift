//
//  TxlemetryNoMaskViewModifier.swift
//  Txlemetry
//
//  Created by Yiannis Josephides on 09/10/2024.
//

#if os(iOS) && canImport(SwiftUI)

    import SwiftUI

    /// SwiftUI session replay unmasking helpers.
    public extension View {
        /**
         Marks a SwiftUI View to be excluded from masking in Txlemetry session replay recordings.

         Note: On iOS 26+ (Xcode 26 SwiftUI rendering engine), SwiftUI views may no longer map
         reliably to a backing `UIView`, so this modifier may behave inconsistently. A future SDK
         update will try to address this limitation, but for now, we recommend using this modifier
         with caution.

         There are cases where Txlemetry SDK will unintentionally mask some SwiftUI views.

         Because of the nature of how we intercept SwiftUI view hierarchy (and how it maps to UIKit),
         we can't always be 100% confident that a view should be masked. For that reason, we prefer to
         take a proactive and prefer to mask views if we're not sure.

         Use this modifier to prevent views from being masked in session replay recordings.

         For example:
         ```swift
         // This view may be accidentally masked by Txlemetry SDK
         SomeSafeView()

         // This custom view (and all its subviews) will not be masked in recordings
         SomeSafeView()
           .txlemetryNoMask()
         ```

         - Returns: A modified view that will not be masked in session replay recordings
         */
        func txlemetryNoMask() -> some View {
            modifier(
                TxlemetryTagViewModifier(
                    onChange: { owner, views, layers in
                        views.forEach { $0.setTxlemetryNoMask(true, owner: owner) }
                        layers.forEach { $0.setTxlemetryNoMask(true, owner: owner) }
                    },
                    onRemove: { owner, views, layers in
                        views.forEach { $0.setTxlemetryNoMask(false, owner: owner) }
                        layers.forEach { $0.setTxlemetryNoMask(false, owner: owner) }
                    }
                )
            )
        }
    }

    // Ref-counted ownership (see TxlemetryFlagOwners): overlapping no-mask regions
    // must not clear each other on teardown.
    extension UIView {
        var txlemetryNoMask: Bool {
            isTxlemetryFlagOwned(&AssociatedKeys.phNoMask)
        }

        func setTxlemetryNoMask(_ enabled: Bool, owner: UIView) {
            setTxlemetryFlag(&AssociatedKeys.phNoMask, enabled: enabled, owner: owner)
        }
    }

    extension CALayer {
        var txlemetryNoMask: Bool {
            isTxlemetryFlagOwned(&AssociatedKeys.phNoMask)
        }

        func setTxlemetryNoMask(_ enabled: Bool, owner: UIView) {
            setTxlemetryFlag(&AssociatedKeys.phNoMask, enabled: enabled, owner: owner)
        }
    }

#endif
