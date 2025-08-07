import SwiftUI
import FirebaseAuth

struct EditNameView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var displayName: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Name")
                .font(.title)
                .bold()

            TextField("Your name", text: $displayName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Save") {
                Task {
                    await sessionStore.updateDisplayName(to: displayName)
                    dismiss()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(10)

            Spacer()
        }
        .padding()
        .onAppear {
            displayName = sessionStore.userProfile?.displayName ?? ""
        }
    }
} 