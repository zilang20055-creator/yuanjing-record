import Foundation

struct Account: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var balance: Int64 = 0 // Signed cents; debt is negative.
    var isDebt = false
}
struct Entry: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var kind: String
    var amount: Int64
    var account: UUID
    var destination: UUID? = nil
    var category: String
    var tag: String = ""
    var note: String = ""
    var parent: UUID? = nil
    var expectedShare: Int64 = 0
    var sourceFields: [String]? = nil
    var sourceKey: String? = nil
    var balanceAppliedAt: Date? = nil
}
struct Calibration: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var account: UUID
    var before: Int64
    var after: Int64
}
struct BowelEntry: Codable, Identifiable {
    var id = UUID()
    var start: Date
    var end: Date
    var selections: [String: String]
    var note = ""
}
let categoryArt = ["食物", "购物", "交通", "饮品", "电子消费", "模玩", "日用", "通讯", "运动", "娱乐", "游戏", "社交", "数码", "住房", "宠物", "旅行", "服饰", "理发", "其他", "医疗"]
struct Snapshot: Codable {
    var version = 1
    var trackingStartedAt = Date()
    var accounts = [Account(name: "银行卡"), Account(name: "微信"), Account(name: "支付宝"), Account(name: "信用卡", isDebt: true), Account(name: "花呗", isDebt: true)]
    var entries: [Entry] = []
    var calibrations: [Calibration] = []
    var bowels: [BowelEntry] = []
    var runningSince: Date? = nil
    var remindersEnabled: Bool? = nil
    var reminderHour: Int? = nil
    var remindersEnabledAt: Date? = nil
    var payday = 10
    var lastAccount: UUID? = nil
    var categories = ["食物", "购物", "交通", "饮品", "电子消费", "模玩", "日用", "通讯", "运动", "娱乐", "游戏", "社交", "数码", "住房", "宠物", "旅行", "服饰", "理发", "其他", "医疗"]
    var tags: [String: [String]] = [:]
    var bowelDefaults = Dictionary(uniqueKeysWithValues: bowelOptions.map { ($0.0, $0.1[0]) })
}
let bowelOptions: [(String, [String])] = [
    ("形态", ["香蕉形", "颗粒状", "团块状", "表面裂纹", "软块状", "糊状", "水样"]),
    ("颜色", ["咖啡色", "浅棕色", "深棕色", "黄色", "绿色", "黑色", "红色", "灰白色"]),
    ("分量", ["一般", "非常少", "少量", "大量"]),
    ("感觉", ["轻松", "困难", "意犹未尽"]),
    ("气味", ["轻微", "无味", "明显", "很重", "异常"]),
    ("厕纸血迹", ["没有", "有"]), ("沾马桶", ["不沾", "沾"]),
    ("腹部", ["舒适", "腹胀", "腹痛", "其他"]),
    ("心情", ["没感觉", "开心", "期待", "难过", "焦虑"]),
    ("地点", ["家", "公司", "学校", "公厕", "其他"])
]
enum Ledger {
    static func cents(_ input: String) -> Int64? {
        let s = input.trimmingCharacters(in: .whitespaces)
        guard s.range(of: "^-?[0-9]{1,10}(\\.[0-9]{1,2})?$", options: .regularExpression) != nil else { return nil }
        let negative = s.hasPrefix("-")
        let parts = s.replacingOccurrences(of: "-", with: "").split(separator: ".")
        guard let whole = Int64(parts[0]) else { return nil }
        let fraction = parts.count > 1 ? String(parts[1]) : ""
        return (whole * 100 + (Int64(fraction.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0)) * (negative ? -1 : 1)
    }
    static func money(_ value: Int64) -> String { String(format: "%.2f", Double(value) / 100) }
    static func cycleStart(_ date: Date, payday: Int, calendar: Calendar = .current) -> Date {
        let month = calendar.dateInterval(of: .month, for: date)!.start
        func start(_ m: Date) -> Date {
            let count = calendar.range(of: .day, in: .month, for: m)!.count
            return calendar.date(byAdding: .day, value: min(max(payday, 1), count) - 1, to: m)!
        }
        let candidate = start(month)
        return date >= candidate ? candidate : start(calendar.date(byAdding: .month, value: -1, to: month)!)
    }
    static func spend(_ entries: [Entry], from: Date, until: Date) -> Int64 {
        entries.filter { $0.date >= from && $0.date < until }.reduce(0) { sum, e in
            sum + (e.kind == "支出" ? e.amount : (["退款", "分摊回款"].contains(e.kind) ? -e.amount : 0))
        }
    }
    static func comparison(_ entries: [Entry], now: Date, payday: Int, calendar: Calendar = .current, coverageStart: Date? = nil) -> String {
        let start = cycleStart(now, payday: payday, calendar: calendar)
        let elapsed = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: now)).day! + 1
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let current = spend(entries, from: start, until: end)
        var history: Int64 = 0
        for offset in 1...3 {
            let month = calendar.date(byAdding: .month, value: -offset, to: calendar.dateInterval(of: .month, for: start)!.start)!
            let day = min(payday, calendar.range(of: .day, in: .month, for: month)!.count)
            let previous = calendar.date(byAdding: .day, value: day - 1, to: month)!
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: month)!
            let nextDay = min(payday, calendar.range(of: .day, in: .month, for: nextMonth)!.count)
            let next = calendar.date(byAdding: .day, value: nextDay - 1, to: nextMonth)!
            if let coverageStart, calendar.startOfDay(for: coverageStart) > previous { return "积累满三个历史周期后显示对比" }
            history += spend(entries, from: previous, until: min(next, calendar.date(byAdding: .day, value: elapsed, to: previous)!))
        }
        guard history > 0 else { return "暂无可比较的同期记录" }
        let percent = (Double(current) / (Double(history) / 3) - 1) * 100
        if abs(percent) < 0.05 { return "与前三个月同期平均持平" }
        return "比前三个月同期平均\(percent < 0 ? "少" : "多") \(String(format: "%.1f", abs(percent)))%"
    }
    static func apply(_ entry: Entry, to state: inout Snapshot) throws {
        guard entry.amount > 0, entry.amount <= 999_999_999_999,
              let source = state.accounts.firstIndex(where: { $0.id == entry.account }) else { throw ModelError.invalid("金额或账户无效") }
        if ["退款", "分摊回款"].contains(entry.kind) {
            guard let original = state.entries.first(where: { $0.id == entry.parent }), original.kind == "支出" else { throw ModelError.invalid("找不到原支出") }
            let returned = state.entries.filter { $0.parent == original.id }.reduce(Int64(0)) { $0 + $1.amount }
            guard returned + entry.amount <= original.amount else { throw ModelError.invalid("退款与分摊回款合计不能超过原支出") }
        }
        switch entry.kind {
        case "支出": state.accounts[source].balance -= entry.amount
        case "收入", "退款", "分摊回款": state.accounts[source].balance += entry.amount
        case "转账":
            guard let destination = state.accounts.firstIndex(where: { $0.id == entry.destination }), destination != source else { throw ModelError.invalid("请选择不同的转入账户") }
            state.accounts[source].balance -= entry.amount
            state.accounts[destination].balance += entry.amount
        default: throw ModelError.invalid("未知记录类型")
        }
        var saved = entry
        saved.balanceAppliedAt = Date()
        state.entries.append(saved)
        state.lastAccount = entry.account
        if !entry.tag.isEmpty, !(state.tags[entry.category] ?? []).contains(entry.tag) { state.tags[entry.category, default: []].append(entry.tag) }
    }
}
enum ModelError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

struct ReminderPlan {
    let id: String
    let signature: String
    let date: Date
    let title: String
    let body: String
    static func plans(_ state: Snapshot, now: Date = Date(), calendar: Calendar = .current) -> [ReminderPlan] {
        guard state.remindersEnabled == true else { return [] }
        var plans: [ReminderPlan] = []
        if let start = state.runningSince {
            let hour = state.reminderHour ?? 22
            var due = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: start)!
            if due <= start { due = calendar.date(byAdding: .day, value: 1, to: due)! }
            plans.append(ReminderPlan(id: "yuanjing.unfinished", signature: "\(start.timeIntervalSince1970)-\(hour)", date: max(due, now.addingTimeInterval(5)), title: "这次便便还没结束记录", body: "回来补改时间、完成记录，或者取消这次计时。"))
        }
        if let anchor = state.bowels.map(\.end).max() ?? state.remindersEnabledAt {
            let due = calendar.date(byAdding: .day, value: 3, to: anchor)!
            plans.append(ReminderPlan(id: "yuanjing.gap", signature: "\(anchor.timeIntervalSince1970)", date: max(due, now.addingTimeInterval(5)), title: "已经 3 天没有排便记录", body: "看看是否忘了记录，也留意一下自己的身体感受。"))
        }
        return plans
    }
}
