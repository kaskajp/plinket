import SwiftUI

/// Collects server address and credentials, and signs in once the server accepts them.
struct LoginView: View {
    @Environment(AppModel.self) private var appModel
    @State private var serverAddress = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Server", text: $serverAddress, prompt: Text("music.example.com"))
                    .serverAddressInput()
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .credentialInput()
                SecureField("Password", text: $password)
                    .textContentType(.password)
            } header: {
                Text("Navidrome Server")
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            Section {
                Button(action: signIn) {
                    if isSigningIn {
                        ProgressView()
                    } else {
                        Text("Sign In")
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 480)
        .onSubmit(signIn)
    }

    private var canSubmit: Bool {
        !isSigningIn && !serverAddress.isEmpty && !username.isEmpty && !password.isEmpty
    }

    private func signIn() {
        guard canSubmit else { return }
        isSigningIn = true
        errorMessage = nil
        Task {
            defer { isSigningIn = false }
            do {
                try await appModel.signIn(serverAddress: serverAddress, username: username, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private extension View {
    func serverAddressInput() -> some View {
        #if os(iOS)
        credentialInput()
            .keyboardType(.URL)
            .textContentType(.URL)
        #else
        credentialInput()
        #endif
    }

    func credentialInput() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        autocorrectionDisabled()
        #endif
    }
}
