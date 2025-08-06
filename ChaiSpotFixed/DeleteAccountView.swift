import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct DeleteAccountView: View {
    @Environment(\.dismiss) var dismiss
    @State private var errorMessage: String?
    @State private var isProcessing = false
    @State private var isDeleted = false

    var body: some View {
        VStack(spacing: 20) {
            if isDeleted {
                Text("Your account has been deleted.")
                Button("Close") {
                    dismiss()
                }
            } else {
                Text("Are you sure you want to delete your account?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if isProcessing {
                    ProgressView()
                } else {
                    Button("Delete My Account", role: .destructive) {
                        deleteAccount()
                    }
                }
                if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
    }

    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        isProcessing = true

        // Delete Firestore user doc
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).delete { error in
            if let error = error {
                self.errorMessage = "Failed to delete user data: \(error.localizedDescription)"
                self.isProcessing = false
                return
            }

            // Delete Firebase Auth user
            user.delete { error in
                isProcessing = false
                if let error = error {
                    self.errorMessage = "Failed to delete account: \(error.localizedDescription)"
                } else {
                    self.isDeleted = true
                }
            }
        }
    }
}
