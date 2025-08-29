import SwiftUI

struct ReportContentView: View {
    let contentId: String
    let contentType: ContentType
    let contentPreview: String
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var moderationService = ContentModerationService()
    @State private var selectedReason: ReportReason = .inappropriate
    @State private var additionalDetails: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Content Being Reported")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type: \(contentType.rawValue.capitalized)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(contentPreview)
                            .font(.body)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                Section(header: Text("Reason for Report")) {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            Text(reason.displayName).tag(reason)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Additional Details (Optional)")) {
                    TextEditor(text: $additionalDetails)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                
                Section {
                    Button(action: submitReport) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isSubmitting ? "Submitting..." : "Submit Report")
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Report Submitted", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for your report. We will review it within 24 hours.")
            }
            .keyboardDismissible()
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        
        moderationService.reportContent(
            contentId: contentId,
            contentType: contentType,
            reason: selectedReason,
            additionalDetails: additionalDetails.isEmpty ? nil : additionalDetails
        )
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: DispatchWorkItem {
            isSubmitting = false
            showSuccess = true
        })
    }
} 