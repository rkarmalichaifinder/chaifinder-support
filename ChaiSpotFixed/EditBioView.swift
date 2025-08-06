import SwiftUI

struct EditBioView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var bioText: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Bio")) {
                    TextEditor(text: $bioText)
                        .frame(height: 150)
                }
            }
            .navigationTitle("Edit Bio")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBio()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                bioText = sessionStore.user?.bio ?? ""
            }
        }
    }
    
    private func saveBio() {
        guard var updatedUser = sessionStore.user else { return }
        updatedUser.bio = bioText
        sessionStore.updateUserProfile(updatedUser)
    }
}
