import SwiftUI
import WidgetKit
struct QuickEntry: TimelineEntry { let date: Date }
struct QuickProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickEntry { QuickEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (QuickEntry) -> Void) { completion(QuickEntry(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickEntry>) -> Void) { completion(Timeline(entries: [QuickEntry(date: Date())], policy: .never)) }
}
struct QuickView: View {
    let bowel: Bool
    var cat: UIImage {
        guard let url = Bundle.main.url(forResource: "honey-atlas", withExtension: "jpg"), let image = UIImage(contentsOfFile: url.path)?.cgImage else { return UIImage() }
        let side = CGFloat(image.width) / 5
        let rect = CGRect(x: side * 4 * (bowel ? 0.995 : 0.738), y: side * 4 * 0.97, width: side, height: side).integral
        return image.cropping(to: rect).map { UIImage(cgImage: $0) } ?? UIImage()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(uiImage: cat).resizable().frame(width: 65, height: 65).blendMode(.multiply)
            Spacer()
            Text(bowel ? "开始便便" : "记一笔").font(.title2.bold())
            Text("圆景记录").font(.caption)
        }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Color(red: 0.20, green: 0.16, blue: 0.12))
            .containerBackground(Color(red: 1, green: 0.91, blue: 0.68), for: .widget)
            .widgetURL(URL(string: bowel ? "yuanjing://bowel/start" : "yuanjing://expense"))
    }
}
struct ExpenseWidget: Widget {
    let kind = "YuanjingExpense"
    var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: QuickProvider()) { _ in QuickView(bowel: false) }.configurationDisplayName("快速记账").description("直接打开记一笔页面。").supportedFamilies([.systemSmall]) }
}
struct BowelWidget: Widget {
    let kind = "YuanjingBowel"
    var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: QuickProvider()) { _ in QuickView(bowel: true) }.configurationDisplayName("便便记录").description("开始计时；已有计时则返回当前记录。").supportedFamilies([.systemSmall]) }
}
@main struct YuanjingWidgets: WidgetBundle { var body: some Widget { ExpenseWidget(); BowelWidget() } }
