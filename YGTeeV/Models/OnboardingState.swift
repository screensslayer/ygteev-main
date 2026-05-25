//
//  OnboardingState.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import Foundation

@Observable
class OnboardingState {
    var currentStep: OnboardingStep = .welcome
    var userAnswers: [String: String] = [:]
    var birthYear: Int = 2008
    var hasCompletedOnboarding: Bool = false
    var startInLoginMode: Bool = false

    /// Grade (6–12) collected on `.gradeYear`. `nil` = "I'm not a student".
    var gradeLevel: Int? = nil
    /// Full name collected on `.name`. Written to `profiles.display_name`
    /// on signup success.
    var fullName: String = ""

    enum OnboardingStep: Equatable {
        case welcome
        case knowledgeQuestion(Int) // 0-2 for three questions
        case encouragement(EncouragementTone)
        case reward
        case vibeCheck
        case reviewPrompt
        case accountIntro
        case gradeYear           // NEW — between accountIntro and birthYear
        case birthYear
        case birthYearConfirm
        case adultRequired       // RENAMED from .kidPairing (kid SCANS a parent's QR now)
        case name                // NEW — over-13 only, between birthYearConfirm and createAccount
        case createAccount       // over 13
        case customizing         // NEW — animated "setting up your account" screen
        case optionalPaywall     // NEW — $2.99/mo offer with skip / join-group escape hatches
        case done
    }
    
    enum EncouragementTone: String, Equatable {
        case new
        case casual
        case regular
        case deep
        case correct
        case tryAgain
    }
    
    var isUnder13: Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return (currentYear - birthYear) < 13
    }
    
    func skipToEnd() {
        currentStep = .done
    }
    
    func goToLogin() {
        startInLoginMode = true
        currentStep = .createAccount
    }
    
    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .knowledgeQuestion(0)
        case .knowledgeQuestion(let index):
            // Every question lands on an encouragement screen before the
            // flow moves on — including the last trivia question, which
            // gets the same right/wrong feedback as the previous one.
            let tone = determineTone(for: index)
            currentStep = .encouragement(tone)
        case .encouragement:
            // Determine next question or move to reward
            if let lastQuestionIndex = currentQuestionIndex() {
                if lastQuestionIndex < 2 {
                    currentStep = .knowledgeQuestion(lastQuestionIndex + 1)
                } else {
                    currentStep = .reward
                }
            } else {
                currentStep = .knowledgeQuestion(1)
            }
        case .reward:
            currentStep = .vibeCheck
        case .vibeCheck:
            currentStep = .accountIntro
        case .reviewPrompt:
            currentStep = .accountIntro
        case .accountIntro:
            currentStep = .gradeYear
        case .gradeYear:
            currentStep = .birthYear
        case .birthYear:
            currentStep = .birthYearConfirm
        case .birthYearConfirm:
            if isUnder13 {
                // Under-13 lands on the parent-required screen; the only
                // forward path is `ChildSignInSheet` opened from there.
                currentStep = .adultRequired
            } else {
                currentStep = .name
            }
        case .name:
            currentStep = .createAccount
        case .adultRequired:
            // Intentionally no-op: kid can't advance on their own. They
            // either scan a parent's QR (which authenticates them and
            // RootView swaps to MainTabView) or hit the dev Skip button.
            break
        case .createAccount:
            // Account form calls nextStep() only AFTER the signup succeeds
            // and the profile row has been patched with display_name +
            // grade_year + date_of_birth.
            currentStep = .customizing
        case .customizing:
            currentStep = .optionalPaywall
        case .optionalPaywall:
            currentStep = .done
        case .done:
            hasCompletedOnboarding = true
        }
    }
    
    func showReviewPrompt() {
        currentStep = .reviewPrompt
    }
    
    func goBack() {
        switch currentStep {
        case .birthYearConfirm:
            currentStep = .birthYear
        default:
            break
        }
    }
    
    private func currentQuestionIndex() -> Int? {
        if case .encouragement = currentStep {
            // Find last question answered
            for i in (0...2).reversed() {
                if userAnswers["question_\(i)"] != nil {
                    return i
                }
            }
        }
        return nil
    }
    
    private func determineTone(for questionIndex: Int) -> EncouragementTone {
        guard let answer = userAnswers["question_\(questionIndex)"] else {
            return .new
        }
        
        // Question 0: self-assessment
        if questionIndex == 0 {
            switch answer {
            case "new": return .new
            case "casual": return .casual
            case "regular": return .regular
            case "deep": return .deep
            default: return .new
            }
        }
        
        // Question 1 & 2: trivia
        let questions = KnowledgeQuestions.all
        if questionIndex < questions.count {
            let question = questions[questionIndex]
            if answer == question.correctAnswer {
                return .correct
            } else {
                return .tryAgain
            }
        }
        
        return .new
    }
}

// MARK: - Knowledge Questions
struct KnowledgeQuestion: Identifiable {
    let id: Int
    let question: String
    let kind: QuestionKind
    let options: [QuestionOption]
    let correctAnswer: String?
    
    enum QuestionKind {
        case self_
        case trivia
    }
    
    struct QuestionOption: Identifiable {
        let id: String
        let label: String
        let subtitle: String?
    }
}

struct KnowledgeQuestions {
    static let all: [KnowledgeQuestion] = [
        KnowledgeQuestion(
            id: 0,
            question: "How would you describe your Bible journey?",
            kind: .self_,
            options: [
                .init(id: "new", label: "Brand new to it", subtitle: "Never really opened one"),
                .init(id: "casual", label: "I read sometimes", subtitle: "Holidays, youth group, etc."),
                .init(id: "regular", label: "I read regularly", subtitle: "Weekly or more"),
                .init(id: "deep", label: "I know it well", subtitle: "Studied & memorized"),
            ],
            correctAnswer: nil
        ),
        KnowledgeQuestion(
            id: 1,
            question: "Who wrote most of the Psalms?",
            kind: .trivia,
            options: [
                .init(id: "paul", label: "Paul", subtitle: nil),
                .init(id: "david", label: "King David", subtitle: nil),
                .init(id: "moses", label: "Moses", subtitle: nil),
                .init(id: "idk", label: "No idea — surprise me", subtitle: nil),
            ],
            correctAnswer: "david"
        ),
        KnowledgeQuestion(
            id: 2,
            question: "How many books are in the Bible?",
            kind: .trivia,
            options: [
                .init(id: "27", label: "27", subtitle: nil),
                .init(id: "40", label: "40", subtitle: nil),
                .init(id: "66", label: "66", subtitle: nil),
                .init(id: "idk", label: "No idea — surprise me", subtitle: nil),
            ],
            correctAnswer: "66"
        )
    ]
}
