import Foundation
import Darwin

enum LearningAction { case next, previous, remind(String), unmark(String), translations(Bool), rotation(Bool)
    case practice(String?), reveal(UUID), grade(UUID, RecallGrade), widgetPractice(Bool)
    case dailyGoal(Int), dailyReminder(DailyReminder), resetProgress }

struct LearningSnapshot: Equatable {
    let card: WordCard
    let state: LearningState
    let wordCount: Int
    var activeIDs: Set<String>? = nil
    var practiceCard: WordCard? = nil
    var canGoBack: Bool { state.canGoBack(ids: activeIDs) }
    var seenCount: Int { activeIDs.map { state.seen.intersection($0).count } ?? state.seen.count }
    var reviewCount: Int { activeIDs.map { Set(state.reviews.keys).intersection($0).count } ?? state.reviews.count }
}

/// App presentation depends on behavior rather than a concrete file store.
protocol LearningRepository {
    var vocabulary: Vocabulary { get }
    func snapshot(now: Date, rotateIfDue: Bool) throws -> LearningSnapshot
    func perform(_ action: LearningAction, now: Date) throws
}

/// Every read and mutation takes a process-wide file lock, then reloads the file.
/// This prevents lost updates when an AppIntent and the app run simultaneously.
final class LearningStore: LearningRepository {
    static let widgetKind = "WortagWidget"
    let vocabulary: Vocabulary
    private let directory: URL
    private let queue = DispatchQueue(label: "de.wortag.store")

    init(vocabulary: Vocabulary, directory: URL) {
        self.vocabulary = vocabulary
        self.directory = directory
    }

    convenience init() throws {
        // A local-only build has no provisioned App Group. Both sandboxed targets
        // receive access to this one folder through a home-relative entitlement.
        // Resolve the login home rather than the process's sandbox-container home.
        guard let account = getpwuid(getuid()), let home = account.pointee.pw_dir else {
            throw WortagError.message("Wortag could not locate your local learning folder.")
        }
        let directory = URL(fileURLWithPath: String(cString: home), isDirectory: true)
            .appendingPathComponent("Library/Application Support/Wortag", isDirectory: true)
        self.init(vocabulary: try Vocabulary(), directory: directory)
    }

    func snapshot(now: Date = Date(), rotateIfDue: Bool = false) throws -> LearningSnapshot {
        try transaction { state in
            state.start(ids: vocabulary.activeIDs, now: now)
            if rotateIfDue && state.automaticRotation && state.practiceInWidget != true && now >= state.nextAutomaticAt {
                state.next(ids: vocabulary.activeIDs, now: now)
            }
            if let challenge = state.practice, !vocabulary.activeIDSet.contains(challenge.cardID) { state.practice = nil }
            if state.practiceInWidget == true && state.practice == nil {
                state.startPractice(ids: vocabulary.activeIDs, now: now)
            }
            guard let id = state.currentID, let card = vocabulary[id] else {
                throw WortagError.message("The saved card is unavailable. Restore the original vocabulary.")
            }
            return LearningSnapshot(card: card, state: state, wordCount: vocabulary.cards.count,
                                    activeIDs: vocabulary.activeIDSet, practiceCard: state.practice.flatMap { vocabulary[$0.cardID] })
        }
    }

    func perform(_ action: LearningAction, now: Date = Date()) throws {
        let resetting: Bool
        if case .resetProgress = action { resetting = true } else { resetting = false }
        try transaction(resetting: resetting) { state in
            let ids = vocabulary.activeIDs
            let initialized = state.start(ids: ids, now: now)
            switch action {
            case .next: if !initialized { state.next(ids: ids, now: now) }
            case .previous: state.previous(now: now, ids: vocabulary.activeIDSet)
            case .remind(let id):
                guard vocabulary.activeIDSet.contains(id) else { return }
                state.remind(id: id, now: now)
            case .unmark(let id): state.reviews.removeValue(forKey: id)
            case .translations(let value): state.showTranslations = value
            case .practice(let id): state.startPractice(ids: ids, now: now, cardID: id)
            case .reveal(let token): state.revealPractice(token)
            case .grade(let token, let grade): state.gradePractice(token, grade: grade, ids: ids, now: now)
            case .widgetPractice(let value):
                state.practiceInWidget = value
                if value { state.startPractice(ids: ids, now: now) }
                else { state.nextAutomaticAt = now.addingTimeInterval(ReviewSchedule.automaticInterval) }
            case .dailyGoal(let goal): state.dailyGoal = min(100, max(1, goal))
            case .dailyReminder(let preference):
                guard preference.isValid else { throw WortagError.message("Choose a valid reminder time and at least one weekday.") }
                state.dailyReminder = preference
            case .resetProgress:
                // Keep the fresh starting card visible without counting it as
                // explored. All previous history and preferences were discarded
                // under the same lock before initialization.
                state.seen.removeAll()
                state.advances = 0
            case .rotation(let value):
                state.automaticRotation = value
                state.nextAutomaticAt = now.addingTimeInterval(ReviewSchedule.automaticInterval)
            }
        }
    }

    private func transaction<T>(resetting: Bool = false, _ body: (inout LearningState) throws -> T) throws -> T {
        try queue.sync {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            let descriptor = open(directory.appendingPathComponent("learning.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
            guard descriptor >= 0 else { throw WortagError.message("Could not open the learning-state lock.") }
            defer { close(descriptor) }
            guard flock(descriptor, LOCK_EX) == 0 else { throw WortagError.message("Could not lock learning progress.") }
            defer { flock(descriptor, LOCK_UN) }
            let file = directory.appendingPathComponent("learning.json")
            var state: LearningState
            if !resetting && FileManager.default.fileExists(atPath: file.path) {
                do { state = try JSONDecoder().decode(LearningState.self, from: Data(contentsOf: file)) }
                catch { throw WortagError.message("Saved progress could not be read. It has been preserved: \(error.localizedDescription)") }
                try state.validate()
            } else { state = LearningState() }
            let old = state
            if state.version == 1 {
                let backup = directory.appendingPathComponent("learning-v1-backup.json")
                if !FileManager.default.fileExists(atPath: backup.path) {
                    try Data(contentsOf: file).write(to: backup, options: .atomic)
                }
                state.version = 2
            }
            let result = try body(&state)
            try state.validate()
            if resetting || state != old {
                let bytes = try JSONEncoder().encode(state)
                let backup = directory.appendingPathComponent("learning-v1-backup.json")
                let backupBytes = resetting && FileManager.default.fileExists(atPath: backup.path)
                    ? try Data(contentsOf: backup) : nil
                if backupBytes != nil { try FileManager.default.removeItem(at: backup) }
                do { try bytes.write(to: file, options: .atomic) }
                catch {
                    // A failed replacement must not also discard the user's
                    // migration backup. Retain the original write error.
                    if let backupBytes { try? backupBytes.write(to: backup, options: .atomic) }
                    throw error
                }
            }
            return result
        }
    }
}
