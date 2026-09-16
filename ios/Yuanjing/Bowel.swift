import SwiftUI
struct BowelHome: View {
    @EnvironmentObject var store: Store
    @State private var day = Date()
    @State private var edit = false
    @State private var cancel = false
    @State private var detail: BowelEntry? = nil
    var body: some View {
        ScrollView { VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text("便便记录").font(.largeTitle.bold())
                    if let start = store.state.runningSince { Text("正在记录"); Text(start, style: .timer).font(.title.bold()).monospacedDigit() }
                    else if let last = store.state.bowels.max(by: { $0.end < $1.end }) { Text("上次记录"); Text(last.end, style: .relative).font(.title3.bold()) }
                    else { Text("从今天开始好好记录") }
                }; Spacer(); CatIcon(index: 24, size: 95)
            }.frame(maxWidth: .infinity, alignment: .leading).card(honey.opacity(0.35))
            Button {
                if store.state.runningSince == nil { store.change { $0.runningSince = Date() } }
                else { edit = true }
            } label: { Text(store.state.runningSince == nil ? "开始便便" : "结束并记录").bold().frame(maxWidth: .infinity).card(honey) }.buttonStyle(.plain)
            if store.state.runningSince != nil { Button("取消这次计时", role: .destructive) { cancel = true }.font(.caption); Text("可以切去其他应用，回来继续。\n计时起点已保存在手机。 ").font(.caption).foregroundStyle(.secondary) }
            BowelCalendar(day: $day, dates: store.state.bowels.map(\.start)).card()
            HStack { Text(day.formatted(.dateTime.month().day())).bold(); Spacer(); Button("补记") { edit = true } }
            let records = store.state.bowels.filter { Calendar.current.isDate($0.start, inSameDayAs: day) }.sorted { $0.start > $1.start }
            if records.isEmpty { Text("这天还没有记录").foregroundStyle(.secondary).padding() }
            ForEach(records) { entry in Button { detail = entry } label: { HStack {
                CatIcon(index: 21, size: 35)
                VStack(alignment: .leading) { Text((entry.selections["形态"] ?? "未知") + " · " + (entry.selections["颜色"] ?? "未知")); Text("\(entry.start.formatted(.dateTime.hour().minute())) · \(Int(entry.end.timeIntervalSince(entry.start)) / 60) 分 \(Int(entry.end.timeIntervalSince(entry.start)) % 60) 秒").font(.caption).foregroundStyle(.secondary) }; Spacer()
            }.card() }.buttonStyle(.plain) }
            if !store.state.bowels.isEmpty { Text("有记录的日期").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                let dates = Array(Set(store.state.bowels.map { Calendar.current.startOfDay(for: $0.start) })).sorted(by: >)
                ScrollView(.horizontal) { HStack { ForEach(dates, id: \.self) { date in Button(date.formatted(.dateTime.month().day())) { day = date }.padding(10).background(honey.opacity(0.35), in: Capsule()) } } }
            }
        }.padding(20) }.background(cream).navigationBarHidden(true)
            .sheet(isPresented: $edit) { NavigationStack { BowelForm(initialStart: store.state.runningSince ?? day, timed: store.state.runningSince != nil) } }
            .sheet(item: $detail) { entry in NavigationStack { List { Text(entry.start.formatted()); Text("时长 \(Int(entry.end.timeIntervalSince(entry.start))) 秒"); ForEach(bowelOptions, id: \.0) { item in LabeledContent(item.0, value: entry.selections[item.0] ?? "未知") }; if !entry.note.isEmpty { Text(entry.note) } }.navigationTitle("排便详情") } }
            .alert("取消本次计时？", isPresented: $cancel) { Button("继续记录", role: .cancel) {}; Button("取消计时", role: .destructive) { store.change { $0.runningSince = nil } } } message: { Text("不会生成排便记录。") }
    }
}
struct BowelForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let initialStart: Date
    let timed: Bool
    @State private var start = Date()
    @State private var end = Date()
    @State private var selections: [String: String] = [:]
    @State private var note = ""
    var body: some View {
        Form {
            Section("时间可手动修改") { DatePicker("开始", selection: $start, displayedComponents: [.date, .hourAndMinute]); DatePicker("结束", selection: $end, displayedComponents: [.date, .hourAndMinute]) }
            Section("本次情况") { ForEach(bowelOptions, id: \.0) { item in Picker(item.0, selection: Binding(get: { selections[item.0] ?? item.1[0] }, set: { selections[item.0] = $0 })) { ForEach(item.1, id: \.self) { Text($0) } } } }
            TextField("想记什么都可以", text: $note, axis: .vertical)
            Text("预选来自你设置的固定常态，本次异常不会改变下次默认。").font(.caption)
        }.scrollContentBackground(.hidden).background(cream).navigationTitle("结束记录").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("返回") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("保存") {
                guard end >= start, end <= Date().addingTimeInterval(60) else { store.error = "请检查开始和结束时间"; return }
                if store.change({ state in state.bowels.append(BowelEntry(start: start, end: end, selections: selections, note: note)); if timed { state.runningSince = nil } }) { dismiss() }
            } }
        }.onAppear { start = initialStart; end = timed ? Date() : initialStart; selections = store.state.bowelDefaults }
    }
}

struct BowelCalendar: View {
    @Binding var day: Date
    let dates: [Date]
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())!.start
    private let calendar = Calendar.current
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button { move(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("上个月")
                Spacer(); Text(month.formatted(.dateTime.year().month())).bold(); Spacer()
                Button { move(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("下个月")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 9) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                let offset = calendar.component(.weekday, from: month) - 1
                let count = calendar.range(of: .day, in: .month, for: month)!.count
                ForEach(0..<(offset + count), id: \.self) { index in
                    if index < offset { Color.clear.frame(height: 36) }
                    else {
                        let date = calendar.date(byAdding: .day, value: index - offset, to: month)!
                        let recorded = dates.contains { calendar.isDate($0, inSameDayAs: date) }
                        let selected = calendar.isDate(date, inSameDayAs: day)
                        Button { day = date } label: {
                            VStack(spacing: 3) { Text("\(index - offset + 1)").font(.subheadline.bold()); Circle().fill(recorded ? ink : .clear).frame(width: 4, height: 4) }
                                .frame(maxWidth: .infinity).frame(height: 36).background(recorded ? honey.opacity(0.55) : cream, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? ink : .clear, lineWidth: 2))
                        }.buttonStyle(.plain).accessibilityLabel("\(date.formatted(date: .complete, time: .omitted))，\(recorded ? "有排便记录" : "无记录")")
                    }
                }
            }
        }.onChange(of: day) { _, new in month = calendar.dateInterval(of: .month, for: new)!.start }
    }
    private func move(_ value: Int) { month = calendar.date(byAdding: .month, value: value, to: month)! }
}
