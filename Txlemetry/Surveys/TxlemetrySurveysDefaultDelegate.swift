//
//  TxlemetrySurveysDefaultDelegate.swift
//  Txlemetry
//
//  Created by Ioannis Josephides on 18/06/2025.
//

#if os(iOS)
    import UIKit
#else
    import Foundation
#endif

final class TxlemetrySurveysDefaultDelegate: TxlemetrySurveysDelegate {
    var supportsSurveyResume: Bool { true }

    #if os(iOS)
        private var surveysWindow: UIWindow?
        private var displayController: SurveyDisplayController?
        private var pendingDisplayWorkItem: DispatchWorkItem?
        private var pendingSurvey: TxlemetryDisplaySurvey?
        private var pendingSurveyClosedHandler: OnTxlemetrySurveyClosed?
    #endif

    func renderSurvey(
        _ survey: TxlemetryDisplaySurvey,
        onSurveyShown: @escaping OnTxlemetrySurveyShown,
        onSurveyResponse: @escaping OnTxlemetrySurveyResponse,
        onSurveyClosed: @escaping OnTxlemetrySurveyClosed
    ) {
        #if os(iOS)
            guard #available(iOS 15.0, *) else { return }

            if displayController == nil {
                // setup window for first-time display
                setupWindow()
            }

            guard let displayController else {
                // If we cannot render the survey UI, treat this as a pre-render dismiss so integration state is cleared.
                onSurveyClosed(survey)
                return
            }

            // Setup handlers
            displayController.onSurveyShown = onSurveyShown
            displayController.onSurveyResponse = onSurveyResponse
            displayController.onSurveyClosed = onSurveyClosed

            scheduleSurveyDisplay(survey, displayController: displayController, onSurveyClosed: onSurveyClosed)
        #endif
    }

    func updateSurvey(_ survey: TxlemetryDisplaySurvey) {
        #if os(iOS)
            guard #available(iOS 15.0, *) else { return }

            // If the survey is still waiting out its display delay, refresh the queued copy so
            // it gets shown with the latest content.
            if pendingSurvey?.id == survey.id {
                pendingSurvey = survey
            }

            displayController?.updateSurvey(survey)
        #endif
    }

    func cleanupSurveys() {
        #if os(iOS)
            dismissPendingSurveyIfNeeded()
            displayController?.dismissSurvey() // dismiss any active surveys
            surveysWindow?.rootViewController?.dismiss(animated: true) {
                self.surveysWindow?.isHidden = true
                self.surveysWindow = nil
                self.displayController = nil
            }
        #endif
    }

    #if os(iOS)
        @available(iOS 15.0, *)
        private func setupWindow() {
            if let activeWindow = UIApplication.getCurrentWindow(), let activeScene = activeWindow.windowScene {
                let controller = SurveyDisplayController()
                displayController = controller
                surveysWindow = SurveysWindow(
                    controller: controller,
                    scene: activeScene
                )
                surveysWindow?.isHidden = false
                surveysWindow?.windowLevel = activeWindow.windowLevel + 1
            }
        }

        private func scheduleSurveyDisplay(
            _ survey: TxlemetryDisplaySurvey,
            displayController: SurveyDisplayController,
            onSurveyClosed: @escaping OnTxlemetrySurveyClosed
        ) {
            dismissPendingSurveyIfNeeded()

            let delay = max(survey.appearance?.surveyPopupDelaySeconds ?? 0, 0)
            guard delay > 0 else {
                // show the survey directly
                displayController.showSurvey(survey)
                return
            }

            hedgeLog("[Surveys] Scheduling survey \(survey.id) display in \(delay) seconds")

            // schedule a survey display for now + delay
            pendingSurvey = survey
            pendingSurveyClosedHandler = onSurveyClosed

            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                // Read the latest pending copy: `updateSurvey` may have replaced it with a
                // re-translated version (same id) while the delay was counting down. Showing
                // the captured `survey` here would drop that update.
                guard let pending = self.pendingSurvey, pending.id == survey.id else {
                    // current survey?
                    return
                }

                self.pendingDisplayWorkItem = nil
                self.pendingSurvey = nil
                self.pendingSurveyClosedHandler = nil
                displayController.showSurvey(pending)
            }

            pendingDisplayWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }

        private func dismissPendingSurveyIfNeeded() {
            guard let pendingSurvey else { return }

            pendingDisplayWorkItem?.cancel()
            pendingDisplayWorkItem = nil
            self.pendingSurvey = nil

            let pendingClosedHandler = pendingSurveyClosedHandler
            pendingSurveyClosedHandler = nil
            pendingClosedHandler?(pendingSurvey)
        }
    #endif
}

#if os(iOS) && TESTING
    extension TxlemetrySurveysDefaultDelegate {
        /// Injects a display controller so tests can drive rendering without a `UIWindowScene`
        func setDisplayControllerForTesting(_ controller: SurveyDisplayController) {
            displayController = controller
        }
    }
#endif
