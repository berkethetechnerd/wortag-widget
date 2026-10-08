import Foundation
import Darwin

enum LearningAction { case next, previous, remind(String), unmark(String), translations(Bool), rotation(Bool) }

struct LearningSnapshot: Equatable {
    let card: WordCard
    let state: LearningState
    let wordCount: Int
    var activeIDs: Set<String>? = nil
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
            if rotateIfDue && state.automaticRotation && now >= state.nextAutomaticAt {
                state.next(ids: vocabulary.activeIDs, now: now)
            }
            guard let id = state.currentID, let card = vocabulary[id] else {
                throw WortagError.message("The saved card is unavailable. Restore the original vocabulary.")
            }
            return LearningSnapshot(card: card, state: state, wordCount: vocabulary.cards.count,
                                    activeIDs: vocabulary.activeIDSet)
        }
    }

    func perform(_ action: LearningAction, now: Date = Date()) throws {
        try transaction { state in
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
            case .rotation(let value):
                state.automaticRotation = value
                state.nextAutomaticAt = now.addingTimeInterval(ReviewSchedule.automaticInterval)
            }
        }
    }

    private func transaction<T>(_ body: (inout LearningState) throws -> T) throws -> T {
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
            if FileManager.default.fileExists(atPath: file.path) {
                do { state = try JSONDecoder().decode(LearningState.self, from: Data(contentsOf: file)) }
                catch { throw WortagError.message("Saved progress could not be read. It has been preserved: \(error.localizedDescription)") }
                try state.validate()
            } else { state = LearningState() }
            let old = state
            let result = try body(&state)
            if state != old { try JSONEncoder().encode(state).write(to: file, options: .atomic) }
            return result
        }
    }
}
