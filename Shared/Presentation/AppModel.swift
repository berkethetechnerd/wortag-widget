import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: LearningSnapshot?
    @Published private(set) var error: String?
    private var repository: (any LearningRepository)?
    private let makeRepository: () throws -> any LearningRepository
    private let reloadWidgets: () -> Void

    init(makeRepository: @escaping () throws -> any LearningRepository = { try LearningStore() },
         reloadWidgets: @escaping () -> Void = {}) {
        self.makeRepository = makeRepository
        self.reloadWidgets = reloadWidgets
        refresh()
        if error == nil { reloadWidgets() }
    }

    var cards: [WordCard] { repository?.vocabulary.cards ?? [] }

    func refresh() {
        do {
            if repository == nil { repository = try makeRepository() }
            let current = try repository?.snapshot(now: Date(), rotateIfDue: false)
            if snapshot != current { snapshot = current }
            if error != nil { error = nil; reloadWidgets() }
        } catch {
            if self.error != error.localizedDescription { self.error = error.localizedDescription }
        }
    }

    func act(_ action: LearningAction) {
        do {
            if repository == nil { repository = try makeRepository() }
            try repository?.perform(action, now: Date())
            refresh()
            if error == nil { reloadWidgets() }
        } catch { self.error = error.localizedDescription }
    }

    /// Fixture repository keeps layout previews separate from live I/O.
    convenience init(previewSnapshot: LearningSnapshot, cards: [WordCard]) {
        self.init(makeRepository: { PreviewRepository(snapshot: previewSnapshot, cards: cards) })
    }
}

private final class PreviewRepository: LearningRepository {
    let vocabulary: Vocabulary
    private let fixture: LearningSnapshot
    init(snapshot: LearningSnapshot, cards: [WordCard]) {
        vocabulary = Vocabulary(cards: cards)
        fixture = snapshot
    }
    func snapshot(now: Date, rotateIfDue: Bool) throws -> LearningSnapshot { fixture }
    func perform(_ action: LearningAction, now: Date) throws {}
}
