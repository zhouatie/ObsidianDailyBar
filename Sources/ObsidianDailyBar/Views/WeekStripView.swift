import SwiftUI

public struct WeekStripView: View {
    @ObservedObject var viewModel: DailyNotesViewModel

    public init(viewModel: DailyNotesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 6) {
            Button(action: { viewModel.previousDay() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("前一天 (◀)")

            HStack(spacing: 4) {
                ForEach(viewModel.weekDays) { day in
                    DayCapsuleView(
                        day: day,
                        isSelected: Calendar.current.isDate(day.date, inSameDayAs: viewModel.selectedDate)
                    ) {
                        viewModel.selectDate(day.date)
                    }
                }
            }

            Button(action: { viewModel.nextDay() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("后一天 (▶)")

            Divider()
                .frame(height: 16)

            Button(action: { viewModel.goToToday() }) {
                Text("今")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 20, height: 20)
                    .background(viewModel.isToday ? Color.accentColor.opacity(0.2) : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("回到今天")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DayCapsuleView: View {
    let day: DaySummary
    let isSelected: Bool
    let action: () -> Void

    private var weekdaySymbol: String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: day.date)
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        return symbols[(weekday - 1) % 7]
    }

    private var dayNumber: String {
        let calendar = Calendar.current
        return "\(calendar.component(.day, from: day.date))"
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(weekdaySymbol)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(isSelected ? .white : .secondary)

                Text(dayNumber)
                    .font(.system(size: 11, weight: isSelected ? .bold : (day.isToday ? .semibold : .regular)))
                    .foregroundStyle(isSelected ? .white : (day.isToday ? Color.accentColor : .primary))

                // 进度指示点 / 徽标
                if day.totalCount > 0 {
                    if day.openCount == 0 {
                        Circle()
                            .fill(isSelected ? Color.white : Color.green)
                            .frame(width: 4, height: 4)
                    } else {
                        Circle()
                            .fill(isSelected ? Color.white : Color.orange)
                            .frame(width: 4, height: 4)
                    }
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 32, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor : (day.isToday ? Color.accentColor.opacity(0.12) : Color.clear))
            )
        }
        .buttonStyle(.plain)
    }
}
