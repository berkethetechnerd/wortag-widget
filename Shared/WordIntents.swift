import AppIntents
import WidgetKit

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
        try LearningStore().perform(.next)
        WidgetCenter.shared.reloadTimelines(ofKind: LearningStore.widgetKind)
        return .result()
    }
}

struct PreviousWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous word"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        try LearningStore().perform(.previous)
        WidgetCenter.shared.reloadTimelines(ofKind: LearningStore.widgetKind)
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
        try LearningStore().perform(.remind(wordID))
        WidgetCenter.shared.reloadTimelines(ofKind: LearningStore.widgetKind)
        return .result()
    }
}
