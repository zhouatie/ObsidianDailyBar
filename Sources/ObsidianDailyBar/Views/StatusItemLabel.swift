import SwiftUI

public struct StatusItemLabel: View {
    @ObservedObject var viewModel: DailyNotesViewModel

    public init(viewModel: DailyNotesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)

            if viewModel.todaySnapshot.totalCount > 0 {
                Text("\(viewModel.todaySnapshot.doneCount)/\(viewModel.todaySnapshot.totalCount)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
        }
    }

    private var iconName: String {
        let snap = viewModel.todaySnapshot
        if snap.totalCount > 0 && snap.openCount == 0 {
            return "checkmark.circle.fill"
        } else if snap.openCount > 0 {
            return "checklist"
        } else {
            return "note.text"
        }
    }

    private var iconColor: Color {
        let snap = viewModel.todaySnapshot
        if snap.totalCount > 0 && snap.openCount == 0 {
            return .green
        }
        return .primary
    }
}
