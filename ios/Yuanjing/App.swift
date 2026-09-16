import SwiftUI
import UniformTypeIdentifiers

let ink = Color(red: 0.20, green: 0.16, blue: 0.12)
let cream = Color(red: 1, green: 0.98, blue: 0.94)
let honey = Color(red: 0.96, green: 0.78, blue: 0.41)
struct DoodleCard: ViewModifier {
    var fill: Color = .white
    func body(content: Content) -> some View {
        content.padding(16).background(fill, in: RoundedRectangle(cornerRadius: 23))
            .overlay(RoundedRectangle(cornerRadius: 23).stroke(ink, lineWidth: 2.5))
    }
}
extension View { func card(_ fill: Color = .white) -> some View { modifier(DoodleCard(fill: fill)) } }
enum Atlas {
    static let tiles: [UIImage] = {
        guard let url = Bundle.main.url(forResource: "honey-atlas", withExtension: "jpg"), let image = UIImage(contentsOfFile: url.path)?.cgImage else { return Array(repeating: UIImage(), count: 25) }
        let side = CGFloat(image.width) / 5
        return (0..<25).map { index in
            let x = index < 20 ? CGFloat(index % 5) * 0.25 : [0.0, 0.25, 0.488, 0.738, 0.995][index - 20]
            let y = index < 20 ? CGFloat(index / 5) * 0.25 : 0.97
            let rect = CGRect(x: side * 4 * x, y: side * 4 * y, width: side, height: side).integral
            return image.cropping(to: rect).map { UIImage(cgImage: $0) } ?? UIImage()
        }
    }()
}
struct CatIcon: View {
    let index: Int
    var size: CGFloat = 42
    var body: some View {
        Image(uiImage: Atlas.tiles[min(max(index, 0), 24)]).resizable()
            .frame(width: size, height: size).blendMode(.multiply).accessibilityHidden(true)
    }
}
@main struct YuanjingApp: App {
    @StateObject private var store = Store()
    var body: some Scene { WindowGroup { RootView().environmentObject(store).tint(ink).preferredColorScheme(.light) } }
}
struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0
    @State private var newEntry = false
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeView(newEntry: $newEntry) }.tabItem { Label("记账", systemImage: "creditcard") }.tag(0)
            NavigationStack { BowelHome() }.tabItem { Label("便便", systemImage: "calendar") }.tag(1)
            NavigationStack {
                VStack(spacing: 22) { CatIcon(index: 22, size: 150); Text("睡个好觉").font(.title.bold()); Text("睡眠记录稍后见").foregroundStyle(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity).background(cream)
            }.tabItem { Label("睡眠", systemImage: "moon") }.tag(2)
        }
        .sheet(isPresented: $newEntry) { NavigationStack { EntryForm() } }
        .alert("记录提示", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("知道了") { store.error = nil } } message: { Text(store.error ?? "") }
        .onOpenURL { url in
            if url.host == "expense" { tab = 0; newEntry = true }
            if url.host == "bowel" {
                tab = 1
                if store.state.runningSince == nil { store.change { $0.runningSince = Date() } }
            }
        }
    }
}
struct HomeView: View {
    @EnvironmentObject var store: Store
    @Binding var newEntry: Bool
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HStack { Text("圆景记录").font(.largeTitle.bold()); Spacer(); NavigationLink { SettingsView() } label: { Image(systemName: "gearshape").font(.title2) }.accessibilityLabel("设置") }
                NavigationLink { AccountsView() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) { Text("剩余总金额").font(.subheadline); Text("¥ " + Ledger.money(store.state.accounts.reduce(0) { $0 + $1.balance })).font(.system(size: 32, weight: .bold, design: .rounded)); Text("账户与余额  ›").font(.caption) }
                        Spacer(minLength: 0); CatIcon(index: 23, size: 90)
                    }.card(honey.opacity(0.4))
                }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 8) {
                    let start = Ledger.cycleStart(Date(), payday: store.state.payday)
                    Text("本月花费 · \(start.formatted(.dateTime.month().day())) 起").font(.subheadline)
                    Text("¥ " + Ledger.money(Ledger.spend(store.state.entries, from: start, until: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!))).font(.title.bold())
                    Text(Ledger.comparison(store.state.entries, now: Date(), payday: store.state.payday, coverageStart: store.state.trackingStartedAt)).font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).card()
                Button { newEntry = true } label: { HStack { Image(systemName: "plus"); Text("记一笔").bold() }.frame(maxWidth: .infinity).card(honey) }.buttonStyle(.plain).accessibilityIdentifier("new-entry")
                HStack { Text("最近记录").font(.title3.bold()); Spacer(); NavigationLink("分类统计") { StatisticsView() }.font(.subheadline) }
                if store.state.entries.isEmpty { Text("先在「账户与余额」填好各项余额，\n再记下今天的第一笔吧。").foregroundStyle(.secondary).padding(.vertical, 24) }
                ForEach(store.state.entries.sorted { $0.date > $1.date }) { entry in
                    NavigationLink { EntryDetail(entry: entry) } label: { EntryRow(entry: entry) }.buttonStyle(.plain)
                }
            }.padding(20)
        }.background(cream).toolbar(.hidden, for: .navigationBar).foregroundStyle(ink)
    }
}
struct EntryRow: View {
    @EnvironmentObject var store: Store
    let entry: Entry
    var body: some View {
        HStack(spacing: 12) {
            CatIcon(index: categoryArt.firstIndex(of: entry.category) ?? 20, size: 38)
            VStack(alignment: .leading, spacing: 4) { Text(entry.tag.isEmpty ? entry.category : entry.tag).bold(); Text("\(entry.date.formatted(.dateTime.month().day())) · \(store.accountName(entry.account)) · \(entry.kind)").font(.caption).foregroundStyle(.secondary) }
            Spacer(); Text((entry.kind == "支出" ? "−" : entry.kind == "转账" ? "" : "+") + Ledger.money(entry.amount)).monospacedDigit()
        }.padding(.vertical, 8)
    }
}
struct EntryForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    var parent: Entry? = nil
    @State var kind = "支出"
    @State private var category = "食物"
    @State private var tag = ""
    @State private var amount = ""
    @State private var account: UUID? = nil
    @State private var destination: UUID? = nil
    @State private var date = Date()
    @State private var note = ""
    @State private var tagsShown = false
    @State private var newTag = ""
    @State private var tagsSnapshot: [String] = []
    @State private var operand: Int64? = nil
    @State private var operation: String? = nil
    var body: some View {
        VStack(spacing: 10) {
            if parent == nil { Picker("类型", selection: $kind) { ForEach(["支出", "收入", "转账"], id: \.self) { Text($0) } }.pickerStyle(.segmented) }
            if kind != "转账" && parent == nil {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 5), spacing: 10) {
                        ForEach(Array(store.state.categories.enumerated()), id: \.element) { index, item in
                            Button {
                                category = item; tag = ""; tagsSnapshot = store.sortedTags(item); tagsShown = true
                            } label: {
                                VStack(spacing: 3) { CatIcon(index: categoryArt.firstIndex(of: item) ?? 18, size: 38); Text(item).font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7) }
                                    .frame(maxWidth: .infinity).padding(.vertical, 7).background(category == item ? honey.opacity(0.55) : .clear, in: RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain).accessibilityIdentifier("category-" + item)
                        }
                    }
                }.frame(maxHeight: .infinity)
            } else { Spacer(minLength: 0) }
            HStack {
                Picker("账户", selection: $account) { ForEach(store.state.accounts) { Text($0.name).tag(Optional($0.id)) } }.labelsHidden()
                if kind == "转账" { Image(systemName: "arrow.right"); Picker("转入", selection: $destination) { Text("转入账户").tag(nil as UUID?); ForEach(store.state.accounts) { Text($0.name).tag(Optional($0.id)) } }.labelsHidden() }
                Spacer(minLength: 0)
                DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute]).labelsHidden().scaleEffect(0.85, anchor: .trailing)
            }.font(.caption)
            TextField("备注（可选）", text: $note).textFieldStyle(.roundedBorder)
            HStack {
                Button { tagsSnapshot = store.sortedTags(category); tagsShown = true } label: { Text(tag.isEmpty ? category + " · 标签" : category + " · " + tag).font(.subheadline) }.disabled(kind == "转账" || parent != nil)
                Spacer(); Text("¥ " + (amount.isEmpty ? "0" : amount)).font(.system(size: 29, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.5)
            }.card(honey.opacity(0.22))
            if let operand, let operation { Text("\(Ledger.money(operand)) \(operation)").font(.caption).frame(maxWidth: .infinity, alignment: .trailing) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(["7", "8", "9", "⌫", "4", "5", "6", "+", "1", "2", "3", "−", ".", "0", "=", "完成"], id: \.self) { key in
                    Button { press(key) } label: { Text(key).font(.system(size: key == "完成" ? 19 : 26, weight: .semibold, design: .rounded)).frame(maxWidth: .infinity).frame(height: 47).background(key == "完成" ? honey : .white, in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(ink, lineWidth: 2)) }.buttonStyle(.plain).accessibilityIdentifier("key-" + key)
                }
            }
        }.padding(16).background(cream).foregroundStyle(ink).navigationTitle(parent == nil ? "记一笔" : kind).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .onAppear { account = store.state.lastAccount ?? store.state.accounts.first?.id; if let parent { category = parent.category; tag = parent.tag } }
            .sheet(isPresented: $tagsShown) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { TextField("添加小标签", text: $newTag).textFieldStyle(.roundedBorder); Button("选择") { let clean = newTag.trimmingCharacters(in: .whitespacesAndNewlines); if !clean.isEmpty { tag = clean; newTag = ""; tagsShown = false } } }
                        ScrollView { LazyVGrid(columns: [GridItem(.adaptive(minimum: 85))], spacing: 10) { ForEach(tagsSnapshot, id: \.self) { item in Button { tag = item; tagsShown = false } label: { Text(item).font(.subheadline).frame(maxWidth: .infinity).padding(12).background(honey.opacity(0.35), in: Capsule()) } } } }
                        Button("本次只记大类") { tag = ""; tagsShown = false }
                    }.padding().background(cream).navigationTitle(category + " · 全部标签").navigationBarTitleDisplayMode(.inline)
                }.presentationDetents([.height(320), .medium])
            }
    }
    private func evaluated() -> Int64? {
        guard let right = Ledger.cents(amount) else { return nil }
        guard let left = operand, let operation else { return right }
        return operation == "+" ? left + right : left - right
    }
    private func press(_ key: String) {
        if key == "⌫" { if !amount.isEmpty { amount.removeLast() }; return }
        if ["+", "−", "="].contains(key) {
            guard let result = evaluated(), abs(result) <= 999_999_999_999 else { store.error = "请先输入有效金额"; return }
            amount = key == "=" ? Ledger.money(result) : ""
            operand = key == "=" ? nil : result; operation = key == "=" ? nil : key; return
        }
        if key == "完成" {
            guard let value = evaluated(), value > 0, let account else { store.error = "请输入大于 0 的金额"; return }
            if store.add(Entry(date: date, kind: kind, amount: value, account: account, destination: destination, category: category, tag: tag, note: note, parent: parent?.id)) { dismiss() }; return
        }
        if key == "." { if !amount.contains(".") { amount = amount.isEmpty ? "0." : amount + "." }; return }
        if let decimal = amount.firstIndex(of: "."), amount.distance(from: decimal, to: amount.endIndex) > 2 { return }
        if amount.count < 13 { amount += key }
    }
}
struct EntryDetail: View {
    @EnvironmentObject var store: Store
    let entry: Entry
    @State private var eventKind = "退款"
    @State private var event = false
    @State private var editing = false
    @State private var split = false
    @State private var splitAmount = ""
    var current: Entry { store.state.entries.first { $0.id == entry.id } ?? entry }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            let entry = current
            EntryRow(entry: current).card(honey.opacity(0.3))
            Button("编辑这笔记录") { editing = true }
            Text(entry.date.formatted(date: .complete, time: .shortened))
            if !entry.note.isEmpty { Text(entry.note) }
            if let destination = entry.destination { Text("转入：" + store.accountName(destination)) }
            let children = store.state.entries.filter { $0.parent == entry.id }
            if entry.kind == "支出" {
                Text("当前净支出 ¥ " + Ledger.money(entry.amount - children.reduce(0) { $0 + $1.amount })).font(.title3.bold())
                let received = children.filter { $0.kind == "分摊回款" }.reduce(Int64(0)) { $0 + $1.amount }
                Button { splitAmount = Ledger.money(current.expectedShare); split = true } label: { HStack { Text("待收分摊"); Spacer(); Text("¥ " + Ledger.money(max(0, current.expectedShare - received))); Image(systemName: "pencil") } }.card(honey.opacity(0.2))
                HStack { Button("记退款") { eventKind = "退款"; event = true }; Spacer(); Button("收到朋友分摊") { eventKind = "分摊回款"; event = true } }.card()
                Text("回款到账后选择实际收款账户和日期；未收到的钱不计入余额。").font(.caption).foregroundStyle(.secondary)
                ForEach(children) { EntryRow(entry: $0) }
            }
        }.padding() }.background(cream).navigationTitle("记录详情")
            .alert("设置朋友应分摊的总金额", isPresented: $split) {
                TextField("金额", text: $splitAmount).keyboardType(.decimalPad)
                Button("取消", role: .cancel) {}
                Button("保存") {
                    guard let amount = Ledger.cents(splitAmount), amount >= 0, amount <= entry.amount else { store.error = "分摊金额应在 0 与原支出之间"; return }
                    store.change { state in
                        let received = state.entries.filter { $0.parent == entry.id && $0.kind == "分摊回款" }.reduce(Int64(0)) { $0 + $1.amount }
                        guard amount >= received else { throw ModelError.invalid("应分摊总额不能小于已收分摊") }
                        if let index = state.entries.firstIndex(where: { $0.id == entry.id }) { state.entries[index].expectedShare = amount }
                    }
                }
            } message: { Text("只标记待收款，到账前不会增加账户余额。填 0 可取消待收标记。") }
            .sheet(isPresented: $event) { NavigationStack { EntryForm(parent: current, kind: eventKind) } }
            .sheet(isPresented: $editing) { EntryEditor(entry: current) }
    }
}
struct AccountsView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Account? = nil
    @State private var adding = false
    var body: some View {
        List {
            Section("剩余总金额 ¥ " + Ledger.money(store.state.accounts.reduce(0) { $0 + $1.balance })) {
                ForEach(store.state.accounts) { account in Button { editing = account } label: { HStack { Text(account.name); Spacer(); Text((account.isDebt ? "欠款 " : "") + Ledger.money(account.isDebt ? -account.balance : account.balance)) } } }
                Button("添加账户") { adding = true }
            }
            Section { Text("点击每项修改实际余额。校准不计入收入或支出。信用卡、花呗填正数欠款，溢缴款填负数。").font(.caption) }
            Section("余额校准历史") { ForEach(store.state.calibrations.reversed()) { item in VStack(alignment: .leading) { Text(store.accountName(item.account) + "：" + Ledger.money(item.before) + " → " + Ledger.money(item.after)); Text(item.date.formatted()).font(.caption).foregroundStyle(.secondary) } } }
        }.scrollContentBackground(.hidden).background(cream).navigationTitle("账户与余额")
            .sheet(item: $editing) { AccountEditor(account: $0) }.sheet(isPresented: $adding) { AccountEditor(account: Account(name: ""), isNew: true) }
    }
}
struct AccountEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let account: Account
    var isNew = false
    @State private var name = ""
    @State private var amount = ""
    @State private var debt = false
    var body: some View {
        NavigationStack { Form {
            TextField("账户名称", text: $name)
            if isNew { Toggle("这是负债账户", isOn: $debt) }
            TextField(debt ? "欠款金额" : "实际余额", text: $amount).keyboardType(.numbersAndPunctuation)
            Text("只校准本账户，不产生消费或收入。负债正数表示欠款，负数表示溢缴款。").font(.caption)
        }.navigationTitle(isNew ? "添加账户" : "校准余额").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("保存") {
                guard let number = Ledger.cents(amount), !name.trimmingCharacters(in: .whitespaces).isEmpty else { store.error = "请填写账户名称及有效金额"; return }
                if store.change({ state in
                    let balance = debt ? -number : number
                    if isNew { var item = account; item.name = name; item.balance = balance; item.isDebt = debt; state.accounts.append(item) }
                    else if let i = state.accounts.firstIndex(where: { $0.id == account.id }) { state.calibrations.append(Calibration(account: account.id, before: state.accounts[i].balance, after: balance)); state.accounts[i].balance = balance; state.accounts[i].name = name }
                }) { dismiss() }
            } }
        }.onAppear { name = account.name; debt = account.isDebt; amount = Ledger.money(account.isDebt ? -account.balance : account.balance) } }
    }
}
struct StatisticsView: View {
    @EnvironmentObject var store: Store
    @State private var start = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: Date()))!
    @State private var end = Date()
    @State private var search = ""
    var body: some View {
        List {
            TextField("搜索小标签或旧备注", text: $search)
            HStack { Button("本周期") { start = Ledger.cycleStart(Date(), payday: store.state.payday); end = Date() }; Spacer(); Button("今年") { start = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: Date()))!; end = Date() } }
            DatePicker("开始", selection: $start, displayedComponents: .date)
            DatePicker("结束", selection: $end, in: start..., displayedComponents: .date)
            let entries = store.state.entries.filter { $0.date >= Calendar.current.startOfDay(for: start) && $0.date < Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end))! && ["支出", "退款", "分摊回款"].contains($0.kind) && (search.isEmpty || ($0.category + $0.tag + $0.note).localizedCaseInsensitiveContains(search)) }
            let netTotal = entries.reduce(Int64(0)) { $0 + ($1.kind == "支出" ? $1.amount : -$1.amount) }
            LabeledContent("筛选净支出", value: "¥ " + Ledger.money(netTotal))
            let groups = Dictionary(grouping: entries) { $0.category + ($0.tag.isEmpty ? "" : " · " + $0.tag) }
            ForEach(groups.keys.sorted(), id: \.self) { key in
                let items = groups[key]!
                let paid = items.filter { $0.kind == "支出" }.reduce(Int64(0)) { $0 + $1.amount }
                let returned = items.filter { $0.kind != "支出" }.reduce(Int64(0)) { $0 + $1.amount }
                VStack(alignment: .leading, spacing: 5) { HStack { Text(key); Spacer(); Text("¥ " + Ledger.money(paid - returned)).bold() }; Text("支出 \(Ledger.money(paid)) · 回款 \(Ledger.money(returned))" + (netTotal > 0 && paid >= returned ? " · " + String(format: "%.1f%%", Double(paid - returned) / Double(netTotal) * 100) : "")).font(.caption).foregroundStyle(.secondary) }
            }
            Text("按实际收支日期统计，回款包括退款和朋友分摊。").font(.caption)
        }.navigationTitle("分类与小标签统计").scrollContentBackground(.hidden).background(cream)
    }
}
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var bytes: Data
    init(bytes: Data) { self.bytes = bytes }
    init(configuration: ReadConfiguration) throws { bytes = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: bytes) }
}
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var exporting = false
    @State private var document = BackupDocument(bytes: Data())
    var body: some View {
        Form {
            Section("记账") { Stepper("发薪周期从每月 \(store.state.payday) 日开始", value: Binding(get: { store.state.payday }, set: { value in store.change { $0.payday = value } }), in: 1...31)
                NavigationLink("账户与余额") { AccountsView() }
                NavigationLink("固定大类顺序") { CategorySettings() }
            }
            Section("排便常态 · 不沿用上次异常") { ForEach(bowelOptions, id: \.0) { item in Picker(item.0, selection: Binding(get: { store.state.bowelDefaults[item.0] ?? item.1[0] }, set: { value in store.change { $0.bowelDefaults[item.0] = value } })) { ForEach(item.1, id: \.self) { Text($0) } } } }
            Section("提醒") {
                Toggle("启用排便提醒", isOn: Binding(get: { store.state.remindersEnabled == true }, set: { store.setReminders($0) }))
                Stepper("未结束记录：每天 \(store.state.reminderHour ?? 22):00 检查", value: Binding(get: { store.state.reminderHour ?? 22 }, set: { value in store.change { $0.reminderHour = value } }), in: 0...23)
                Text("同一次计时只提醒一次；3 天无记录提醒一次，新的排便记录会重新计算。").font(.caption)
                if !store.reminderStatus.isEmpty { Text(store.reminderStatus).font(.caption).foregroundStyle(.secondary) }
            }
            Section("本地数据") {
                Button("导出备份到文件 / iCloud Drive") { do { document = BackupDocument(bytes: try JSONEncoder().encode(store.state)); exporting = true } catch { store.error = error.localizedDescription } }
                NavigationLink("导入懒猫账单 / 恢复备份") { DataTransferView() }
                Text("可将备份存入 iCloud Drive。导入历史账单不改变当前余额；恢复备份前会保留当前数据副本。").font(.caption)
            }
            Section { Text("圆景记录 · 原生开发版 0.2\n小组件实时状态同步尚未启用。").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("设置").fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "圆景记录备份") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
    }
}
struct CategorySettings: View {
    @EnvironmentObject var store: Store
    var body: some View {
        List { ForEach(store.state.categories, id: \.self) { Text($0) }.onMove { source, destination in store.change { $0.categories.move(fromOffsets: source, toOffset: destination) } } }.environment(\.editMode, .constant(.active)).navigationTitle("调整大类顺序")
    }
}

struct DataTransferView: View {
    @EnvironmentObject var store: Store
    @State private var choosing = false
    @State private var restoreMode = false
    @State private var loading = false
    @State private var preview: ImportPreview? = nil
    @State private var replacement: Snapshot? = nil
    @State private var mapping: [String: UUID] = [:]
    @State private var completeHistory = false
    @State private var confirmRestore = false
    @State private var message: String? = nil
    var body: some View {
        List {
            Section("选择文件") {
                Button("导入懒猫 CSV / TSV") { restoreMode = false; choosing = true }
                Button("恢复圆景 JSON 备份") { restoreMode = true; choosing = true }
                Text("通过「文件」选择本机或 iCloud Drive 中的文件。").font(.caption)
                if loading { ProgressView("正在读取与校验…") }
            }.disabled(loading)
            if let message { Section { Text(message) } }
            if let preview {
                Section("导入预览") {
                    LabeledContent("文件记录", value: "\(preview.totalCount) 笔")
                    LabeledContent("将新增", value: "\(preview.rows.count) 笔")
                    LabeledContent("已导入，跳过", value: "\(preview.duplicateCount) 笔")
                    LabeledContent("新增支出", value: "¥ " + Ledger.money(preview.expense))
                    LabeledContent("新增收入", value: "¥ " + Ledger.money(preview.income))
                    if let first = preview.earliest, let last = preview.latest { Text(first.formatted(date: .numeric, time: .omitted) + " — " + last.formatted(date: .numeric, time: .omitted)) }
                }
                Section("旧账户对应到") {
                    ForEach(preview.accounts, id: \.self) { name in
                        Picker(name, selection: Binding<UUID?>(get: { mapping[name] }, set: { mapping[name] = $0 })) {
                            Text("新建同名账户（余额 0）").tag(nil as UUID?)
                            ForEach(store.state.accounts) { Text($0.name).tag(Optional($0.id)) }
                        }
                    }
                    Text("只导入历史记录，不累加到当前余额。导入后可逐项校准余额。").font(.caption)
                }
                Section("历史完整度") {
                    Toggle("此文件覆盖所示日期之间的全部账单", isOn: $completeHistory)
                    Text("确认完整后，才用这段历史计算前三个月同期平均。旧备注原样保留，不自动变成小标签。").font(.caption)
                }
                Section("前 5 笔") { ForEach(Array(preview.rows.prefix(5))) { row in VStack(alignment: .leading) { Text(row.category + " · " + row.kind + " ¥ " + Ledger.money(row.amount)); Text(row.date.formatted() + " · " + row.account).font(.caption); if !row.note.isEmpty { Text(row.note).font(.caption).foregroundStyle(.secondary) } } } }
                Button("确认导入 \(preview.rows.count) 笔") {
                    if store.change({ try Migration.apply(preview, mapping: mapping, completeHistory: completeHistory, to: &$0) }) { message = "已导入 \(preview.rows.count) 笔，当前账户余额未改变。"; self.preview = nil }
                }.disabled(preview.rows.isEmpty)
            }
            if let replacement {
                Section("备份内容") {
                    Text("\(replacement.accounts.count) 个账户 · \(replacement.entries.count) 笔账单 · \(replacement.bowels.count) 次排便")
                    Text("净余额 ¥ " + Ledger.money(replacement.accounts.reduce(0) { $0 + $1.balance }))
                    Text("恢复会用备份替换当前记录及设置，当前版本会另存为本地副本。").font(.caption)
                    Button("恢复这份备份", role: .destructive) { confirmRestore = true }
                }
            }
        }.navigationTitle("导入与恢复").scrollContentBackground(.hidden).background(cream)
            .fileImporter(isPresented: $choosing, allowedContentTypes: restoreMode ? [.json] : [.commaSeparatedText, .tabSeparatedText, .plainText, .data]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 50_000_000 else { throw ModelError.invalid("文件超过 50 MB") }
                    let bytes = try Data(contentsOf: url)
                    preview = nil; replacement = nil; message = nil; loading = true
                    let mode = restoreMode, keys = Set(store.state.entries.compactMap(\.sourceKey))
                    Task {
                        do {
                            if mode { replacement = try await Task.detached { try Backup.decode(bytes) }.value }
                            else {
                                let result = try await Task.detached { try Migration.parse(bytes, existing: keys) }.value
                                mapping = [:]; completeHistory = false
                                for name in result.accounts {
                                    let alias = ["微信钱包": "微信", "储蓄卡": "银行卡"][name] ?? name
                                    mapping[name] = store.state.accounts.first { $0.name == name || $0.name == alias }?.id
                                }
                                preview = result
                            }
                        } catch { message = error.localizedDescription }
                        loading = false
                    }
                } catch { message = error.localizedDescription; loading = false }
            }
            .alert("替换当前记录？", isPresented: $confirmRestore) {
                Button("取消", role: .cancel) {}
                Button("恢复", role: .destructive) { if let replacement, store.restore(replacement) { self.replacement = nil; message = "备份已恢复，恢复前的数据已留存本机。" } }
            } message: { Text("请先核对备份中的记录数量与余额。") }
    }
}

struct EntryEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let entry: Entry
    @State private var amount = ""
    @State private var date = Date()
    @State private var account: UUID? = nil
    @State private var destination: UUID? = nil
    @State private var category = ""
    @State private var tag = ""
    @State private var note = ""
    @State private var error: String? = nil
    var body: some View {
        NavigationStack { Form {
            Text(entry.kind)
            TextField("金额", text: $amount).keyboardType(.decimalPad)
            DatePicker("日期", selection: $date)
            Picker("账户", selection: $account) { ForEach(store.state.accounts) { Text($0.name).tag(Optional($0.id)) } }
            if entry.kind == "转账" { Picker("转入账户", selection: $destination) { ForEach(store.state.accounts) { Text($0.name).tag(Optional($0.id)) } } }
            if entry.parent == nil && entry.kind != "转账" {
                Picker("大类", selection: $category) { ForEach(store.state.categories, id: \.self) { Text($0) } }
                TextField("小标签", text: $tag)
            }
            TextField("备注", text: $note, axis: .vertical)
            Text("历史导入记录只修正统计，不改变余额。已经校准过余额的账户，校准前的记录修改也不会再次扣款。").font(.caption)
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("编辑记录").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("保存") {
                guard let number = Ledger.cents(amount), number > 0, let account else { error = "请填写有效金额和账户"; return }
                var edited = entry
                edited.amount = number; edited.date = date; edited.account = account; edited.destination = destination
                edited.category = category; edited.tag = tag; edited.note = note
                var preview = store.state
                do { try Ledger.replace(edited, in: &preview) } catch { self.error = error.localizedDescription; return }
                if store.change({ try Ledger.replace(edited, in: &$0) }) { dismiss() }
            } }
        }.onAppear { amount = Ledger.money(entry.amount); date = entry.date; account = entry.account; destination = entry.destination; category = entry.category; tag = entry.tag; note = entry.note } }
    }
}
