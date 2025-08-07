import SwiftUI
import FirebaseAuth

struct EditBioView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var bio: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Bio")
                .font(.title)
                .bold()

            TextField("Your bio", text: $bio)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Save") {
                Task {
                    await sessionStore.updateBio(to: bio)
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
            bio = sessionStore.userProfile?.bio ?? ""
        }
    }
}
