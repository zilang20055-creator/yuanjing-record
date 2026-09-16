import SwiftUI
import UserNotifications

@MainActor final class Store: ObservableObject {
    @Published private(set) var state = Snapshot()
    @Published var error: String? = nil
    @Published var reminderStatus = ""
    private var reminderTask: Task<Void, Never>?
    private var writable = true
    private let url: URL
    init() {
        var folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Yuanjing", isDirectory: true)
        #if DEBUG
        if let flag = ProcessInfo.processInfo.arguments.firstIndex(of: "--test-store"), ProcessInfo.processInfo.arguments.count > flag + 1,
           let id = UUID(uuidString: ProcessInfo.processInfo.arguments[flag + 1]) {
            folder = folder.deletingLastPathComponent().appendingPathComponent("UITest-" + id.uuidString, isDirectory: true)
        }
        #endif
        url = folder.appendingPathComponent("records.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                state = try Backup.decode(Data(contentsOf: url))
                guard state.version == 1 else { throw ModelError.invalid("数据版本不兼容") }
            }
        } catch { writable = false; self.error = "无法读取本地记录，已停止写入以保护原文件：\(error.localizedDescription)" }
        if writable { refreshReminders() }
    }
    @discardableResult func change(_ edit: (inout Snapshot) throws -> Void) -> Bool {
        guard writable else { error = "本地记录未成功加载，请先恢复原数据文件。"; return false }
        do {
            var candidate = state
            try edit(&candidate)
            let bytes = try JSONEncoder().encode(candidate)
            try bytes.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            state = candidate
            refreshReminders()
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func setReminders(_ enabled: Bool) {
        if !enabled { change { $0.remindersEnabled = false }; return }
        Task {
            do {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                guard allowed else { reminderStatus = "通知未获允许，可前往系统设置开启。"; return }
                change { $0.remindersEnabled = true; if $0.remindersEnabledAt == nil { $0.remindersEnabledAt = Date() } }
            } catch { reminderStatus = "无法开启通知：" + error.localizedDescription }
        }
    }
    private func refreshReminders() {
        let previous = reminderTask, snapshot = state
        previous?.cancel()
        reminderTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            let result = await ReminderScheduler.synchronize(snapshot)
            if !Task.isCancelled { reminderStatus = result }
        }
    }
    func restore(_ replacement: Snapshot) -> Bool {
        do {
            try Backup.validate(replacement)
            if FileManager.default.fileExists(atPath: url.path) {
                let rescue = url.deletingLastPathComponent().appendingPathComponent("before-restore-" + UUID().uuidString + ".json")
                try Data(contentsOf: url).write(to: rescue, options: [.atomic, .completeFileProtectionUnlessOpen])
            }
            try JSONEncoder().encode(replacement).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            state = replacement; writable = true
            refreshReminders()
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func add(_ entry: Entry) -> Bool { change { try Ledger.apply(entry, to: &$0) } }
    func accountName(_ id: UUID) -> String { state.accounts.first { $0.id == id }?.name ?? "未知账户" }
    func sortedTags(_ category: String) -> [String] {
        let counts = Dictionary(grouping: state.entries.filter { $0.category == category && !$0.tag.isEmpty }, by: \.tag).mapValues(\.count)
        return (state.tags[category] ?? []).enumerated().sorted {
            let a = counts[$0.element] ?? 0, b = counts[$1.element] ?? 0
            return a == b ? $0.offset < $1.offset : a > b
        }.map(\.element)
    }
}

@MainActor enum ReminderScheduler {
    static func synchronize(_ state: Snapshot) async -> String {
        let center = UNUserNotificationCenter.current()
        let plans = ReminderPlan.plans(state)
        let ids = ["yuanjing.unfinished", "yuanjing.gap"]
        for id in ids where !plans.contains(where: { $0.id == id }) {
            center.removePendingNotificationRequests(withIdentifiers: [id])
            UserDefaults.standard.removeObject(forKey: id + ".scheduled")
        }
        guard state.remindersEnabled == true else { return "提醒已关闭" }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return "系统未允许通知，请前往系统设置开启。" }
        do {
            for plan in plans {
                // Persist the successfully scheduled anchor even after a delivered notification is dismissed.
                // Routine ledger writes must not schedule the same overdue reminder again.
                let key = plan.id + ".scheduled"
                if UserDefaults.standard.string(forKey: key) == plan.signature { continue }
                center.removePendingNotificationRequests(withIdentifiers: [plan.id])
                let content = UNMutableNotificationContent()
                content.title = plan.title; content.body = plan.body; content.sound = .default
                let date = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: plan.date)
                try await center.add(UNNotificationRequest(identifier: plan.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: false)))
                UserDefaults.standard.set(plan.signature, forKey: key)
            }
            return "提醒已开启，每次符合条件只提醒一次。"
        } catch { return "安排提醒失败：" + error.localizedDescription }
    }
}
