import SwiftUI

struct ReportTabView: View {
    let home: Home

    var body: some View {
        if home.rooms.isEmpty && home.equipment.isEmpty && home.appliances.isEmpty {
            emptyState
                .navigationTitle("Report")
        } else {
            HomeReportView(home: home, isEmbedded: true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "doc.text.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.manor.primary.opacity(0.4))
            VStack(spacing: 8) {
                Text("No Report Yet")
                    .font(.title2.bold())
                Text("Add rooms from the Home tab to generate your energy report. Equipment and appliances unlock cost estimates and upgrade recommendations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
