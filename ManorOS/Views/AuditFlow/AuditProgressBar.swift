import SwiftUI

struct AuditProgressBar: View {
    let auditProgress: AuditProgress
    let currentStep: AuditStep

    var body: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(AuditStep.allCases.enumerated()), id: \.element.id) { index, step in
                        HStack(spacing: 0) {
                            // Connecting line before (skip for first)
                            if index > 0 {
                                Rectangle()
                                    .fill(auditProgress.isStepComplete(step) || step == currentStep
                                          ? Color.manor.primary
                                          : Color.gray.opacity(0.3))
                                    .frame(width: 12, height: 2)
                            }

                            // Step circle
                            stepCircle(step: step, index: index)

                            // Connecting line after (skip for last)
                            if index < AuditStep.allCases.count - 1 {
                                Rectangle()
                                    .fill(auditProgress.isStepComplete(step)
                                          ? Color.manor.primary
                                          : Color.gray.opacity(0.3))
                                    .frame(width: 12, height: 2)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // Current step label
            Text(currentStep.rawValue)
                .font(.caption.bold())
                .foregroundStyle(Color.manor.primary)
        }
        .padding(.vertical, 8)
    }

    private func stepCircle(step: AuditStep, index: Int) -> some View {
        let isComplete = auditProgress.isStepComplete(step)
        let isCurrent = step == currentStep
        let stateLabel: String = {
            if isCurrent { return "current" }
            if isComplete { return "completed" }
            return "not completed"
        }()

        return ZStack {
            Circle()
                .fill(isComplete ? Color.manor.primary : isCurrent ? Color.manor.primary : Color.clear)
                .frame(width: 28, height: 28)

            Circle()
                .stroke(isComplete || isCurrent ? Color.manor.primary : Color.gray.opacity(0.4), lineWidth: 2)
                .frame(width: 28, height: 28)

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.manor.onPrimary)
            } else {
                Text("\(index + 1)")
                    .font(.caption2.bold())
                    .foregroundStyle(isCurrent ? Color.manor.onPrimary : .secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(index + 1): \(step.rawValue), \(stateLabel)")
    }
}
