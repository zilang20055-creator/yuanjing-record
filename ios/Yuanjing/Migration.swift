import Foundation
import CryptoKit

struct ImportedRow: Identifiable {
    let id: String
    let fields: [String]
    let date: Date
    let amount: Int64
    var kind: String { fields[2] }
    var account: String { fields[4] }
    var note: String { fields[6] }
    var category: String { fields[1].components(separatedBy: "‐").first ?? fields[1] }
    var tag: String { fields[1].components(separatedBy: "‐").dropFirst().joined(separator: "‐") }
}
struct ImportPreview {
    let rows: [ImportedRow]
    let duplicateCount: Int
    let totalCount: Int
    var accounts: [String] { Array(Set(rows.map(\.account))).sorted() }
    var earliest: Date? { rows.map(\.date).min() }
    var latest: Date? { rows.map(\.date).max() }
    var expense: Int64 { rows.filter { $0.kind == "支出" }.reduce(0) { $0 + $1.amount } }
    var income: Int64 { rows.filter { $0.kind == "收入" }.reduce(0) { $0 + $1.amount } }
}
enum Migration {
    static func parse(_ bytes: Data, existing: Set<String> = []) throws -> ImportPreview {
        guard bytes.count <= 30_000_000 else { throw ModelError.invalid("文件超过 30 MB，请分批导出") }
        let text: String?
        if bytes.starts(with: [0xff, 0xfe]) || bytes.starts(with: [0xfe, 0xff]) { text = String(data: bytes, encoding: .utf16) }
        else { text = String(data: bytes, encoding: .utf8) }
        guard let text else { throw ModelError.invalid("文件编码不支持，请使用懒猫原始导出文件") }
        let clean = text.replacingOccurrences(of: "\u{feff}", with: "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let delimiter: Character = clean.prefix(200).contains("\t") ? "\t" : ","
        let table = try fields(clean, delimiter: delimiter)
        guard table.first == ["日期", "分类", "类型", "金额", "账户", "账本", "备注"] else { throw ModelError.invalid("表头不匹配，需要日期、分类、类型、金额、账户、账本、备注") }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.isLenient = false
        var seen: [String: Int] = [:], rows: [ImportedRow] = [], duplicates = 0
        for (i, row) in table.dropFirst().enumerated() {
            guard row.count == 7, ["支出", "收入"].contains(row[2]),
                  let amount = importCents(row[3]), amount > 0,
                  let date = formatter.date(from: row[0]), formatter.string(from: date) == row[0],
                  !row[1].isEmpty, !row[4].isEmpty else { throw ModelError.invalid("第 \(i + 2) 行字段、日期或金额有误，未导入任何记录") }
            let hash = SHA256.hash(data: try JSONEncoder().encode(row)).map { String(format: "%02x", $0) }.joined()
            seen[hash, default: 0] += 1
            let key = hash + ":" + String(seen[hash]!)
            if existing.contains(key) { duplicates += 1; continue }
            rows.append(ImportedRow(id: key, fields: row, date: date, amount: amount))
        }
        return ImportPreview(rows: rows, duplicateCount: duplicates, totalCount: table.count - 1)
    }
    static func importCents(_ input: String) -> Int64? {
        guard input.range(of: "^[¥￥]?(?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?:\\.[0-9]{1,2})?$", options: .regularExpression) != nil else { return nil }
        return Ledger.cents(input.replacingOccurrences(of: "¥", with: "").replacingOccurrences(of: "￥", with: "").replacingOccurrences(of: ",", with: ""))
    }
    static func fields(_ text: String, delimiter: Character) throws -> [[String]] {
        let chars = Array(text)
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false, closed = false, i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { quoted = false; closed = true }
                } else { field.append(c) }
            } else if c == delimiter { row.append(field); field = ""; closed = false }
            else if c == "\n" { row.append(field); if row.contains(where: { !$0.isEmpty }) { rows.append(row) }; row = []; field = ""; closed = false }
            else if c == "\"" && field.isEmpty && !closed { quoted = true }
            else {
                guard !closed && c != "\"" else { throw ModelError.invalid("文件引号格式不完整") }
                field.append(c)
            }
            i += 1
        }
        guard !quoted else { throw ModelError.invalid("文件引号未闭合") }
        row.append(field); if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        return rows
    }
    static func apply(_ preview: ImportPreview, mapping: [String: UUID], completeHistory: Bool, to state: inout Snapshot) throws {
        var candidate = state
        var accounts = mapping
        let priorKeys = Set(state.entries.compactMap(\.sourceKey))
        let freshAccounts = Set(preview.rows.filter { !priorKeys.contains($0.id) }.map(\.account))
        for name in freshAccounts where accounts[name] == nil {
            let new = Account(name: name, isDebt: ["信用卡", "花呗"].contains(name))
            candidate.accounts.append(new); accounts[name] = new.id
        }
        let valid = Set(candidate.accounts.map(\.id))
        guard accounts.values.allSatisfy({ valid.contains($0) }) else { throw ModelError.invalid("账户对应已变化，请重新预览") }
        var keys = Set(candidate.entries.compactMap(\.sourceKey))
        for row in preview.rows where !keys.contains(row.id) {
            guard let account = accounts[row.account] else { throw ModelError.invalid("缺少账户对应") }
            candidate.entries.append(Entry(date: row.date, kind: row.kind, amount: row.amount, account: account, category: row.category, tag: row.tag, note: row.note, sourceFields: row.fields, sourceKey: row.id))
            if !candidate.categories.contains(row.category) { candidate.categories.append(row.category) }
            if !row.tag.isEmpty, !(candidate.tags[row.category] ?? []).contains(row.tag) { candidate.tags[row.category, default: []].append(row.tag) }
            keys.insert(row.id)
        }
        if completeHistory, let first = preview.earliest { candidate.trackingStartedAt = min(candidate.trackingStartedAt, first) }
        // Historical records are deliberately not replayed against current account balances.
        try Backup.validate(candidate)
        state = candidate
    }
}
enum Backup {
    static func decode(_ data: Data) throws -> Snapshot {
        guard data.count <= 50_000_000 else { throw ModelError.invalid("备份超过 50 MB") }
        let state = try JSONDecoder().decode(Snapshot.self, from: data)
        try validate(state)
        return state
    }
    static func validate(_ state: Snapshot) throws {
        func require(_ condition: Bool, _ message: String) throws { if !condition { throw ModelError.invalid("备份校验失败：" + message) } }
        try require(state.version == 1, "不支持的数据版本")
        try require((1...31).contains(state.payday), "发薪日期无效")
        try require((0...23).contains(state.reminderHour ?? 22), "提醒时间无效")
        let dates = [state.trackingStartedAt] + state.entries.map(\.date) + state.bowels.flatMap { [$0.start, $0.end] } + state.calibrations.map(\.date) + [state.runningSince, state.remindersEnabledAt].compactMap { $0 }
        try require(dates.allSatisfy { $0.timeIntervalSince1970 >= -2208988800 && $0.timeIntervalSince1970 < 4133980800 }, "日期超出支持范围")
        try require(!state.accounts.isEmpty && state.accounts.count <= 1000 && state.entries.count <= 100000, "账户或账单数量异常")
        let accounts = Set(state.accounts.map(\.id)), entryIDs = Set(state.entries.map(\.id))
        try require(accounts.count == state.accounts.count && entryIDs.count == state.entries.count, "存在重复编号")
        try require(Set(state.bowels.map(\.id)).count == state.bowels.count, "存在重复排便编号")
        try require(Set(state.categories).count == state.categories.count, "存在重复大类")
        try require(state.tags.values.allSatisfy { Set($0).count == $0.count }, "存在重复标签")
        for account in state.accounts { try require(!account.name.isEmpty && account.balance > -1_000_000_000_000_000 && account.balance < 1_000_000_000_000_000, "账户余额无效") }
        let byID = Dictionary(uniqueKeysWithValues: state.entries.map { ($0.id, $0) })
        var returned: [UUID: Int64] = [:]
        for entry in state.entries {
            try require(accounts.contains(entry.account) && entry.amount > 0 && entry.amount <= 999_999_999_999 && entry.expectedShare >= 0 && entry.expectedShare <= entry.amount, "账单账户或金额无效")
            try require(["支出", "收入", "转账", "退款", "分摊回款"].contains(entry.kind), "记录类型无效")
            if entry.kind == "转账" { try require(entry.destination != entry.account && entry.destination.map { accounts.contains($0) } == true, "转入账户无效") }
            if ["退款", "分摊回款"].contains(entry.kind) {
                guard let parent = entry.parent, let source = byID[parent], source.kind == "支出" else { throw ModelError.invalid("备份中的回款缺少原账单") }
                returned[parent, default: 0] += entry.amount
                try require(returned[parent]! <= source.amount, "回款超过原支出")
            } else { try require(entry.parent == nil, "普通账单不应关联原支出") }
        }
        for item in state.bowels { try require(item.end >= item.start, "排便结束早于开始") }
        for item in state.calibrations { try require(accounts.contains(item.account), "校准对应账户不存在") }
    }
}

extension Ledger {
    static func replace(_ replacement: Entry, in state: inout Snapshot) throws {
        guard let index = state.entries.firstIndex(where: { $0.id == replacement.id }) else { throw ModelError.invalid("原记录不存在") }
        let old = state.entries[index]
        guard old.kind == replacement.kind && old.parent == replacement.parent else { throw ModelError.invalid("编辑不能改变记录类型或回款关联") }
        var candidate = state
        var edited = replacement
        edited.sourceFields = old.sourceFields; edited.sourceKey = old.sourceKey; edited.balanceAppliedAt = old.balanceAppliedAt
        candidate.entries[index] = edited
        if old.kind == "支出" {
            for i in candidate.entries.indices where candidate.entries[i].parent == old.id {
                candidate.entries[i].category = edited.category; candidate.entries[i].tag = edited.tag
            }
        }
        try Backup.validate(candidate)
        func changes(_ entry: Entry) -> [UUID: Int64] {
            if entry.kind == "转账", let destination = entry.destination { return [entry.account: -entry.amount, destination: entry.amount] }
            return [entry.account: entry.kind == "支出" ? -entry.amount : entry.amount]
        }
        if old.sourceFields == nil {
            let before = changes(old), after = changes(edited), applied = old.balanceAppliedAt ?? old.date
            for i in candidate.accounts.indices {
                let id = candidate.accounts[i].id
                let calibrated = candidate.calibrations.filter { $0.account == id }.map(\.date).max()
                // A later real-world balance calibration supersedes earlier bookkeeping effects.
                if let calibrated, calibrated >= applied { continue }
                candidate.accounts[i].balance += (after[id] ?? 0) - (before[id] ?? 0)
            }
        }
        if !candidate.categories.contains(edited.category) { candidate.categories.append(edited.category) }
        if !edited.tag.isEmpty, !(candidate.tags[edited.category] ?? []).contains(edited.tag) { candidate.tags[edited.category, default: []].append(edited.tag) }
        try Backup.validate(candidate)
        state = candidate
    }
}


extension Ledger {
    /// Delete a record and its linked returns atomically; later balance calibrations take precedence.
    static func remove(_ id: UUID, from state: inout Snapshot) throws {
        guard state.entries.contains(where: { $0.id == id }) else { throw ModelError.invalid("记录不存在") }
        var candidate = state
        let removed = candidate.entries.filter { $0.id == id || $0.parent == id }
        for entry in removed where entry.sourceFields == nil {
            var effects = [entry.account: entry.kind == "支出" || entry.kind == "转账" ? -entry.amount : entry.amount]
            if entry.kind == "转账", let destination = entry.destination { effects[destination, default: 0] += entry.amount }
            for index in candidate.accounts.indices {
                let account = candidate.accounts[index].id
                let calibrated = candidate.calibrations.filter { $0.account == account }.map(\.date).max()
                if let calibrated, calibrated >= (entry.balanceAppliedAt ?? entry.date) { continue }
                candidate.accounts[index].balance -= effects[account] ?? 0
            }
        }
        candidate.entries.removeAll { $0.id == id || $0.parent == id }
        try Backup.validate(candidate)
        state = candidate
    }
}
