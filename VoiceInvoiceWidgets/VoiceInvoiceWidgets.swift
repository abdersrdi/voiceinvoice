import WidgetKit
import SwiftUI
import AppIntents

@main
struct VoiceInvoiceWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatsWidget()
        QuickInvoiceControl()
    }
}

// MARK: - Control Center / Action Button

struct QuickInvoiceControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.abdersrdi.voiceinvoice.control.newinvoice") {
            ControlWidgetButton(action: StartDictationIntent()) {
                Label("New invoice", systemImage: "mic.fill")
            }
        }
        .displayName("New invoice")
        .description("Start dictating an invoice.")
    }
}

// MARK: - Home and Lock Screen widget

struct StatsEntry: TimelineEntry {
    let date: Date
    let snapshot: InvoiceSnapshot
}

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(
            date: .now,
            snapshot: InvoiceSnapshot(
                currencyCode: "USD", day: .now,
                todayRevenue: 240, todayCount: 3, monthRevenue: 3200, monthCount: 41, freeRemaining: nil
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        completion(StatsEntry(date: .now, snapshot: InvoiceSnapshot.load() ?? .empty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        let entry = StatsEntry(date: .now, snapshot: InvoiceSnapshot.load() ?? .empty)
        let nextMidnight = Calendar.current.nextDate(
            after: .now, matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime
        ) ?? .now.addingTimeInterval(3600)
        let refresh = min(nextMidnight, Date.now.addingTimeInterval(30 * 60))
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct StatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.abdersrdi.voiceinvoice.stats", provider: StatsProvider()) { entry in
            StatsWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Today's invoiced total. Tap to dictate a new invoice.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

private let burgundy = Color(red: 0.42, green: 0.12, blue: 0.18)
private let burgundyDeep = Color(red: 0.16, green: 0.04, blue: 0.07)
private let glacier = Color(red: 0.66, green: 0.82, blue: 0.91)

struct StatsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatsEntry

    private var today: (revenue: Double, count: Int) { entry.snapshot.today(now: entry.date) }
    private var amount: String { today.revenue.formatted(.currency(code: entry.snapshot.currencyCode)) }
    private var dictateURL: URL { URL(string: "voiceinvoice://dictate")! }

    var body: some View {
        content
            .widgetURL(dictateURL)
            .containerBackground(for: .widget) {
                switch family {
                case .accessoryRectangular, .accessoryCircular, .accessoryInline:
                    Color.clear
                default:
                    LinearGradient(colors: [burgundy, burgundyDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Label("\(amount) today", systemImage: "mic.fill")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "mic.fill").font(.system(size: 16, weight: .semibold))
                    Text("\(today.count)").font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("New invoice", systemImage: "mic.fill").font(.caption.weight(.semibold))
                Text(amount).font(.system(.headline, design: .rounded)).minimumScaleFactor(0.6)
                Text("\(today.count) today").font(.caption2)
            }
        case .systemMedium:
            HStack {
                stats
                Spacer()
                micBadge(size: 64)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Today").font(.system(.caption, design: .rounded, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    micBadge(size: 30)
                }
                Spacer(minLength: 0)
                Text(amount)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("\(today.count) invoices").font(.caption).foregroundStyle(glacier)
            }
        }
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today").font(.system(.caption, design: .rounded, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
            Text(amount)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("\(today.count) invoices").font(.footnote).foregroundStyle(glacier)
            if let left = entry.snapshot.freeRemaining {
                Text("\(left) free left this month").font(.caption2).foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func micBadge(size: CGFloat) -> some View {
        Image(systemName: "mic.fill")
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.white.opacity(0.18), in: Circle())
    }
}
