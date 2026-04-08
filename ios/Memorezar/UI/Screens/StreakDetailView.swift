import SwiftUI

struct StreakDetailView: View {
    @EnvironmentObject var quoteStore: QuoteStore

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)
                        .frame(width: 70, height: 70)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)

                    Text(String(localized: "\(quoteStore.dailyStreak) days"))
                        .font(.system(size: 36, weight: .bold))

                    Text("Current Streak")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // Stats row
                HStack(spacing: 12) {
                    StatCard(
                        title: String(localized: "Best Streak"),
                        value: String(localized: "\(bestStreak)d"),
                        icon: "trophy.fill",
                        color: .yellow
                    )

                    StatCard(
                        title: String(localized: "Practice Days"),
                        value: String(localized: "\(totalPracticeDays)"),
                        icon: "calendar",
                        color: .blue
                    )

                    StatCard(
                        title: String(localized: "This Week"),
                        value: String(localized: "\(sessionsThisWeek)"),
                        icon: "chart.bar.fill",
                        color: .green
                    )
                }

                // Practice history — last 30 days
                if last30DaysStats.contains(where: { $0.sessionCount > 0 }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Practice History")
                        .font(.headline)

                    ForEach(last30DaysStats, id: \.date) { dayStat in
                        HStack(spacing: 12) {
                            Image(systemName: dayStat.sessionCount > 0 ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(dayStat.sessionCount > 0 ? .green : Color(.systemGray4))

                            Text(dayStat.date, style: .date)
                                .font(.subheadline)

                            Spacer()

                            if dayStat.sessionCount > 0 {
                                Text(String(localized: "\(dayStat.sessionCount) session\(dayStat.sessionCount == 1 ? "" : "s")"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(formatDuration(dayStat.totalDuration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x777777), lineWidth: 2))
                }
            }
            .padding()
        }
        .navigationTitle("Streak")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed Properties

    private var bestStreak: Int {
        let calendar = Calendar.current
        let practiceDays = Set(quoteStore.sessions.map { calendar.startOfDay(for: $0.completedAt) })
            .sorted()

        guard !practiceDays.isEmpty else { return 0 }

        var best = 1
        var current = 1

        for i in 1..<practiceDays.count {
            let expected = calendar.date(byAdding: .day, value: 1, to: practiceDays[i - 1])!
            if calendar.isDate(practiceDays[i], inSameDayAs: expected) {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }

        return best
    }

    private var totalPracticeDays: Int {
        let calendar = Calendar.current
        return Set(quoteStore.sessions.map { calendar.startOfDay(for: $0.completedAt) }).count
    }

    private var sessionsThisWeek: Int {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return quoteStore.sessions.filter { $0.completedAt >= weekStart }.count
    }

    private struct DayStat {
        let date: Date
        let sessionCount: Int
        let totalDuration: TimeInterval
    }

    private var last30DaysStats: [DayStat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<30).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let daySessions = quoteStore.sessions.filter {
                calendar.isDate($0.completedAt, inSameDayAs: date)
            }
            return DayStat(
                date: date,
                sessionCount: daySessions.count,
                totalDuration: daySessions.reduce(0) { $0 + $1.duration }
            )
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return String(localized: "\(mins)m \(secs)s")
        }
        return String(localized: "\(secs)s")
    }
}
