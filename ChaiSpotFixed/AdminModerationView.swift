import SwiftUI
import FirebaseFirestore

struct AdminModerationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var moderationService = ContentModerationService()
    @State private var reports: [Report] = []
    @State private var isLoading = true
    @State private var selectedReport: Report?
    @State private var showingReportDetail = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading reports...")
                } else if reports.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("No Reports")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("All user-generated content is currently appropriate.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List(reports) { report in
                        ReportRow(report: report) {
                            selectedReport = report
                            showingReportDetail = true
                        }
                    }
                }
            }
            .navigationTitle("Content Moderation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingReportDetail) {
                if let report = selectedReport {
                    ReportDetailView(report: report) {
                        loadReports()
                    }
                }
            }
        }
        .onAppear {
            loadReports()
        }
        .navigationViewStyle(.stack)
    }
    
    private func loadReports() {
        isLoading = true
        moderationService.getReports { reports in
            DispatchQueue.main.async {
                self.reports = reports
                self.isLoading = false
            }
        }
    }
}

struct ReportRow: View {
    let report: Report
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(report.contentType.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text(report.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(report.reason.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if !report.additionalDetails.isEmpty {
                    Text(report.additionalDetails)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text("Status: \(report.status.displayName)")
                        .font(.caption)
                        .foregroundColor(statusColor)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusColor: Color {
        switch report.status {
        case .pending: return .orange
        case .reviewed: return .blue
        case .resolved: return .green
        case .dismissed: return .gray
        }
    }
}

struct ReportDetailView: View {
    let report: Report
    let onUpdate: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var moderationService = ContentModerationService()
    @State private var selectedStatus: ReportStatus
    @State private var adminNotes: String = ""
    @State private var isUpdating = false
    
    init(report: Report, onUpdate: @escaping () -> Void) {
        self.report = report
        self.onUpdate = onUpdate
        self._selectedStatus = State(initialValue: report.status)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Report Details")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Type:")
                                .fontWeight(.semibold)
                            Text(report.contentType.rawValue.capitalized)
                        }
                        
                        HStack {
                            Text("Reason:")
                                .fontWeight(.semibold)
                            Text(report.reason.displayName)
                        }
                        
                        HStack {
                            Text("Status:")
                                .fontWeight(.semibold)
                            Text(report.status.displayName)
                                .foregroundColor(statusColor)
                        }
                        
                        HStack {
                            Text("Reported:")
                                .fontWeight(.semibold)
                            Text(report.timestamp, style: .date)
                        }
                    }
                }
                
                Section(header: Text("Content Preview")) {
                    Text("Content ID: \(report.contentId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !report.additionalDetails.isEmpty {
                        Text(report.additionalDetails)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                Section(header: Text("Update Status")) {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(ReportStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    TextField("Admin Notes (Optional)", text: $adminNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button(action: updateReport) {
                        HStack {
                            if isUpdating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isUpdating ? "Updating..." : "Update Report")
                        }
                    }
                    .disabled(isUpdating)
                }
            }
            .navigationTitle("Report Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private var statusColor: Color {
        switch report.status {
        case .pending: return .orange
        case .reviewed: return .blue
        case .resolved: return .green
        case .dismissed: return .gray
        }
    }
    
    private func updateReport() {
        isUpdating = true
        
        moderationService.updateReportStatus(
            reportId: report.id,
            status: selectedStatus,
            adminNotes: adminNotes.isEmpty ? nil : adminNotes
        )
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isUpdating = false
            onUpdate()
            dismiss()
        }
    }
} 