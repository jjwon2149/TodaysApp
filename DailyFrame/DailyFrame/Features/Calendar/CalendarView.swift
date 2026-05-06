import SwiftUI

struct CalendarView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    Text("2026년 5월")
                        .font(.system(.title2, design: .rounded, weight: .bold))

                    AppCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                            Text("이번 달 18일 중 14일 기록")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(1...31, id: \.self) { day in
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(day.isMultiple(of: 3) ? AppTheme.Colors.secondaryAccent : AppTheme.Colors.muted)
                                        .frame(height: 46)
                                        .overlay {
                                            Text("\(day)")
                                                .font(.system(.footnote, design: .rounded, weight: .semibold))
                                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                        }
                                }
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                            Text("캘린더 화면은 다음 단계에서 실제 썸네일과 날짜 상세 연결을 붙입니다.")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text("현재는 앱 골격과 월간 누적 경험의 기본 구조를 먼저 세팅했습니다.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                .padding(AppTheme.Spacing.medium)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("캘린더")
        }
    }
}
