#if os(iOS) || TESTING
    import Foundation

    extension TxlemetrySurvey {
        func toDisplaySurvey(
            surveyTranslation: TxlemetrySurveyTranslation? = nil,
            questionTranslations: [TxlemetrySurveyQuestionTranslation?]? = nil,
            initialQuestionIndex: Int = 0
        ) -> TxlemetryDisplaySurvey {
            let translatedQuestions = questions.enumerated().compactMap { index, question in
                let translation = questionTranslations.flatMap { index < $0.count ? $0[index] : nil }
                return question.toDisplayQuestion(translation: translation)
            }
            return TxlemetryDisplaySurvey(
                id: id,
                name: surveyTranslation?.name ?? name,
                questions: translatedQuestions,
                appearance: appearance?.toDisplayAppearance(translation: surveyTranslation),
                startDate: startDate,
                endDate: endDate,
                initialQuestionIndex: initialQuestionIndex
            )
        }
    }

    extension TxlemetrySurveyQuestion {
        func toDisplayQuestion(translation: TxlemetrySurveyQuestionTranslation? = nil) -> TxlemetryDisplaySurveyQuestion? {
            switch self {
            case let .open(question):
                return TxlemetryDisplayOpenQuestion(
                    id: question.id,
                    question: translation?.question ?? question.question,
                    questionDescription: translation?.description ?? question.description,
                    questionDescriptionContentType: question.descriptionContentType?.toDisplayContentType(),
                    isOptional: question.optional ?? false,
                    buttonText: translation?.buttonText ?? question.buttonText
                )

            case let .link(question):
                return TxlemetryDisplayLinkQuestion(
                    id: question.id,
                    question: translation?.question ?? question.question,
                    questionDescription: translation?.description ?? question.description,
                    questionDescriptionContentType: question.descriptionContentType?.toDisplayContentType(),
                    isOptional: question.optional ?? false,
                    buttonText: translation?.buttonText ?? question.buttonText,
                    link: translation?.link ?? question.link ?? ""
                )

            case let .rating(question):
                return TxlemetryDisplayRatingQuestion(
                    id: question.id,
                    question: translation?.question ?? question.question,
                    questionDescription: translation?.description ?? question.description,
                    questionDescriptionContentType: question.descriptionContentType?.toDisplayContentType(),
                    isOptional: question.optional ?? false,
                    buttonText: translation?.buttonText ?? question.buttonText,
                    ratingType: question.display.toDisplayRatingType(),
                    scaleLowerBound: question.scale.range.lowerBound,
                    scaleUpperBound: question.scale.range.upperBound,
                    lowerBoundLabel: translation?.lowerBoundLabel ?? question.lowerBoundLabel ?? "",
                    upperBoundLabel: translation?.upperBoundLabel ?? question.upperBoundLabel ?? "",
                    skipSubmitButton: question.skipSubmitButton ?? false
                )

            case let .singleChoice(question), let .multipleChoice(question):
                return TxlemetryDisplayChoiceQuestion(
                    id: question.id,
                    question: translation?.question ?? question.question,
                    questionDescription: translation?.description ?? question.description,
                    questionDescriptionContentType: question.descriptionContentType?.toDisplayContentType(),
                    isOptional: question.optional ?? false,
                    buttonText: translation?.buttonText ?? question.buttonText,
                    choices: translation?.choices ?? question.choices,
                    hasOpenChoice: question.hasOpenChoice ?? false,
                    shuffleOptions: question.shuffleOptions ?? false,
                    isMultipleChoice: isMultipleChoice,
                    skipSubmitButton: question.skipSubmitButton ?? false
                )

            default:
                return nil
            }
        }

        private var isMultipleChoice: Bool {
            switch self {
            case .multipleChoice: return true
            default: return false
            }
        }
    }

    extension TxlemetrySurveyTextContentType {
        func toDisplayContentType() -> TxlemetryDisplaySurveyTextContentType {
            if case .html = self {
                return .html
            }
            return .text
        }
    }

    extension TxlemetrySurveyRatingDisplayType {
        func toDisplayRatingType() -> TxlemetryDisplaySurveyRatingType {
            if case .emoji = self {
                return .emoji
            }
            return .number
        }
    }

    extension TxlemetrySurveyAppearance {
        func toDisplayAppearance(translation: TxlemetrySurveyTranslation? = nil) -> TxlemetryDisplaySurveyAppearance {
            TxlemetryDisplaySurveyAppearance(
                fontFamily: fontFamily,
                backgroundColor: backgroundColor,
                borderColor: borderColor,
                submitButtonColor: submitButtonColor,
                submitButtonText: submitButtonText,
                submitButtonTextColor: submitButtonTextColor,
                textColor: textColor,
                descriptionTextColor: descriptionTextColor,
                ratingButtonColor: ratingButtonColor,
                ratingButtonActiveColor: ratingButtonActiveColor,
                inputBackground: inputBackground,
                inputTextColor: inputTextColor,
                placeholder: placeholder,
                surveyPopupDelaySeconds: surveyPopupDelaySeconds,
                displayThankYouMessage: displayThankYouMessage ?? true,
                thankYouMessageHeader: translation?.thankYouMessageHeader ?? thankYouMessageHeader,
                thankYouMessageDescription: translation?.thankYouMessageDescription ?? thankYouMessageDescription,
                thankYouMessageDescriptionContentType: thankYouMessageDescriptionContentType?.toDisplayContentType(),
                thankYouMessageCloseButtonText: translation?.thankYouMessageCloseButtonText ?? thankYouMessageCloseButtonText,
                displayIntroScreen: displayIntroScreen ?? false,
                introScreenHeader: translation?.introScreenHeader ?? introScreenHeader,
                introScreenDescription: translation?.introScreenDescription ?? introScreenDescription,
                introScreenDescriptionContentType: introScreenDescriptionContentType?.toDisplayContentType(),
                introScreenButtonText: translation?.introScreenButtonText ?? introScreenButtonText
            )
        }
    }
#endif
