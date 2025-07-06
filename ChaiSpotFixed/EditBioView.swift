import SwiftUI
import FirebaseFirestore

struct EditBioView: View {
    var user: UserProfile
    var onSave: (String) -> Void

    @State private var bioText: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
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
                        onSave(bioText)
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
                bioText = user.bio ?? ""
            }
        }
    }
}
