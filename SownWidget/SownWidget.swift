//
//  SownWidget.swift
//  SownWidget
//
//  Created by Alexander Saw on 23/03/2026.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct SownWidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetHabitData
}

// MARK: - Timeline Provider

struct SownWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SownWidgetEntry {
        SownWidgetEntry(date: Date(), data: WidgetDataReader.placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SownWidgetEntry) -> Void) {
        let data = WidgetDataReader.read()
        completion(SownWidgetEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SownWidgetEntry>) -> Void) {
        let data = WidgetDataReader.read()
        let entry = SownWidgetEntry(date: Date(), data: data)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Configuration

// MARK: - Family Switching View

struct SownWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: SownWidgetEntry

    var body: some View {
        switch widgetFamily {
        case .systemLarge:
            SownWidgetLargeView(data: entry.data)
        default:
            SownWidgetMediumView(data: entry.data)
        }
    }
}

struct SownWidget: Widget {
    let kind: String = "SownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SownWidgetProvider()) { entry in
            SownWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Sown")
        .description("See your habits, streak, and blocking status at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct SownWidgetBundle: WidgetBundle {
    var body: some Widget {
        SownWidget()
    }
}

// MARK: - Previews

#Preview(as: .systemLarge) {
    SownWidget()
} timeline: {
    SownWidgetEntry(date: .now, data: WidgetDataReader.placeholder)
    SownWidgetEntry(date: .now, data: WidgetHabitData(
        streakCount: 12,
        isBlockingActive: true,
        todayTasks: [
            WidgetTask(id: UUID(), name: "Book dentist appointment", isCompleted: false),
        ],
        mustDoTasks: [
            WidgetTask(id: UUID(), name: "Morning meditation", isCompleted: true),
            WidgetTask(id: UUID(), name: "Gym workout", isCompleted: false),
            WidgetTask(id: UUID(), name: "Read 30 pages", isCompleted: false),
        ],
        niceToDoTasks: [
            WidgetTask(id: UUID(), name: "Call mum", isCompleted: false),
        ],
        completedCount: 1,
        totalCount: 5,
        lastUpdated: Date()
    ))
}
