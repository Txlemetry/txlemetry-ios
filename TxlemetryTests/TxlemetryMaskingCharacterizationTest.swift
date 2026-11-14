//
//  TxlemetryMaskingCharacterizationTest.swift
//  Txlemetry
//
//  Created by Jiri Urbasek on 16/07/2026.
//

#if os(iOS)
    import Foundation
    @testable import Txlemetry
    import SwiftUI
    import Testing
    import UIKit

    /// Characterization tests pinning the CURRENT behavior of the SwiftUI masking
    /// machinery: the tag-view traversal (`getTargetViews` and its helpers) and the
    /// iOS 26 content-layer collection.
    ///
    /// These are golden tests: they encode what the SDK does today — including
    /// behaviors that are quirky but relied upon — so that the performance rework
    /// of this machinery can prove it did not change resolution behavior. They are
    /// intentionally written against synthetic UIKit hierarchies (not hosted
    /// SwiftUI) so they are deterministic and OS-rendering independent.
    ///
    /// Known-buggy behaviors that these tests deliberately do NOT pin (they are
    /// slated to change, with their own tests, in later commits): the Boolean
    /// unmask-on-remove of overlapping masks (`txlemetryMask()`'s `onRemove`), and
    /// the hosting-view-sized reference frame of the iOS 26 layer scan.
    @Suite("SwiftUI masking characterization", .serialized)
    @MainActor
    final class TxlemetryMaskingCharacterizationTest {
        // MARK: - getTargetViews

        @Test("targets are the DFS pre-order views between anchor and tagger, excluding injected views")
        func targetViewsFlatSandwich() {
            let (anchor, tagger) = TxlemetryTaggingTestSupport.makeTagPair()

            let root = UIView()
            let contentA = UIView()
            let childOfA = UIView()
            let contentB = UIView()

            contentA.addSubview(childOfA)
            root.addSubview(anchor)
            root.addSubview(contentA)
            root.addSubview(contentB)
            root.addSubview(tagger)

            let targets = TxlemetryTaggingTestSupport.targetViews(from: tagger)

            #expect(targets.count == 3)
            #expect(targets.elementsEqual([contentA, childOfA, contentB], by: ===))
        }

        @Test("wrapper hosts: anchor-side wrapper is dropped by traversal order, tagger-side wrapper only if marked injected")
        func targetViewsWrappedSandwich() {
            let (anchor, tagger) = TxlemetryTaggingTestSupport.makeTagPair()

            // Mirrors the structure the representables produce: anchor/tagger sit
            // inside platform-host wrapper views, and `updateUIView` marks the
            // wrapper (superview) as an injected view.
            let root = UIView()
            let anchorHost = UIView()
            let stack = UIView()
            let label1 = UIView()
            let label2 = UIView()
            let taggerHost = UIView()

            anchorHost.addSubview(anchor)
            stack.addSubview(label1)
            stack.addSubview(label2)
            taggerHost.addSubview(tagger)
            root.addSubview(anchorHost)
            root.addSubview(stack)
            root.addSubview(taggerHost)

            TxlemetryTaggingTestSupport.markInjected(anchor)
            TxlemetryTaggingTestSupport.markInjected(tagger)

            let targets = TxlemetryTaggingTestSupport.targetViews(from: tagger)

            // anchorHost precedes the anchor in DFS order, so drop(while:) removes
            // it; taggerHost was marked injected (as the representable would), so
            // the filter removes it. What remains is the content in between.
            #expect(targets.elementsEqual([stack, label1, label2], by: ===))
        }

        @Test("tagger without a hierarchy resolves no targets")
        func targetViewsNotInHierarchy() {
            let (_, tagger) = TxlemetryTaggingTestSupport.makeTagPair()

            // Never added to a superview: the tagger's back-reference is only set
            // in didMoveToSuperview, so anchor lookup fails.
            #expect(TxlemetryTaggingTestSupport.targetViews(from: tagger).isEmpty)
        }

        @Test("anchor and tagger in disjoint trees resolve no targets")
        func targetViewsDisjointTrees() {
            let (anchor, tagger) = TxlemetryTaggingTestSupport.makeTagPair()

            let treeA = UIView()
            let treeB = UIView()
            treeA.addSubview(anchor)
            treeB.addSubview(tagger)

            #expect(TxlemetryTaggingTestSupport.targetViews(from: tagger).isEmpty)
        }

        // MARK: - Traversal helpers

        @Test("descendants enumerate in DFS pre-order, excluding the receiver")
        func descendantsPreOrder() {
            let root = UIView()
            let a = UIView()
            let a1 = UIView()
            let a2 = UIView()
            let b = UIView()
            let b1 = UIView()

            a.addSubview(a1)
            a.addSubview(a2)
            b.addSubview(b1)
            root.addSubview(a)
            root.addSubview(b)

            let result = TxlemetryTaggingTestSupport.descendants(of: root)
            #expect(result.elementsEqual([a, a1, a2, b, b1], by: ===))
        }

        @Test("nearest common ancestor of siblings is their parent")
        func nearestCommonAncestorSiblings() {
            let parent = UIView()
            let a = UIView()
            let b = UIView()
            parent.addSubview(a)
            parent.addSubview(b)

            #expect(TxlemetryTaggingTestSupport.nearestCommonAncestor(of: a, and: b) === parent)
        }

        @Test("quirk: for ancestor/descendant pairs the result skips ABOVE the ancestor")
        func nearestCommonAncestorAncestorDescendantQuirk() {
            // `isDescendant(of:)` here excludes self (ancestors drops the first
            // element), so walking up from the descendant never terminates AT the
            // ancestor — it terminates one level above it. Pinned as-is: the real
            // anchor/tagger pairs are never ancestor/descendant, so this quirk is
            // dormant, but a traversal rewrite must not accidentally "fix" visible
            // behavior while restructuring.
            let root = UIView()
            let mid = UIView()
            let leaf = UIView()
            root.addSubview(mid)
            mid.addSubview(leaf)

            #expect(TxlemetryTaggingTestSupport.nearestCommonAncestor(of: leaf, and: mid) === root)
            #expect(TxlemetryTaggingTestSupport.nearestCommonAncestor(of: leaf, and: root) == nil)
        }

        @Test("nearest common ancestor of disjoint trees is nil")
        func nearestCommonAncestorDisjoint() {
            #expect(TxlemetryTaggingTestSupport.nearestCommonAncestor(of: UIView(), and: UIView()) == nil)
        }

        @Test("quirk is asymmetric: receiver that IS an ancestor of the other resolves to itself")
        func nearestCommonAncestorSelfIsAncestor() {
            // The receiver's own chain starts at self, so when the receiver is a
            // proper ancestor of the argument it returns itself — the opposite
            // direction (see the quirk test above) skips one level up.
            let root = UIView()
            let mid = UIView()
            let leaf = UIView()
            root.addSubview(mid)
            mid.addSubview(leaf)

            #expect(TxlemetryTaggingTestSupport.nearestCommonAncestor(of: mid, and: leaf) === mid)
        }

        @Test("tagger nested inside the anchor's subtree resolves no targets")
        func targetViewsTaggerInsideAnchor() {
            // Degenerate shape (never produced by the real modifier): the common
            // ancestor resolves to the anchor itself, and the anchor is not part
            // of its own descendants — so the traversal never starts.
            let (anchor, tagger) = TxlemetryTaggingTestSupport.makeTagPair()
            let root = UIView()
            let inner = UIView()
            root.addSubview(anchor)
            anchor.addSubview(inner)
            inner.addSubview(tagger)

            #expect(TxlemetryTaggingTestSupport.targetViews(from: tagger).isEmpty)
        }

        // MARK: - iOS 26 content-layer collection

        @Test("content layers: collects sized, non-view-backed layers whose center is inside the reference frame")
        func contentLayerCollection() throws {
            guard #available(iOS 26.0, *) else { return }

            let referenceFrame = CGRect(x: 0, y: 0, width: 200, height: 200)
            let root = CALayer()
            root.frame = referenceFrame

            let content = CALayer()
            content.frame = CGRect(x: 10, y: 10, width: 50, height: 50)
            root.addSublayer(content)

            let zeroSized = CALayer()
            zeroSized.frame = .zero
            root.addSublayer(zeroSized)

            let viewBacked = CALayer()
            viewBacked.frame = CGRect(x: 20, y: 100, width: 50, height: 50)
            let backingView = UIView()
            viewBacked.delegate = backingView
            root.addSublayer(viewBacked)

            // Center outside the reference frame -> not collected itself, but
            // recursion continues into its children, which can still qualify.
            let outside = CALayer()
            outside.frame = CGRect(x: 150, y: 150, width: 300, height: 300)
            let childInside = CALayer()
            childInside.frame = CGRect(x: 0, y: 0, width: 20, height: 20) // absolute (150,150), center inside
            outside.addSublayer(childInside)
            root.addSublayer(outside)

            let collected = TxlemetryTaggingTestSupport.contentLayers(under: root, containedIn: referenceFrame)

            #expect(collected.elementsEqual([content, childInside], by: ===))
        }
    }

    /// Behavior tests for the ref-counted flag ownership and the re-resolution
    /// coalescer — the two mechanisms that make overlapping masks safe (one mask's
    /// teardown must not unmask targets still claimed by another) and hierarchy
    /// churn affordable (one resolution per tagger per run-loop turn).
    @Suite("SwiftUI masking ownership & coalescing", .serialized)
    @MainActor
    final class TxlemetryMaskOwnershipTest {
        private func maskHandlers() -> (onChange: TxlemetryTagHandler, onRemove: TxlemetryTagHandler) {
            (
                onChange: { owner, views, layers in
                    views.forEach { $0.setTxlemetryNoMask(true, owner: owner) }
                    layers.forEach { $0.setTxlemetryNoMask(true, owner: owner) }
                },
                onRemove: { owner, views, layers in
                    views.forEach { $0.setTxlemetryNoMask(false, owner: owner) }
                    layers.forEach { $0.setTxlemetryNoMask(false, owner: owner) }
                }
            )
        }

        @Test("a view stays flagged until every owner releases it")
        func overlappingOwnersOnView() {
            let view = UIView()
            let ownerA = UIView()
            let ownerB = UIView()

            view.setTxlemetryNoMask(true, owner: ownerA)
            view.setTxlemetryNoMask(true, owner: ownerB)
            #expect(view.txlemetryNoMask)

            view.setTxlemetryNoMask(false, owner: ownerA)
            #expect(view.txlemetryNoMask, "still owned by B")

            view.setTxlemetryNoMask(false, owner: ownerB)
            #expect(!view.txlemetryNoMask)
        }

        @Test("a layer stays flagged until every owner releases it")
        func overlappingOwnersOnLayer() {
            let layer = CALayer()
            let ownerA = UIView()
            let ownerB = UIView()

            layer.setTxlemetryNoMask(true, owner: ownerA)
            layer.setTxlemetryNoMask(true, owner: ownerB)
            layer.setTxlemetryNoMask(false, owner: ownerB)
            #expect(layer.txlemetryNoMask)

            layer.setTxlemetryNoMask(false, owner: ownerA)
            #expect(!layer.txlemetryNoMask)
        }

        @Test("a dead owner's claim self-heals instead of flagging the target forever")
        func deadOwnerClaimSelfHeals() {
            let view = UIView()
            weak var probe: UIView?
            autoreleasepool {
                let owner = UIView()
                probe = owner
                view.setTxlemetryNoMask(true, owner: owner)
                #expect(view.txlemetryNoMask)
            }
            #expect(probe == nil, "owner must be deallocated for this test to be meaningful")
            #expect(!view.txlemetryNoMask, "a claim must not outlive its owner")
        }

        @Test("dismantling one of two overlapping masks keeps the shared target masked")
        func overlappingMasksThroughMachinery() {
            // Two real anchor/tagger sandwiches whose target sets both contain the
            // shared view — the RC7 scenario where the Boolean flag used to let the
            // first teardown unmask the survivor's target.
            let (anchor1, tagger1) = TxlemetryTaggingTestSupport.makeTagPair()
            let (anchor2, tagger2) = TxlemetryTaggingTestSupport.makeTagPair()
            let root = UIView()
            let shared = UIView()
            root.addSubview(anchor1)
            root.addSubview(anchor2)
            root.addSubview(shared)
            root.addSubview(tagger2)
            root.addSubview(tagger1)

            let handlers = maskHandlers()
            let coordinator1 = TxlemetryTagView.Coordinator(onRemove: handlers.onRemove)
            let coordinator2 = TxlemetryTagView.Coordinator(onRemove: handlers.onRemove)

            resolveTagTargets(from: tagger1, coordinator: coordinator1, onChange: handlers.onChange)
            resolveTagTargets(from: tagger2, coordinator: coordinator2, onChange: handlers.onChange)
            #expect(shared.txlemetryNoMask)

            TxlemetryTagView.dismantleUIView(tagger2, coordinator: coordinator2)
            #expect(shared.txlemetryNoMask, "still owned by the first mask")

            TxlemetryTagView.dismantleUIView(tagger1, coordinator: coordinator1)
            #expect(!shared.txlemetryNoMask)
        }

        @Test("an empty re-resolution releases all previously claimed targets")
        func emptyResolutionReleasesAllClaims() {
            let (anchor, tagger) = TxlemetryTaggingTestSupport.makeTagPair()
            let root = UIView()
            let target = UIView()
            root.addSubview(anchor)
            root.addSubview(target)
            root.addSubview(tagger)

            let handlers = maskHandlers()
            let coordinator = TxlemetryTagView.Coordinator(onRemove: handlers.onRemove)

            resolveTagTargets(from: tagger, coordinator: coordinator, onChange: handlers.onChange)
            #expect(target.txlemetryNoMask)

            // Break the sandwich (anchor gone → resolution is empty) while the tagger
            // stays alive: the recycled target must not keep the stale no-mask claim.
            anchor.removeFromSuperview()
            resolveTagTargets(from: tagger, coordinator: coordinator, onChange: handlers.onChange)
            #expect(!target.txlemetryNoMask, "stale claim would mark recycled content safe to record")
            #expect(coordinator.cachedTargets.isEmpty)
        }

        @Test("reconcileAndEmit releases dropped layers on an empty resolution without emitting")
        func reconcileAndEmitEmptyLayerResolution() {
            let owner = UIView()
            let previous = [CALayer(), CALayer()]
            var removed: [CALayer] = []
            var changed = false

            let cache = reconcileAndEmit(
                owner: owner,
                resolved: [CALayer](),
                previous: previous,
                onRemove: { _, dropped in removed = dropped },
                onChange: { _, _ in changed = true }
            )

            #expect(removed.count == 2)
            #expect(!changed, "onChange must not fire for an empty resolution")
            #expect(cache.isEmpty)
        }

        @Test("re-resolution releases ownership on targets that dropped out")
        func reconciliationReleasesDroppedTargets() {
            let (anchor, tagger) = TxlemetryTaggingTestSupport.makeTagPair()
            let root = UIView()
            let keep = UIView()
            let dropped = UIView()
            root.addSubview(anchor)
            root.addSubview(keep)
            root.addSubview(dropped)
            root.addSubview(tagger)

            let handlers = maskHandlers()
            let coordinator = TxlemetryTagView.Coordinator(onRemove: handlers.onRemove)

            resolveTagTargets(from: tagger, coordinator: coordinator, onChange: handlers.onChange)
            #expect(keep.txlemetryNoMask)
            #expect(dropped.txlemetryNoMask)

            // SwiftUI moves the view out of the sandwich; the next resolution must
            // release this tagger's claim on it.
            let elsewhere = UIView()
            elsewhere.addSubview(dropped)
            resolveTagTargets(from: tagger, coordinator: coordinator, onChange: handlers.onChange)

            #expect(keep.txlemetryNoMask)
            #expect(!dropped.txlemetryNoMask)
        }

        @Test("iOS 26 layer scan: reference frame is the masked view's own extent, not the hosting view's")
        func layerScanBoundedToCaptureExtent() {
            guard #available(iOS 26.0, *) else { return }

            // Mirrors the iOS 26 structure: content layers are bare sublayers of the
            // hosting view; the capture view sits two wrapper views deep and spans
            // exactly the masked view's extent.
            let host = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 600))
            let contentInside = CALayer()
            contentInside.frame = CGRect(x: 10, y: 10, width: 50, height: 20)
            host.layer.addSublayer(contentInside)
            let contentOutside = CALayer()
            contentOutside.frame = CGRect(x: 10, y: 300, width: 50, height: 20)
            host.layer.addSublayer(contentOutside)

            let inherited = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
            let platformHost = UIView(frame: inherited.bounds)
            let captureView = TxlemetryTaggingTestSupport.makeFrameCaptureView()
            captureView.frame = platformHost.bounds
            platformHost.addSubview(captureView)
            inherited.addSubview(platformHost)
            host.addSubview(inherited)

            let layers = TxlemetryTaggingTestSupport.targetLayers(fromCaptureView: captureView)

            // Previously the reference frame was the whole hosting view, so
            // contentOutside — a different mask's content — was collected too.
            #expect(layers.elementsEqual([contentInside], by: ===))
        }

        @Test("iOS 26 layer scan: clipped subtrees outside the reference frame are pruned")
        func layerScanPrunesClippedSubtrees() {
            guard #available(iOS 26.0, *) else { return }

            let referenceFrame = CGRect(x: 0, y: 0, width: 200, height: 200)
            let root = CALayer()
            root.frame = referenceFrame

            // The clipped parent lies fully outside the reference frame; its child's
            // absolute center falls inside, but masksToBounds means the child renders
            // clipped away — collecting it would mask a region with no such content.
            let clipped = CALayer()
            clipped.frame = CGRect(x: 300, y: 300, width: 100, height: 100)
            clipped.masksToBounds = true
            let child = CALayer()
            child.frame = CGRect(x: -250, y: -250, width: 50, height: 50)
            clipped.addSublayer(child)
            root.addSublayer(clipped)

            let collected = TxlemetryTaggingTestSupport.contentLayers(under: root, containedIn: referenceFrame)
            #expect(collected.isEmpty)
        }

        @Test("coalescer resolves each dirty tagger exactly once per drain")
        func coalescerDrainsOncePerTagger() {
            let (anchor1, tagger1) = TxlemetryTaggingTestSupport.makeTagPair()
            let (anchor2, tagger2) = TxlemetryTaggingTestSupport.makeTagPair()
            let root = UIView()
            root.addSubview(anchor1)
            root.addSubview(anchor2)
            root.addSubview(tagger2)
            root.addSubview(tagger1)

            var resolutions1 = 0
            var resolutions2 = 0
            tagger1.handler = { resolutions1 += 1 }
            tagger2.handler = { resolutions2 += 1 }

            TxlemetryTagResolutionCoalescer.markDirty(tagger1)
            TxlemetryTagResolutionCoalescer.markDirty(tagger1)
            TxlemetryTagResolutionCoalescer.markDirty(tagger2)
            TxlemetryTagResolutionCoalescer.markDirty(tagger1)
            TxlemetryTagResolutionCoalescer.drainForTesting()

            #expect(resolutions1 == 1)
            #expect(resolutions2 == 1)

            TxlemetryTagResolutionCoalescer.drainForTesting()
            #expect(resolutions1 == 1, "drained set does not fire again")
        }
    }

    /// Behavior tests for the `txlemetryMask()` reporter registry: masked regions are
    /// registered by lifecycle, read live at capture time, filtered per window, and
    /// self-healing on missed teardown.
    @Suite("Session replay mask registry", .serialized)
    @MainActor
    final class TxlemetryMaskRegistryTest {
        @Test("reporter rects are read live at capture time, never cached")
        func liveRects() {
            let registry = TxlemetrySessionReplayMaskRegistry()
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let container = UIView(frame: window.bounds)
            window.addSubview(container)
            let reporter = TxlemetryMaskReporterUIView(frame: CGRect(x: 10, y: 20, width: 100, height: 40))
            container.addSubview(reporter)
            defer { reporter.removeFromSuperview() }
            window.layoutIfNeeded()

            registry.register(reporter)
            #expect(registry.maskedRects(in: window).rects == [CGRect(x: 10, y: 20, width: 100, height: 40)])

            // Reposition without any registry interaction — the next read must see
            // the current geometry (this is the property that keeps fast-scrolling
            // content redacted at its actual position).
            reporter.frame = CGRect(x: 30, y: 200, width: 50, height: 25)
            #expect(registry.maskedRects(in: window).rects == [CGRect(x: 30, y: 200, width: 50, height: 25)])

            registry.unregister(reporter)
            #expect(registry.maskedRects(in: window).rects.isEmpty)
        }

        @Test("reporters attached to other windows are excluded")
        func windowFiltering() {
            let registry = TxlemetrySessionReplayMaskRegistry()
            let windowA = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let windowB = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let reporterA = TxlemetryMaskReporterUIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
            let reporterB = TxlemetryMaskReporterUIView(frame: CGRect(x: 5, y: 5, width: 10, height: 10))
            windowA.addSubview(reporterA)
            windowB.addSubview(reporterB)
            defer {
                reporterA.removeFromSuperview()
                reporterB.removeFromSuperview()
            }
            windowA.layoutIfNeeded()
            windowB.layoutIfNeeded()
            registry.register(reporterA)
            registry.register(reporterB)

            #expect(registry.maskedRects(in: windowA).rects == [CGRect(x: 0, y: 0, width: 10, height: 10)])
            #expect(registry.maskedRects(in: windowB).rects == [CGRect(x: 5, y: 5, width: 10, height: 10)])
        }

        @Test("deallocated reporters self-heal out of the registry")
        func weakSelfHealing() {
            let registry = TxlemetrySessionReplayMaskRegistry()
            autoreleasepool {
                let reporter = TxlemetryMaskReporterUIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
                registry.register(reporter)
                #expect(registry.registeredCountForTesting == 1)
            }
            #expect(registry.registeredCountForTesting == 0)
        }

        @Test("reporter view registers on window attach, unregisters on detach and disable")
        func reporterLifecycle() {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let reporter = TxlemetryMaskReporterUIView(frame: CGRect(x: 10, y: 10, width: 50, height: 50))

            #expect(TxlemetrySessionReplayMaskRegistry.shared.maskedRects(in: window).rects.isEmpty)

            window.addSubview(reporter)
            window.layoutIfNeeded()
            #expect(TxlemetrySessionReplayMaskRegistry.shared.maskedRects(in: window).rects == [CGRect(x: 10, y: 10, width: 50, height: 50)])

            reporter.isMaskingEnabled = false
            #expect(TxlemetrySessionReplayMaskRegistry.shared.maskedRects(in: window).rects.isEmpty)

            reporter.isMaskingEnabled = true
            #expect(TxlemetrySessionReplayMaskRegistry.shared.maskedRects(in: window).rects.count == 1)

            reporter.removeFromSuperview()
            #expect(TxlemetrySessionReplayMaskRegistry.shared.maskedRects(in: window).rects.isEmpty)
        }

        @Test("capture collection includes live reporter rects")
        func captureCollectionIncludesReporters() {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let container = UIView(frame: window.bounds)
            window.addSubview(container)

            let reporter = TxlemetryMaskReporterUIView(frame: CGRect(x: 10, y: 100, width: 100, height: 40))
            container.addSubview(reporter)
            defer { reporter.removeFromSuperview() }
            window.layoutIfNeeded()

            let integration = TxlemetryReplayIntegration()
            let rects = integration.collectMaskableRects(in: window)

            #expect(rects == [CGRect(x: 10, y: 100, width: 100, height: 40)], "reporter rect flows through the capture collection")
        }

        // MARK: - Pre-first-layout gap (fail closed)

        @Test("a reporter completes its first layout even at zero size")
        func zeroSizeReporterCompletesFirstLayout() {
            // A zero-sized view must still get a layout pass, or it would flag the
            // window unsettled forever and block snapshots.
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let reporter = TxlemetryMaskReporterUIView(frame: .zero)
            #expect(!reporter.hasCompletedFirstLayout)

            window.addSubview(reporter)
            defer { reporter.removeFromSuperview() }
            window.layoutIfNeeded()

            #expect(reporter.hasCompletedFirstLayout)
        }

        @Test("a pre-layout reporter marks the window unsettled instead of being dropped")
        func preLayoutReporterMarksUnsettled() {
            let registry = TxlemetrySessionReplayMaskRegistry()
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let reporter = TxlemetryMaskReporterUIView(frame: CGRect(x: 10, y: 20, width: 100, height: 40))
            window.addSubview(reporter)
            defer { reporter.removeFromSuperview() }
            registry.register(reporter)

            // Registered but not laid out yet: dropping it silently would leave the
            // region unmasked.
            let beforeLayout = registry.maskedRects(in: window)
            #expect(beforeLayout.hasUnsettledReporters)
            #expect(beforeLayout.rects.isEmpty)

            window.layoutIfNeeded()
            let afterLayout = registry.maskedRects(in: window)
            #expect(!afterLayout.hasUnsettledReporters)
            #expect(afterLayout.rects == [CGRect(x: 10, y: 20, width: 100, height: 40)])
        }

        @Test("a zero-sized reporter that has been laid out does not block snapshots")
        func laidOutZeroSizeReporterDoesNotBlock() {
            let registry = TxlemetrySessionReplayMaskRegistry()
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let reporter = TxlemetryMaskReporterUIView(frame: .zero)
            window.addSubview(reporter)
            defer { reporter.removeFromSuperview() }
            window.layoutIfNeeded()
            registry.register(reporter)

            let result = registry.maskedRects(in: window)
            #expect(!result.hasUnsettledReporters, "legitimately empty view must not stall capture")
            #expect(result.rects.isEmpty)
        }

        @Test("an unsettled reporter in another window does not block this window")
        func unsettledReporterInOtherWindowDoesNotBlock() {
            // Guard-order pin: the window filter must precede the settled check, or a
            // side window realizing content would stall the foreground window's capture.
            let registry = TxlemetrySessionReplayMaskRegistry()
            let windowA = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let windowB = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))

            let settled = TxlemetryMaskReporterUIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
            windowA.addSubview(settled)
            defer { settled.removeFromSuperview() }
            windowA.layoutIfNeeded()

            let unsettled = TxlemetryMaskReporterUIView(frame: CGRect(x: 5, y: 5, width: 10, height: 10))
            windowB.addSubview(unsettled)
            defer { unsettled.removeFromSuperview() }
            // no layout pass in windowB

            registry.register(settled)
            registry.register(unsettled)

            let resultA = registry.maskedRects(in: windowA)
            #expect(!resultA.hasUnsettledReporters)
            #expect(resultA.rects == [CGRect(x: 0, y: 0, width: 10, height: 10)])

            #expect(registry.maskedRects(in: windowB).hasUnsettledReporters)
        }

        @Test("a hidden pre-layout reporter does not mark the window unsettled")
        func hiddenPreLayoutReporterDoesNotMarkUnsettled() {
            // Hidden content isn't rendered, so it must not stall the frame even pre-layout.
            let registry = TxlemetrySessionReplayMaskRegistry()
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let reporter = TxlemetryMaskReporterUIView(frame: CGRect(x: 10, y: 20, width: 100, height: 40))
            reporter.isHidden = true
            window.addSubview(reporter)
            defer { reporter.removeFromSuperview() }
            registry.register(reporter)

            let result = registry.maskedRects(in: window)
            #expect(!result.hasUnsettledReporters)
            #expect(result.rects.isEmpty)
        }

        @Test("an alpha-zero pre-layout reporter does not mark the window unsettled")
        func alphaZeroPreLayoutReporterDoesNotMarkUnsettled() {
            // Pins the other half of the visibility guard order (see the hidden test).
            let registry = TxlemetrySessionReplayMaskRegistry()
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let reporter = TxlemetryMaskReporterUIView(frame: CGRect(x: 10, y: 20, width: 100, height: 40))
            reporter.alpha = 0
            window.addSubview(reporter)
            defer { reporter.removeFromSuperview() }
            registry.register(reporter)

            let result = registry.maskedRects(in: window)
            #expect(!result.hasUnsettledReporters)
            #expect(result.rects.isEmpty)
        }

        @Test("same-window re-adds (cell reuse) keep the reporter settled")
        func sameWindowReaddKeepsSettled() {
            // Cell reuse re-fires didMoveToWindow on every recycle; resetting there
            // would skip capture ticks throughout a scroll gesture.
            let registry = TxlemetrySessionReplayMaskRegistry()
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let reporter = TxlemetryMaskReporterUIView(frame: CGRect(x: 10, y: 20, width: 100, height: 40))
            window.addSubview(reporter)
            defer { reporter.removeFromSuperview() }
            window.layoutIfNeeded()
            registry.register(reporter)
            #expect(reporter.hasCompletedFirstLayout)

            reporter.removeFromSuperview()
            window.addSubview(reporter)

            let result = registry.maskedRects(in: window)
            #expect(!result.hasUnsettledReporters)
            #expect(result.rects == [CGRect(x: 10, y: 20, width: 100, height: 40)])
        }

        @Test("reattaching to a window requires a fresh layout pass before the reporter settles")
        func reattachmentRequiresFreshLayout() {
            let registry = TxlemetrySessionReplayMaskRegistry()
            let windowA = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let windowB = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let reporter = TxlemetryMaskReporterUIView(frame: CGRect(x: 10, y: 20, width: 100, height: 40))
            windowA.addSubview(reporter)
            defer { reporter.removeFromSuperview() }
            windowA.layoutIfNeeded()
            registry.register(reporter)
            #expect(reporter.hasCompletedFirstLayout)

            // Old-window geometry is stale: fail closed until the new window lays it out.
            windowB.addSubview(reporter)
            #expect(!reporter.hasCompletedFirstLayout)
            #expect(registry.maskedRects(in: windowB).hasUnsettledReporters)

            windowB.layoutIfNeeded()
            let settled = registry.maskedRects(in: windowB)
            #expect(!settled.hasUnsettledReporters)
            #expect(settled.rects == [CGRect(x: 10, y: 20, width: 100, height: 40)])
        }

        @Test("a SwiftUI-hosted zero-sized mask settles after the hosting layout pass")
        func swiftUIHostedZeroSizeMaskSettles() {
            // Pins that real SwiftUI hosting delivers a first layout pass even to a
            // zero-sized masked view.
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let baselineCount = TxlemetrySessionReplayMaskRegistry.shared.registeredCountForTesting
            let host = UIHostingController(rootView: Color.clear.frame(width: 0, height: 0).txlemetryMask())
            window.rootViewController = host
            window.isHidden = false
            defer {
                window.isHidden = true
                window.rootViewController = nil
            }
            window.layoutIfNeeded()

            // Non-vacuity: exactly this test's reporter must have registered.
            #expect(TxlemetrySessionReplayMaskRegistry.shared.registeredCountForTesting == baselineCount + 1)
            #expect(!TxlemetrySessionReplayMaskRegistry.shared.maskedRects(in: window).hasUnsettledReporters)
        }

        @Test("capture collection skips the frame while a reporter is unsettled")
        func captureCollectionSkipsUnsettledFrame() {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            let container = UIView(frame: window.bounds)
            window.addSubview(container)
            window.layoutIfNeeded()

            // Like a lazy row: attaching registers the reporter before any layout pass.
            let reporter = TxlemetryMaskReporterUIView(frame: CGRect(x: 10, y: 100, width: 100, height: 40))
            container.addSubview(reporter)
            defer { reporter.removeFromSuperview() }

            let integration = TxlemetryReplayIntegration()
            #expect(integration.collectMaskableRects(in: window) == nil, "frame must be skipped, not captured under-masked")

            window.layoutIfNeeded()
            #expect(integration.collectMaskableRects(in: window) == [CGRect(x: 10, y: 100, width: 100, height: 40)])
        }
    }
#endif
