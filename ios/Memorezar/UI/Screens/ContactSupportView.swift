import SwiftUI

struct ContactSupportView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var reason: SupportReason = .featureRequest
    @State private var message = ""
    @State private var email = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Reason", selection: $reason) {
                        ForEach(SupportReason.allCases) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                } header: {
                    Text("What's this about?")
                }

                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Your Email")
                } footer: {
                    Text("So we can get back to you.")
                }

                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                } header: {
                    Text("Message")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submitTicket()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Send")
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
            .alert("Message Sent!", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Thanks for reaching out. We'll get back to you soon.")
            }
            .onAppear {
                if let userEmail = authService.currentUser?.email {
                    email = userEmail
                }
            }
        }
    }

    private var isValid: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.contains("@")
    }

    private func submitTicket() {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await SupportTicketService.shared.submitTicket(
                    reason: reason,
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = String(localized: "Failed to send. Please try again.")
                }
            }
        }
    }
}
