import SwiftUI

/// Seven fixed day buckets need only bars and labels. Standard SwiftUI shapes
/// also render on Intel environments without a usable Metal chart renderer.
struct ActivityChartView: View {
    let days: [ActivityDay]
    private var maximum: Double { Double(max(1, days.map(\.reviews).max() ?? 0)) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Spacer(minLength: 0)
                    Text(day.reviews.formatted()).font(.system(size: 10))
                        .lineLimit(1).minimumScaleFactor(0.6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(WortagTheme.accent)
                        .frame(height: Double(day.reviews) / maximum * 100)
                    Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 10)).foregroundStyle(WortagTheme.muted)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }.frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide).day().month())): \(day.reviews) graded reviews")
            }
        }.frame(height: 150)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Graded reviews during the last seven days")
    }
}
