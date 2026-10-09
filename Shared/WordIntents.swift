import AppIntents
import WidgetKit

private enum WidgetLearningActions {
    static func perform(_ action: LearningAction) throws {
        try LearningStore().perform(action)
        WidgetCenter.shared.reloadTimelines(ofKind: LearningStore.widgetKind)
    }
}

struct RefreshWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh current word"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: LearningStore.widgetKind)
        return .result()
    }
}

struct NextWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Next word"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        try WidgetLearningActions.perform(.next)
        return .result()
    }
}

struct PreviousWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous word"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        try WidgetLearningActions.perform(.previous)
        return .result()
    }
}

struct RemindWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Remind me"
    static var openAppWhenRun = false
    @Parameter(title: "Word ID") var wordID: String
    init() {}
    init(wordID: String) { self.wordID = wordID }
    func perform() async throws -> some IntentResult {
        try WidgetLearningActions.perform(.remind(wordID))
        return .result()
    }
}

struct StartPracticeIntent: AppIntent {
    static var title: LocalizedStringResource = "Start German practice"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        try WidgetLearningActions.perform(.practice(nil))
        return .result()
    }
}

struct RevealPracticeIntent: AppIntent {
    static var title: LocalizedStringResource = "Reveal German answer"
    static var openAppWhenRun = false
    @Parameter(title: "Question ID") var questionID: String
    init() {}
    init(_ token: UUID) { questionID = token.uuidString }
    func perform() async throws -> some IntentResult {
        if let token = UUID(uuidString: questionID) { try WidgetLearningActions.perform(.reveal(token)) }
        return .result()
    }
}

struct GradePracticeIntent: AppIntent {
    static var title: LocalizedStringResource = "Grade German recall"
    static var openAppWhenRun = false
    @Parameter(title: "Question ID") var questionID: String
    @Parameter(title: "Grade") var gradeName: String
    init() {}
    init(_ token: UUID, _ grade: RecallGrade) { questionID = token.uuidString; gradeName = grade.rawValue }
    func perform() async throws -> some IntentResult {
        if let token = UUID(uuidString: questionID), let grade = RecallGrade(rawValue: gradeName) {
            try WidgetLearningActions.perform(.grade(token, grade))
        }
        return .result()
    }
}

struct BrowseWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Return widget to discovery"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        try WidgetLearningActions.perform(.widgetPractice(false))
        return .result()
    }
}
