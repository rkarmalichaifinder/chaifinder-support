import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var hasAcceptedTerms: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms of Service & User Agreement")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Group {
                        Text("Welcome to Chai Finder!")
                            .font(.headline)
                        
                        Text("By using Chai Finder, you agree to these terms and conditions. Please read them carefully.")
                            .font(.body)
                        
                        Text("1. User-Generated Content")
                            .font(.headline)
                            .padding(.top, 10)
                        
                        Text("Chai Finder allows users to submit chai spots, ratings, reviews, and comments. All content must be appropriate and respectful.")
                            .font(.body)
                        
                        Text("2. Zero-Tolerance Policy for Objectionable Content")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("We have a ZERO-TOLERANCE policy for objectionable content. This includes but is not limited to:")
                            .font(.body)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Hate speech, discrimination, or harassment")
                            Text("• Profanity, vulgar language, or inappropriate content")
                            Text("• Spam, misleading information, or fake reviews")
                            Text("• Personal attacks or bullying")
                            Text("• Sexual content or nudity")
                            Text("• Violence or threats")
                            Text("• Illegal activities or drug references")
                        }
                        .font(.body)
                        .padding(.leading, 20)
                        
                        Text("3. Content Moderation")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• All user-generated content is subject to review")
                            Text("• Users can report inappropriate content")
                            Text("• We will remove objectionable content within 24 hours")
                            Text("• Users who violate these terms will be banned")
                        }
                        .font(.body)
                        .padding(.leading, 20)
                        
                        Text("4. User Responsibilities")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• You are responsible for all content you submit")
                            Text("• You must be 13 years or older to use this app")
                            Text("• You must provide accurate and truthful information")
                            Text("• You must respect other users and their privacy")
                        }
                        .font(.body)
                        .padding(.leading, 20)
                        
                        Text("5. Reporting and Blocking")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• You can report inappropriate content or users")
                            Text("• You can block users who are harassing you")
                            Text("• All reports are reviewed within 24 hours")
                            Text("• False reports may result in account suspension")
                        }
                        .font(.body)
                        .padding(.leading, 20)
                        
                        Text("6. Consequences of Violations")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• First violation: Warning and content removal")
                            Text("• Second violation: Temporary suspension (7 days)")
                            Text("• Third violation: Permanent ban")
                            Text("• Severe violations: Immediate permanent ban")
                        }
                        .font(.body)
                        .padding(.leading, 20)
                        
                        Text("7. Contact Information")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("To report violations or appeal decisions:")
                            Text("Email: support@chaifinder.app")
                            Text("Instagram: @chaifinderapp")
                        }
                        .font(.body)
                        .padding(.leading, 20)
                        
                        Text("By accepting these terms, you acknowledge that you have read, understood, and agree to comply with all the above conditions.")
                            .font(.body)
                            .fontWeight(.semibold)
                            .padding(.top, 20)
                    }
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Decline") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Accept") {
                        hasAcceptedTerms = true
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
} 