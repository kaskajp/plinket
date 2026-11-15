import SwiftUI

/// Matches the native launch screen while the saved library and queue are restored.
struct SplashView: View {
    var body: some View {
        // The logo's built-in padding keeps the visible mark clear of the title even when their frames overlap.
        VStack(spacing: -16) {
            Image("Logo")
                .resizable()
                .frame(width: 128, height: 128)
                .accessibilityHidden(true)
            Text("Plinket")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("SplashBackground"))
        .ignoresSafeArea()
    }
}
