import SwiftUI
import Charts

struct AnalysisView: View {
    @EnvironmentObject var store: Store
    let mode: String
    @State private var period = "薪月"
    @State private var anchor = Date()
    @State private var customStart = Calendar.current.startOfDay(for: Date())
    @State private var customEnd = Date()
    @State private var kind = "支出"
    @State private var search = ""
    @State private var category = ""
    init(mode: String, initialPeriod: String = "薪月", initialAnchor: Date = Date(), initialStart: Date = Date(), initialEnd: Date = Date(), initialKind: String = "支出") {
        self.mode = mode
        _kind = State(initialValue: initialKind)
        _period = State(initialValue: initialPeriod)
        _anchor = State(initialValue: initialAnchor)
        _customStart = State(initialValue: initialStart)
        _customEnd = State(initialValue: initialEnd)
    }
    private var range: DateInterval {
        if period == "区间" {
            return DateInterval(start: Calendar.current.startOfDay(for: customStart), end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: max(customStart, customEnd)))!)
        }
        return FinanceAnalysis.range(period, anchor: anchor, payday: store.state.payday)
    }
    private var selected: [Entry] { FinanceAnalysis.entries(store.state.entries, in: range, kind: kind) }
    private var groups: [AnalysisGroup] {
        FinanceAnalysis.groups(selected, all: store.state.entries, tags: mode == "标签分析").filter {
            (category.isEmpty || $0.id.category == category) && (search.isEmpty || ($0.id.category + " " + $0.id.tag).localizedCaseInsensitiveContains(search))
        }
    }
    private var total: Int64 { selected.reduce(0) { $0 + FinanceAnalysis.signed($1) } }
    private var positiveTotal: Int64 { groups.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount } }
    private var rangeLabel: String {
        let end = Calendar.current.date(byAdding: .day, value: -1, to: range.end)!
        return range.start.formatted(.dateTime.year().month().day()) + " — " + end.formatted(.dateTime.month().day())
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                periodControls
                if mode == "金额分析" { overview }
                Picker("收支类型", selection: $kind) { Text("支出").tag("支出"); Text("收入").tag("收入") }.pickerStyle(.segmented)
                if mode == "金额分析" { trend } else { breakdown }
                Text("按实际收支日期统计。退款、分摊回款冲减原分类和标签的支出；转账、余额校准不计入收支。结余是本期收入减净支出，不是账户余额。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }.navigationTitle(mode).navigationBarTitleDisplayMode(.inline).background(cream).foregroundStyle(ink)
            .onChange(of: customStart) { _, value in if customEnd < value { customEnd = value } }
            .onChange(of: kind) { _, _ in category = "" }
    }
    private var periodControls: some View {
        VStack(spacing: 14) {
            Picker("统计周期", selection: $period) {
                ForEach(["薪月", "周", "月", "年", "区间"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
            if period == "区间" {
                DatePicker("开始日期", selection: $customStart, displayedComponents: .date).accessibilityIdentifier("analysis-start-date")
                DatePicker("结束日期", selection: $customEnd, in: customStart..., displayedComponents: .date).accessibilityIdentifier("analysis-end-date")
            } else {
                HStack {
                    Button { move(-1) } label: { Image(systemName: "chevron.left.circle").font(.title2).frame(width: 40, height: 44) }.accessibilityLabel("上一周期")
                    Text(rangeLabel).font(.subheadline.bold()).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    Button { move(1) } label: { Image(systemName: "chevron.right.circle").font(.title2).frame(width: 40, height: 44) }.accessibilityLabel("下一周期")
                }
                Button("回到本期") { anchor = Date() }.font(.caption)
            }
            if period == "薪月" { Text("按每月 \(store.state.payday) 日发薪计算").font(.caption).foregroundStyle(.secondary) }
        }
    }
    private func move(_ direction: Int) {
        if direction < 0 { anchor = range.start.addingTimeInterval(-1) }
        else { anchor = range.end }
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 7) {
            Text(value).font(.system(.headline, design: .rounded)).minimumScaleFactor(0.65).lineLimit(1)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 5)
    }
    private var overview: some View {
        let expense = FinanceAnalysis.entries(store.state.entries, in: range, kind: "支出").reduce(Int64(0)) { $0 + FinanceAnalysis.signed($1) }
        let incomeEntries = FinanceAnalysis.entries(store.state.entries, in: range, kind: "收入")
        let income = incomeEntries.reduce(Int64(0)) { $0 + $1.amount }
        let days = FinanceAnalysis.elapsedDays(range)
        let count = FinanceAnalysis.entries(store.state.entries, in: range, kind: "支出").count + incomeEntries.count
        return VStack(alignment: .leading, spacing: 16) {
            Text("收支总览").font(.headline)
            HStack { metric("净支出", "¥" + Ledger.money(expense)); metric("收入", "¥" + Ledger.money(income)); metric("结余", "¥" + Ledger.money(income - expense)) }
            HStack { metric("日均净支出", days > 0 ? "¥" + Ledger.money(expense / Int64(days)) : "—"); metric("已过天数", "\(days)"); metric("账单笔数", "\(count)") }
            if period == "薪月", range.contains(Date()) {
                Text(Ledger.comparison(store.state.entries, now: Date(), payday: store.state.payday, coverageStart: store.state.trackingStartedAt)).font(.caption).accessibilityIdentifier("analysis-comparison")
            }
        }.card(honey.opacity(0.22))
    }
    private var trend: some View {
        let points = FinanceAnalysis.points(selected, range: range)
        return VStack(alignment: .leading, spacing: 16) {
            Text(kind + "趋势").font(.headline)
            Text("¥ " + Ledger.money(total)).font(.title.bold()).accessibilityIdentifier("analysis-total")
            if selected.isEmpty {
                emptyState
            } else {
                Chart(points) { point in
                    BarMark(x: .value("日期", point.date), y: .value("金额", Double(point.amount) / 100))
                        .foregroundStyle(point.amount < 0 ? Color.teal.opacity(0.7) : honey)
                }.chartYAxis { AxisMarks(position: .leading) }.frame(height: 220)
                Text("长于 93 天的区间按月汇总，其余按天；当前周期不绘制未来日期。").font(.caption).foregroundStyle(.secondary)
            }
            NavigationLink { AnalysisView(mode: "大类分析", initialPeriod: period, initialAnchor: anchor, initialStart: customStart, initialEnd: customEnd, initialKind: kind) } label: { Label("查看大类分析", systemImage: "chart.pie") }
            NavigationLink { AnalysisView(mode: "标签分析", initialPeriod: period, initialAnchor: anchor, initialStart: customStart, initialEnd: customEnd, initialKind: kind) } label: { Label("查看标签分析", systemImage: "tag") }
        }.card()
    }
    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 18) {
            if mode == "标签分析" {
                TextField("搜索标签，如寿司郎", text: $search).textFieldStyle(.roundedBorder).submitLabel(.done).accessibilityIdentifier("analysis-tag-search")
                Picker("大类", selection: $category) {
                    Text("全部大类").tag("")
                    ForEach(Array(Set(selected.map { FinanceAnalysis.key($0, all: store.state.entries, tags: true).category })).sorted(), id: \.self) { Text($0).tag($0) }
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                Text(kind + "分布").font(.headline)
                Text("¥ " + Ledger.money(groups.reduce(0) { $0 + $1.amount })).font(.title.bold()).accessibilityIdentifier("analysis-total")
                if groups.isEmpty { emptyState }
                else if positiveTotal > 0 {
                    Chart {
                        ForEach(Array(groups.filter { $0.amount > 0 }.prefix(8))) { group in
                        SectorMark(angle: .value("金额", Double(group.amount)), innerRadius: .ratio(0.68), angularInset: 2)
                            .foregroundStyle(by: .value("分类", label(group)))
                        }
                        let other = groups.filter { $0.amount > 0 }.dropFirst(8).reduce(Int64(0)) { $0 + $1.amount }
                        if other > 0 {
                            SectorMark(angle: .value("金额", Double(other)), innerRadius: .ratio(0.68), angularInset: 2)
                                .foregroundStyle(by: .value("分类", "其余项目（合计）"))
                        }
                    }.chartForegroundStyleScale(range: [honey, Color(red: 0.77, green: 0.51, blue: 0.32), Color(red: 0.57, green: 0.70, blue: 0.57), Color(red: 0.90, green: 0.64, blue: 0.59), Color(red: 0.60, green: 0.68, blue: 0.77), Color(red: 0.77, green: 0.67, blue: 0.79), Color(red: 0.83, green: 0.74, blue: 0.51), Color(red: 0.50, green: 0.69, blue: 0.67), Color.gray])
                    .chartLegend(position: .bottom, spacing: 8).frame(height: 230)
                    if groups.filter({ $0.amount > 0 }).count > 8 { Text("环图将前 8 项以外的金额合并显示，完整占比见下方列表。").font(.caption).foregroundStyle(.secondary) }
                }
                if groups.contains(where: { $0.amount < 0 }) {
                    Text("负数表示本期回款超过支出。占比按正金额合计计算，负数单独列出。").font(.caption).foregroundStyle(.secondary)
                }
            }.card(honey.opacity(0.15))
            ForEach(groups) { group in
                NavigationLink {
                    AnalysisRecords(title: label(group), entries: selected.filter { FinanceAnalysis.key($0, all: store.state.entries, tags: mode == "标签分析") == group.id })
                } label: {
                    HStack(spacing: 12) {
                        CatIcon(index: categoryArt.firstIndex(of: group.id.category) ?? 18, size: 42)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text(label(group)).font(.subheadline.bold()); Spacer(minLength: 4); Text("¥" + Ledger.money(group.amount)).font(.subheadline.bold()) }
                            HStack { Text("\(group.count) 笔"); Spacer(); Text(group.amount > 0 && positiveTotal > 0 ? String(format: "%.1f%%", Double(group.amount) / Double(positiveTotal) * 100) : "—") }.font(.caption).foregroundStyle(.secondary)
                            ProgressView(value: positiveTotal > 0 ? max(0, Double(group.amount) / Double(positiveTotal)) : 0).tint(honey)
                        }
                        Image(systemName: "chevron.right").font(.caption)
                    }.card()
                }.accessibilityIdentifier("analysis-group-" + label(group))
            }
        }
    }
    private func label(_ group: AnalysisGroup) -> String {
        mode == "标签分析" ? group.id.category + " · " + (group.id.tag.isEmpty ? "未设标签" : group.id.tag) : group.id.category
    }
    private var emptyState: some View {
        VStack(spacing: 8) { CatIcon(index: 23, size: 64); Text("这个范围还没有记录").font(.subheadline); Text("换个时间范围，或等账单导入后再看看。").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 16)
    }
}
struct AnalysisRecords: View {
    let title: String
    let entries: [Entry]
    var body: some View {
        List {
            ForEach(entries.sorted { $0.date > $1.date }) { entry in
                NavigationLink { EntryDetail(entry: entry) } label: { EntryRow(entry: entry) }
            }
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline).scrollContentBackground(.hidden).background(cream)
    }
}
