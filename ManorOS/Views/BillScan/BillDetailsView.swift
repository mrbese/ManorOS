import SwiftUI
import SwiftData
import UIKit

struct BillDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let home: Home
    var prefilledResult: ParsedBillResult?
    var prefilledImage: UIImage?
    var onComplete: (() -> Void)?

    @State private var utilityName: String = ""
    @State private var billingStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var billingEnd: Date = Date()
    @State private var totalKWhText: String = ""
    @State private var totalCostText: String = ""
    @State private var rateText: String = ""
    @State private var hasSetPrefill = false

    var body: some View {
        NavigationStack {
            Form {
                if let image = prefilledImage {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(maxWidth: .infinity)
                    }
                }

                Section("Utility") {
                    TextField("Utility name (e.g. PG&E)", text: $utilityName)
                }

                Section("Billing Period") {
                    DatePicker("Start", selection: $billingStart, displayedComponents: .date)
                    DatePicker("End", selection: $billingEnd, displayedComponents: .date)
                }

                Section("Usage & Cost") {
                    HStack {
                        TextField("Total kWh", text: $totalKWhText)
                            .keyboardType(.decimalPad)
                        Text("kWh")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("Total cost", text: $totalCostText)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("Rate per kWh (optional)", text: $rateText)
                            .keyboardType(.decimalPad)
                        Text("/kWh")
                            .foregroundStyle(.secondary)
                    }

                    if (Double(totalKWhText) ?? 0) <= 0 && (Double(totalCostText) ?? 0) <= 0 {
                        Text("Enter at least kWh usage or total cost")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let kwh = Double(totalKWhText), let cost = Double(totalCostText), kwh > 0 {
                    Section("Computed") {
                        let rate = rateText.isEmpty ? cost / kwh : (Double(rateText) ?? cost / kwh)
                        HStack {
                            Text("Effective Rate")
                            Spacer()
                            Text(String(format: "$%.3f/kWh", rate))
                                .foregroundStyle(Color.manor.primary)
                        }
                        let days = Calendar.current.dateComponents([.day], from: billingStart, to: billingEnd).day ?? 30
                        if days > 0 {
                            HStack {
                                Text("Daily Average")
                                Spacer()
                                Text(String(format: "%.1f kWh/day", kwh / Double(days)))
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("Annualized")
                                Spacer()
                                Text("\(Int(kwh / Double(days) * 365)) kWh/yr")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Bill Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBill()
                    }
                    .bold()
                    .disabled(
                        (Double(totalKWhText) ?? 0) <= 0 && (Double(totalCostText) ?? 0) <= 0 ||
                        billingStart >= billingEnd
                    )
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .onAppear {
                guard !hasSetPrefill else { return }
                hasSetPrefill = true
                if let r = prefilledResult {
                    utilityName = r.utilityName ?? ""
                    if let start = r.billingPeriodStart { billingStart = start }
                    if let end = r.billingPeriodEnd { billingEnd = end }
                    if let kwh = r.totalKWh { totalKWhText = String(format: "%.0f", kwh) }
                    if let cost = r.totalCost { totalCostText = String(format: "%.2f", cost) }
                    if let rate = r.ratePerKWh { rateText = String(format: "%.4f", rate) }
                }
            }
        }
    }

    private func saveBill() {
        let bill = EnergyBill(
            billingPeriodStart: billingStart,
            billingPeriodEnd: billingEnd,
            totalKWh: Double(totalKWhText) ?? 0,
            totalCost: Double(totalCostText) ?? 0,
            ratePerKWh: Double(rateText),
            utilityName: utilityName.isEmpty ? nil : utilityName,
            photoData: prefilledImage?.jpegData(compressionQuality: 0.7),
            rawOCRText: prefilledResult?.rawText
        )
        bill.home = home
        modelContext.insert(bill)
        home.updatedAt = Date()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onComplete?()
        dismiss()
    }
}
