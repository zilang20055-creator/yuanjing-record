import SwiftUI
struct BowelHome: View {
    @EnvironmentObject var store: Store
    @State private var day = Date()
    @State private var edit = false
    @State private var cancel = false
    @State private var detail: BowelEntry? = nil
    @State private var modifying: BowelEntry? = nil
    @State private var deleting: BowelEntry? = nil
    var body: some View {
        List {
            VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text("便便记录").font(.largeTitle.bold())
                    if let start = store.state.runningSince { Text("正在记录"); Text(start, style: .timer).font(.title.bold()).monospacedDigit() }
                    else if let last = store.state.bowels.max(by: { $0.end < $1.end }) { Text("上次记录"); Text(last.end, style: .relative).font(.title3.bold()) }
                    else { Text("从今天开始好好记录") }
                }; Spacer(); CatIcon(index: 24, size: 95)
            }.frame(maxWidth: .infinity, alignment: .leading).card(honey.opacity(0.35))
            if store.state.runningSince != nil { Button("没拉出来，结束计时", role: .destructive) { cancel = true }.font(.caption); Text("可以切去其他应用，回来继续。\n计时起点已保存在手机。 ").font(.caption).foregroundStyle(.secondary) }
            BowelCalendar(day: $day, dates: store.state.bowels.map(\.start)).card()
            HStack { Text(day.formatted(.dateTime.month().day())).bold(); Spacer(); Button("补记") { edit = true } }
            }.listRowSeparator(.hidden).listRowBackground(cream)
            let records = store.state.bowels.filter { Calendar.current.isDate($0.start, inSameDayAs: day) }.sorted { $0.start > $1.start }
            if records.isEmpty { Text("这天还没有记录").foregroundStyle(.secondary).padding() }
            ForEach(records) { entry in Button { detail = entry } label: { HStack {
                CatIcon(index: 21, size: 35)
                VStack(alignment: .leading) { Text((entry.selections["形态"] ?? "未知") + " · " + (entry.selections["颜色"] ?? "未知")); Text("\(entry.start.formatted(.dateTime.hour().minute())) · \(Int(entry.end.timeIntervalSince(entry.start)) / 60) 分 \(Int(entry.end.timeIntervalSince(entry.start)) % 60) 秒").font(.caption).foregroundStyle(.secondary) }; Spacer()
            }.card() }.buttonStyle(GentleButtonStyle())
                .accessibilityIdentifier("bowel-record-row")
                .listRowSeparator(.hidden).listRowBackground(cream)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("修改") { modifying = entry }.tint(.brown).buttonStyle(.automatic)
                    Button("删除") { deleting = entry }.tint(.red).buttonStyle(.automatic)
                }
            }
            if !store.state.bowels.isEmpty { Text("有记录的日期").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                let dates = Array(Set(store.state.bowels.map { Calendar.current.startOfDay(for: $0.start) })).sorted(by: >)
                ScrollView(.horizontal) { HStack { ForEach(dates, id: \.self) { date in Button(date.formatted(.dateTime.month().day())) { day = date }.padding(10).background(honey.opacity(0.35), in: Capsule()) } } }
            }
        }.listStyle(.plain).scrollContentBackground(.hidden).background(cream).navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                HStack { Spacer(); Button {
                    if store.state.runningSince == nil { store.change { $0.runningSince = Date() } } else { edit = true }
                } label: { Text(store.state.runningSince == nil ? "开始便便" : "结束并记录").bold().padding(.horizontal, 24).frame(height: 50).background(honey, in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(ink, lineWidth: 2)) }
                }.padding(.horizontal, 16).padding(.vertical, 8).background(cream)
            }
            .sheet(item: $modifying) { entry in NavigationStack { BowelForm(initialStart: entry.start, timed: false, existing: entry) } }
            .alert("删除这次排便记录？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { entry in
                Button("取消", role: .cancel) { deleting = nil }
                Button("删除记录", role: .destructive) {
                    store.change { $0.bowels.removeAll { $0.id == entry.id } }
                    deleting = nil
                }
            } message: { _ in Text("日历和距上次排便的时间会重新计算，正在进行的计时不受影响。删除后无法直接撤销。") }
            .sheet(isPresented: $edit) { NavigationStack { BowelForm(initialStart: store.state.runningSince ?? day, timed: store.state.runningSince != nil) } }
            .sheet(item: $detail) { entry in NavigationStack { List { Text(entry.start.formatted()); Text("时长 \(Int(entry.end.timeIntervalSince(entry.start))) 秒"); ForEach(bowelOptions, id: \.0) { item in LabeledContent(item.0, value: entry.selections[item.0] ?? "未知") }; if !entry.note.isEmpty { Text(entry.note) } }.navigationTitle("排便详情") } }
            .alert("这次没拉出来？", isPresented: $cancel) { Button("继续记录", role: .cancel) {}; Button("结束计时", role: .destructive) { store.change { $0.runningSince = nil } } } message: { Text("结束本次计时，不新增排便记录，也不改变距上次排便的时间。") }
    }
}
struct BowelForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let initialStart: Date
    let timed: Bool
    var existing: BowelEntry? = nil
    @State private var start = Date()
    @State private var end = Date()
    @State private var selections: [String: String] = [:]
    @State private var note = ""
    @State private var noResult = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(spacing: 10) {
                    DatePicker("开始", selection: $start, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("结束", selection: $end, displayedComponents: [.date, .hourAndMinute])
                }.font(.subheadline)
                Picker("图标风格", selection: Binding(get: { store.state.bowelIconStyle ?? "涂鸦" }, set: { value in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.65)
                    store.change { $0.bowelIconStyle = value }
                })) {
                    Text("金渐层涂鸦").tag("涂鸦")
                    Text("拟真").tag("拟真")
                }.pickerStyle(.segmented).accessibilityIdentifier("bowel-icon-style")
                ForEach(bowelOptions, id: \.0) { item in
                    BowelOptionRow(field: item.0, options: item.1,
                        selection: Binding(get: { selections[item.0] ?? item.1[0] }, set: { selections[item.0] = $0 }),
                        realistic: store.state.bowelIconStyle == "拟真")
                }
                TextField("想记什么都可以", text: $note, axis: .vertical).textFieldStyle(.roundedBorder)
                Text("预选来自你设置的固定常态，本次异常不会改变下次默认。").font(.caption).foregroundStyle(.secondary)
                if timed { Button("没拉出来，结束计时", role: .destructive) { noResult = true } }
            }.padding(16)
        }.background(cream).foregroundStyle(ink).navigationTitle(existing == nil ? "结束记录" : "修改记录").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("返回") { dismiss() } }

        }.safeAreaInset(edge: .bottom) {
            HStack { Spacer(); Button("保存") { save() }.bold().padding(.horizontal, 32).frame(height: 50).background(honey, in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(ink, lineWidth: 2)).accessibilityIdentifier("save-bowel") }.padding(.horizontal, 16).padding(.vertical, 8).background(cream)
        }.alert("这次没拉出来？", isPresented: $noResult) {
            Button("继续记录", role: .cancel) {}
            Button("结束计时", role: .destructive) { if store.change({ $0.runningSince = nil }) { dismiss() } }
        } message: { Text("结束本次计时，不新增排便记录，也不改变距上次排便的时间。") }
        .onAppear { start = existing?.start ?? initialStart; end = existing?.end ?? (timed ? Date() : initialStart); selections = existing?.selections ?? store.state.bowelDefaults; note = existing?.note ?? "" }
    }
    private func save() {

                guard end >= start, end <= Date().addingTimeInterval(60) else { store.error = "请检查开始和结束时间"; return }
                if store.change({ state in
                    if let existing {
                        guard let index = state.bowels.firstIndex(where: { $0.id == existing.id }) else { throw ModelError.invalid("原记录不存在") }
                        var updated = existing
                        updated.start = start; updated.end = end; updated.selections = selections; updated.note = note
                        state.bowels[index] = updated
                    } else {
                        state.bowels.append(BowelEntry(start: start, end: end, selections: selections, note: note))
                        if timed { state.runningSince = nil }
                    }
                }) { dismiss() }

    }
}

struct BowelOptionRow: View {
    let field: String
    let options: [String]
    @Binding var selection: String
    let realistic: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(field).font(.headline)
                Spacer()
                Text(selection).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 3) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    choice(index: index, option: option)
                }
            }
        }
    }
    private func choice(index: Int, option: String) -> some View {
        let selected = selection == option
        return Button { selection = option } label: {
            Group {
                if ["厕纸血迹", "沾马桶"].contains(field) {
                    HStack(spacing: 6) { Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.caption); Text(option).font(.subheadline) }.frame(height: 36)
                } else {
                    VStack(spacing: 2) {
                        BowelOptionIcon(field: field, index: index, realistic: realistic).frame(height: 24)
                        Text(option).font(.system(size: 10, weight: selected ? .bold : .regular)).lineLimit(1).minimumScaleFactor(0.7).frame(height: 16)
                    }.frame(height: 44)
                }
            }.frame(maxWidth: .infinity).padding(.vertical, 4)
                .background(selected ? honey.opacity(0.6) : .white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? ink : ink.opacity(0.1), lineWidth: selected ? 2 : 1))
        }.buttonStyle(GentleButtonStyle())
            .accessibilityLabel(field + "：" + option)
            .accessibilityValue(selected ? "已选" : "未选")
            .accessibilityIdentifier("bowel-" + field + "-" + option)
    }
}

enum BowelAtlas {
    static let tiles: [UIImage] = {
        guard let url = Bundle.main.url(forResource: "bowel-shapes", withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path)?.cgImage else { return [] }
        let width = CGFloat(image.width) / 4, height = CGFloat(image.height) / 4
        return (0..<16).map { index in
            let rect = CGRect(x: CGFloat(index % 4) * width, y: CGFloat(index / 4) * height, width: width, height: height)
            return image.cropping(to: rect.integral).map { UIImage(cgImage: $0) } ?? UIImage()
        }
    }()
}
struct BowelOptionIcon: View {
    let field: String
    let index: Int
    let realistic: Bool
    private let colors: [Color] = [Color(red: 0.43, green: 0.24, blue: 0.07), Color(red: 0.7, green: 0.48, blue: 0.24), Color(red: 0.24, green: 0.12, blue: 0.05), .yellow, .green, .black, .red, Color(white: 0.85)]
    private var symbol: String {
        let symbols: [String: [String]] = [
            "分量": ["circle.lefthalf.filled", "circle.dotted", "circle.bottomhalf.filled", "circle.fill"],
            "感觉": ["face.smiling", "bolt.heart", "arrow.trianglehead.clockwise"],
            "气味": ["wind", "leaf", "wind", "wind", "exclamationmark.triangle"],
            "厕纸血迹": ["drop.slash", "drop.fill"],
            "沾马桶": ["sparkles", "toilet.fill"],
            "腹部": ["heart", "circle.dashed", "bolt.fill", "ellipsis.circle"],
            "心情": ["minus.circle", "face.smiling", "star", "cloud.rain", "cloud.bolt"],
            "地点": ["house.fill", "building.2.fill", "graduationcap.fill", "toilet.fill", "mappin.circle"]
        ]
        return symbols[field]?[index] ?? "circle"
    }
    var body: some View {
        Group {
            if field == "形态", BowelAtlas.tiles.count == 16 {
                Image(uiImage: BowelAtlas.tiles[index + (realistic ? 0 : 8)])
                    .resizable().scaledToFit().blendMode(.multiply)
            } else if field == "颜色" {
                Circle().fill(colors[index]).overlay(Circle().stroke(ink.opacity(0.25), lineWidth: 1)).padding(4)
            } else {
                Image(systemName: symbol).font(.system(size: 20, weight: realistic ? .regular : .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(field == "厕纸血迹" && index == 1 ? Color.red : ink)
            }
        }.accessibilityHidden(true)
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
            let offset = calendar.component(.weekday, from: month) - 1
            let count = calendar.range(of: .day, in: .month, for: month)!.count
            Grid(horizontalSpacing: 9, verticalSpacing: 9) {
                GridRow { ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity) } }
                ForEach(0..<((offset + count + 6) / 7), id: \.self) { week in
                    GridRow {
                        ForEach(0..<7, id: \.self) { weekday in
                            let index = week * 7 + weekday
                            if index < offset || index >= offset + count { Color.clear.frame(height: 36) }
                            else { calendarDay(index - offset + 1) }
                        }
                    }
                }
            }
        }.onChange(of: day) { _, new in month = calendar.dateInterval(of: .month, for: new)!.start }
    }
    private func calendarDay(_ number: Int) -> some View {
        let date = calendar.date(byAdding: .day, value: number - 1, to: month)!
        let recorded = dates.contains { calendar.isDate($0, inSameDayAs: date) }
        let selected = calendar.isDate(date, inSameDayAs: day)
        return Button { day = date } label: {
            VStack(spacing: 3) { Text("\(number)").font(.subheadline.bold()); Circle().fill(recorded ? ink : .clear).frame(width: 4, height: 4) }
                .frame(maxWidth: .infinity).frame(height: 36).background(recorded ? honey.opacity(0.55) : cream, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? ink : .clear, lineWidth: 2))
        }.buttonStyle(GentleButtonStyle()).accessibilityLabel("\(date.formatted(date: .complete, time: .omitted))，\(recorded ? "有排便记录" : "无记录")")
    }
    private func move(_ value: Int) { month = calendar.date(byAdding: .month, value: value, to: month)! }
}
