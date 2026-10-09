import SwiftUI

struct ReminderSettingsView: View {
    @EnvironmentObject private var reminders: ReminderModel
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var speech: SpeechController
    let saved: DailyReminder
    @State private var draft: DailyReminder
    @State private var confirmingReset = false
    init(saved: DailyReminder) { self.saved = saved; _draft = State(initialValue: saved) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings").font(.system(size: 34, design: .serif))
                Text("DAILY PRACTICE REMINDER").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(WortagTheme.muted)
                Text("One optional notification on each selected day. Your word repetition schedule is separate.")
                    .font(.system(size: 13)).foregroundStyle(WortagTheme.muted)
                Toggle("Enable daily reminders", isOn: $draft.enabled)
                HStack(spacing: 12) {
                    Text("Local time")
                    Picker("Hour", selection: $draft.hour) {
                        ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }.labelsHidden().pickerStyle(.menu).frame(width: 80)
                    Picker("Minute", selection: $draft.minute) {
                        ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }.labelsHidden().pickerStyle(.menu).frame(width: 80)
                }.disabled(!draft.enabled)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], alignment: .leading, spacing: 12) {
                    ForEach(orderedWeekdays, id: \.self) { day in
                        Toggle(Calendar.current.shortWeekdaySymbols[day - 1], isOn: Binding(
                            get: { draft.weekdays.contains(day) },
                            set: { if $0 { draft.weekdays.insert(day) } else { draft.weekdays.remove(day) } }))
                    }
                }.disabled(!draft.enabled)
                if draft.enabled && draft.weekdays.isEmpty {
                    Text("Select at least one weekday.").font(.caption).foregroundStyle(WortagTheme.accent)
                }
                Button("Save reminder settings") {
                    Task { await reminders.save(draft, previous: saved, persist: { model.act(.dailyReminder($0)) }) }
                }.buttonStyle(.borderedProminent).tint(WortagTheme.ink)
                    .disabled(reminders.busy || !draft.isValid)
                if let message = reminders.message { Text(message).font(.system(size: 12)).foregroundStyle(WortagTheme.muted) }
                Text("Notification access is requested only when you enable and save reminders. You can disable them here or change permission in System Settings → Notifications. Focus may silence delivery.")
                    .font(.system(size: 11)).foregroundStyle(WortagTheme.muted).lineSpacing(3)
                Divider().padding(.vertical, 6)
                Text("RESET PROGRESS").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(WortagTheme.muted)
                Text("Start fresh by clearing your learning history, statistics and all reminders. Learning settings will return to their defaults.")
                    .font(.system(size: 13)).foregroundStyle(WortagTheme.muted)
                Button("Reset progress…", role: .destructive) { confirmingReset = true }
                    .buttonStyle(.bordered)
            }.disabled(reminders.busy)
                .frame(maxWidth: 760, alignment: .leading).padding(.horizontal, 32)
                .padding(.top, 48).padding(.bottom, 28).frame(maxWidth: .infinity)
        }
        .onChange(of: saved) { _, current in draft = current }
        .alert("Reset all progress?", isPresented: $confirmingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset progress", role: .destructive) {
                Task {
                    if await reminders.resetProgress(previous: saved, persist: { model.act(.resetProgress) }) {
                        draft = DailyReminder()
                        speech.stop()
                    }
                }
            }
        } message: {
            Text("This permanently deletes explored words, browsing history, practice ratings, scheduled word reviews, daily notifications and the old progress backup. All learning settings will be reset. This cannot be undone.")
        }
    }
    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (($0 + first - 1) % 7) + 1 }
    }
}
