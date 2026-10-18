import SwiftUI

/// The app's icon, version and description, with a link to its GitHub page.
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
                Link(destination: AppInfo.repositoryURL) {
                    Label("Plinket on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
