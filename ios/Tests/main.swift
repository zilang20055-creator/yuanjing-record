import Foundation
var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fatalError("FAIL: " + message) }
}
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
func date(_ s: String) -> Date { ISO8601DateFormatter().date(from: s + "T12:00:00Z")! }
expect(Ledger.cents("0.01") == 1, "exact cents")
expect(Ledger.cents("123.4") == 12340, "one decimal")
expect(Ledger.cents("-12.34") == -1234, "negative calibration")
for bad in ["1.001", "NaN", "1e9", "", "9999999999999999999999", "1,000", "--1"] { expect(Ledger.cents(bad) == nil, "reject " + bad) }
expect(calendar.component(.day, from: Ledger.cycleStart(date("2026-09-09"), payday: 10, calendar: calendar)) == 10, "previous cycle day")
expect(calendar.component(.month, from: Ledger.cycleStart(date("2026-09-09"), payday: 10, calendar: calendar)) == 8, "previous cycle month")
expect(calendar.component(.day, from: Ledger.cycleStart(date("2026-02-28"), payday: 31, calendar: calendar)) == 28, "short month clamp")
var state = Snapshot()
let a = state.accounts[0].id, b = state.accounts[1].id
state.accounts[0].balance = 100000
let purchase = Entry(date: date("2026-09-10"), kind: "支出", amount: 30000, account: a, category: "食物", tag: "寿司郎")
try Ledger.apply(purchase, to: &state)
expect(state.accounts[0].balance == 70000, "expense decreases account")
try Ledger.apply(Entry(kind: "转账", amount: 10000, account: a, destination: b, category: "转账"), to: &state)
expect(state.accounts.reduce(0) { $0 + $1.balance } == 70000, "own transfer preserves total")
try Ledger.apply(Entry(kind: "分摊回款", amount: 15000, account: b, category: "食物", parent: purchase.id), to: &state)
expect(state.accounts[1].balance == 25000, "repayment to selected account")
try Ledger.apply(Entry(kind: "退款", amount: 5000, account: a, category: "食物", parent: purchase.id), to: &state)
let before = state.accounts
var rejected = false
do { try Ledger.apply(Entry(kind: "退款", amount: 11000, account: a, category: "食物", parent: purchase.id), to: &state) } catch { rejected = true }
expect(rejected && state.accounts == before, "over-refund rejected without mutation")
rejected = false
do { try Ledger.apply(Entry(kind: "转账", amount: 100, account: a, destination: a, category: "转账"), to: &state) } catch { rejected = true }
expect(rejected && state.accounts == before, "same-account transfer rejected atomically")
let debt = state.accounts[3].id
try Ledger.apply(Entry(kind: "支出", amount: 9900, account: debt, category: "购物"), to: &state)
expect(state.accounts[3].balance == -9900, "credit purchase creates debt")
let encoded = try JSONEncoder().encode(state)
let decoded = try JSONDecoder().decode(Snapshot.self, from: encoded)
expect(decoded.accounts == state.accounts && decoded.entries.count == state.entries.count, "local persistence roundtrip")
let oldStart = date("2026-09-10").addingTimeInterval(-43200)
let oldEnd = date("2026-09-16").addingTimeInterval(-43200)
let oldSpend = Ledger.spend(state.entries, from: oldStart, until: oldEnd)
state.accounts[0].balance = 500000
expect(Ledger.spend(state.entries, from: oldStart, until: oldEnd) == oldSpend, "calibration leaves spending alone")
var history = [Entry]()
for month in [6,7,8] { history.append(Entry(date: date("2026-0\(month)-10"), kind: "支出", amount: 10000, account: a, category: "食物")); history.append(Entry(date: date("2026-0\(month)-16"), kind: "支出", amount: 99999, account: a, category: "食物")) }
history.append(Entry(date: date("2026-09-10"), kind: "支出", amount: 7500, account: a, category: "食物"))
expect(Ledger.comparison(history, now: date("2026-09-15"), payday: 10, calendar: calendar) == "比前三个月同期平均少 25.0%", "same elapsed days and three-cycle mean")
expect(Ledger.comparison([], now: date("2026-09-15"), payday: 10, calendar: calendar) == "暂无可比较的同期记录", "zero baseline")
state.runningSince = date("2026-09-15")
let restored = try JSONDecoder().decode(Snapshot.self, from: JSONEncoder().encode(state))
expect(restored.runningSince == state.runningSince, "timer survives serialization")
expect(Ledger.comparison(history, now: date("2026-09-15"), payday: 10, calendar: calendar, coverageStart: date("2026-08-01")) == "积累满三个历史周期后显示对比", "incomplete history is not treated as zero spending")
let balancesBeforePending = state.accounts
state.entries[0].expectedShare = 15000
expect(state.accounts == balancesBeforePending, "pending share never increases assets")
print("PASS: \(checks) domain checks")
let header = "日期\t分类\t类型\t金额\t账户\t账本\t备注\n"
let sample = header + "2026-09-14 13:50\t食物‐寿司\t支出\t12.34\t微信钱包\t日常\t\"寿司,郎\n双份\"\n"
expect(Migration.importCents("¥1,234.50") == 123450, "export currency symbol and grouping")
expect(Migration.importCents("¥1,23") == nil, "invalid currency grouping rejected")
let utf16 = Data([0xff, 0xfe]) + sample.data(using: .utf16LittleEndian)!
let imported = try Migration.parse(utf16)
expect(imported.rows.count == 1 && imported.expense == 1234, "UTF16 TSV imported exactly")
expect(imported.rows[0].note == "寿司,郎\n双份" && imported.rows[0].tag == "寿司", "quotes multiline note and subcategory preserved")
var migrationState = Snapshot()
migrationState.accounts[0].balance = 123456
let originalBalance = migrationState.accounts.reduce(0) { $0 + $1.balance }
try Migration.apply(imported, mapping: ["微信钱包": migrationState.accounts[1].id], completeHistory: true, to: &migrationState)
expect(migrationState.accounts.reduce(0) { $0 + $1.balance } == originalBalance, "historical import does not debit current balance")
expect(migrationState.entries[0].sourceFields == imported.rows[0].fields, "all original fields retained")
let repeated = try Migration.parse(utf16, existing: Set(migrationState.entries.compactMap(\.sourceKey)))
expect(repeated.rows.isEmpty && repeated.duplicateCount == 1, "repeat import skipped")
try Migration.apply(imported, mapping: ["微信钱包": migrationState.accounts[1].id], completeHistory: false, to: &migrationState)
expect(migrationState.entries.count == 1, "stale preview cannot double import")
let identical = header + String(repeating: "2026-09-14 13:50\t食物\t支出\t1\t微信\t日常\t相同\n", count: 2)
let escaped = try Migration.fields("a,\"b\"\"c\"\n", delimiter: ",")
expect(escaped == [["a", "b\"c"]], "escaped quotes")
let twins = try Migration.parse(Data(identical.utf8))
expect(twins.rows.count == 2 && twins.rows[0].id != twins.rows[1].id, "legitimate identical source rows retained")
for bad in [header + "bad", header + "2026-02-30 12:00\t食物\t支出\t1\t微信\t日常\t无\n", header + "2026-09-14 13:50\t食物\t支出\t1.001\t微信\t日常\t无\n"] {
    var failed = false
    do { _ = try Migration.parse(Data(bad.utf8)) } catch { failed = true }
    expect(failed, "malformed import rejected in full")
}
let backupRoundtrip = try Backup.decode(JSONEncoder().encode(migrationState))
expect(backupRoundtrip.entries[0].sourceKey == migrationState.entries[0].sourceKey, "dedup metadata survives backup restore")
var corrupt = migrationState
corrupt.accounts.append(corrupt.accounts[0])
var backupRejected = false
do { _ = try Backup.decode(JSONEncoder().encode(corrupt)) } catch { backupRejected = true }
expect(backupRejected, "duplicate account identifiers rejected on restore")
print("PASS: \(checks) total domain and migration checks")
if CommandLine.arguments.count > 1 {
    let real = try Migration.parse(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    var local = Snapshot()
    try Migration.apply(real, mapping: [:], completeHistory: true, to: &local)
    let restored = try Backup.decode(JSONEncoder().encode(local))
    let duplicate = try Migration.parse(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])), existing: Set(restored.entries.compactMap(\.sourceKey)))
    guard real.rows.count == restored.entries.count, duplicate.rows.isEmpty else { fatalError("real data reconciliation failed") }
    print("REAL CSV: rows=\(real.rows.count), expenseCents=\(real.expense), incomeCents=\(real.income), restored=\(restored.entries.count), repeatedSkipped=\(duplicate.duplicateCount), balance=\(restored.accounts.reduce(0) { $0 + $1.balance })")
}
var notificationState = Snapshot()
notificationState.remindersEnabled = true
notificationState.remindersEnabledAt = date("2026-09-12")
notificationState.runningSince = date("2026-09-15")
let plans = ReminderPlan.plans(notificationState, now: date("2026-09-15"), calendar: calendar)
expect(plans.count == 2, "unfinished and three-day reminder generated")
expect(calendar.component(.hour, from: plans.first { $0.id == "yuanjing.unfinished" }!.date) == 22, "unfinished reminder at configured evening hour")
let nextPlans = ReminderPlan.plans(notificationState, now: date("2026-09-17"), calendar: calendar)
expect(plans.map(\.signature) == nextPlans.map(\.signature), "overdue anchors stable across later app launches")
notificationState.runningSince = nil
expect(ReminderPlan.plans(notificationState, calendar: calendar).count == 1, "finishing cancels unfinished reminder")
notificationState.remindersEnabled = false
expect(ReminderPlan.plans(notificationState, calendar: calendar).isEmpty, "disabled reminders schedule nothing")
print("PASS: \(checks) including reminder policy checks")
var correctionState = Snapshot()
let correctionAccount = correctionState.accounts[0].id
try Ledger.apply(Entry(kind: "支出", amount: 1000, account: correctionAccount, category: "食物"), to: &correctionState)
var corrected = correctionState.entries[0]; corrected.amount = 700
try Ledger.replace(corrected, in: &correctionState)
expect(correctionState.accounts[0].balance == -700, "expense correction adjusts balance by difference")
correctionState.calibrations.append(Calibration(account: correctionAccount, before: -700, after: 5000))
correctionState.accounts[0].balance = 5000
corrected.amount = 600
try Ledger.replace(corrected, in: &correctionState)
expect(correctionState.accounts[0].balance == 5000, "correction before calibration preserves calibrated balance")
var importedCorrection = migrationState.entries[0]; importedCorrection.amount = 500
let importedBalances = migrationState.accounts
try Ledger.replace(importedCorrection, in: &migrationState)
expect(migrationState.accounts == importedBalances, "historical correction does not replay balance effects")
print("PASS: \(checks) including correction checks")

var deletionState = Snapshot()
let deletionDebit = deletionState.accounts[0].id, deletionCredit = deletionState.accounts[1].id
let deletionPurchase = Entry(kind: "支出", amount: 30000, account: deletionDebit, category: "食物")
try Ledger.apply(deletionPurchase, to: &deletionState)
let deletionRefund = Entry(kind: "退款", amount: 5000, account: deletionCredit, category: "食物", parent: deletionPurchase.id)
try Ledger.apply(deletionRefund, to: &deletionState)
try Ledger.remove(deletionRefund.id, from: &deletionState)
expect(deletionState.entries.count == 1 && deletionState.accounts[1].balance == 0 && deletionState.accounts[0].balance == -30000, "delete deletionRefund restores its account and keeps expense")
try Ledger.apply(deletionRefund, to: &deletionState)
try Ledger.apply(Entry(kind: "分摊回款", amount: 10000, account: deletionCredit, category: "食物", parent: deletionPurchase.id), to: &deletionState)
try Ledger.remove(deletionPurchase.id, from: &deletionState)
expect(deletionState.entries.isEmpty && deletionState.accounts.allSatisfy { $0.balance == 0 }, "delete original reverses expense and linked returns without dangling parents")
let deletionTransfer = Entry(kind: "转账", amount: 1500, account: deletionDebit, destination: deletionCredit, category: "转账")
try Ledger.apply(deletionTransfer, to: &deletionState)
deletionState.calibrations.append(Calibration(account: deletionDebit, before: -1500, after: 9000))
deletionState.accounts[0].balance = 9000
try Ledger.remove(deletionTransfer.id, from: &deletionState)
expect(deletionState.accounts[0].balance == 9000 && deletionState.accounts[1].balance == 0, "delete deletionTransfer respects each account calibration independently")
let importedToDelete = migrationState.entries[0].id
let balancesBeforeDelete = migrationState.accounts
try Ledger.remove(importedToDelete, from: &migrationState)
expect(migrationState.accounts == balancesBeforeDelete && migrationState.entries.isEmpty, "deleting imported record does not replay balance")
let encodedBeforeMissingDelete = try JSONEncoder().encode(deletionState)
var missingDeleteRejected = false
do { try Ledger.remove(UUID(), from: &deletionState) } catch { missingDeleteRejected = true }
expect(missingDeleteRejected && deletionState.entries.isEmpty && deletionState.accounts[0].balance == 9000, "missing delete rejected without mutation")
print("PASS: \(checks) including deletion checks")

var recurringState = Snapshot()
let recurringAccount = recurringState.accounts[0].id
let rent = RecurringRule(name: "房租", amount: 10000, account: recurringAccount, category: "住房", start: date("2026-01-31"))
recurringState.recurringRules = [rent]
expect(Recurring.pending(recurringState, now: date("2026-01-30"), calendar: calendar).isEmpty, "recurring is not due before start")
expect(recurringState.accounts[0].balance == 0 && recurringState.entries.isEmpty, "creating recurring plan never books money")
try Recurring.confirm(rent.id, occurrence: 0, in: &recurringState, now: date("2026-01-31"), calendar: calendar)
expect(recurringState.accounts[0].balance == -10000 && recurringState.entries.count == 1, "confirm recurring books one expense")
expect(calendar.isDate(recurringState.recurringRules![0].due(calendar: calendar), inSameDayAs: date("2026-02-28")), "monthly 31 clamps to February end")
var duplicateRecurringRejected = false
do { try Recurring.confirm(rent.id, occurrence: 0, in: &recurringState, now: date("2026-03-31"), calendar: calendar) } catch { duplicateRecurringRejected = true }
expect(duplicateRecurringRejected && recurringState.entries.count == 1, "stale confirmation cannot book twice")
try Recurring.skip(rent.id, occurrence: 1, in: &recurringState)
expect(calendar.isDate(recurringState.recurringRules![0].due(calendar: calendar), inSameDayAs: date("2026-03-31")) && recurringState.accounts[0].balance == -10000, "skip does not move money and cadence returns to 31")
recurringState.recurringRules![0].paused = true
expect(Recurring.pending(recurringState, now: date("2026-05-31"), calendar: calendar).isEmpty, "paused recurring is not pending")
recurringState.recurringRules![0].paused = false
expect(Recurring.pending(recurringState, now: date("2026-05-31"), calendar: calendar).count == 1, "overdue plan exposes one occurrence at a time")
try Ledger.remove(recurringState.entries[0].id, from: &recurringState)
expect(recurringState.recurringRules![0].nextIndex == 2, "deleting generated bill does not reopen completed period")
let recurringRestored = try Backup.decode(JSONEncoder().encode(recurringState))
expect(recurringRestored.recurringRules![0].nextIndex == 2, "backup preserves recurring progress")
var weeklyRule = rent; weeklyRule.frequency = "每周"; weeklyRule.nextIndex = 1
expect(calendar.isDate(weeklyRule.due(calendar: calendar), inSameDayAs: date("2026-02-07")), "weekly cadence advances seven calendar days")
var yearlyRule = rent; yearlyRule.frequency = "每年"; yearlyRule.start = date("2024-02-29"); yearlyRule.nextIndex = 1
expect(calendar.isDate(yearlyRule.due(calendar: calendar), inSameDayAs: date("2025-02-28")), "yearly leap day clamps safely")
print("PASS: \(checks) including recurring checks")
