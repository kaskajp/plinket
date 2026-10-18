import SwiftUI

/// The app's icon, version and description, with links to its website and privacy policy.
struct AboutView: View {
    private let logoSize: CGFloat = 88

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    AppLogo(size: logoSize)
                        .padding(.bottom, 4)
                    Text("Plinket")
                        .font(.title.bold())
                    Text(AppInfo.versionDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(AppInfo.summary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }
            Section {
                Link(destination: AppInfo.websiteURL) {
                    Label("Visit Website", systemImage: "globe")
                }
                Link(destination: AppInfo.privacyPolicyURL) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
