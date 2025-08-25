import SwiftUI

struct DebugMigrationView: View {
    @ObservedObject var feedViewModel: FeedViewModel
    @State private var isMigrating = false
    @State private var migrationMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🔧 Debug & Migration Tools")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This view helps fix the feed switching issue by migrating your existing ratings data to include visibility and deleted fields.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("What this does:")
                    .font(.headline)
                
                Text("• Adds 'visibility: \"public\"' to old ratings")
                Text("• Adds 'deleted: false' to old ratings")
                Text("• Enables proper filtering for friends/community views")
                Text("• Fixes the 'error unable to load' issue")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Button(action: {
                triggerMigration()
            }) {
                HStack {
                    if isMigrating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(isMigrating ? "Migrating..." : "Start Data Migration")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isMigrating ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isMigrating)
            
            if !migrationMessage.isEmpty {
                Text(migrationMessage)
                    .font(.caption)
                    .foregroundColor(migrationMessage.contains("✅") ? .green : .red)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Debug Tools")
    }
    
    private func triggerMigration() {
        isMigrating = true
        migrationMessage = "🔄 Starting data migration..."
        
        feedViewModel.triggerDataMigration()
        
        // Set up a timer to check migration status
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            if !feedViewModel.isLoading {
                timer.invalidate()
                isMigrating = false
                migrationMessage = "✅ Migration completed! Your feed switching should now work properly."
            }
        }
    }
}

#Preview {
    DebugMigrationView(feedViewModel: FeedViewModel())
}
