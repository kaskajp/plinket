import Feedback
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Collects an explicit report and optional screenshots before sending it to Linear triage.
struct ReportProblemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var screenshots: [ReportScreenshot] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var importsFiles = false
    @State private var isLoadingImages = false
    @State private var isSubmitting = false
    @State private var isSent = false
    @State private var errorMessage: String?
    @State private var confirmsDiscard = false
    @State private var reportID = UUID()

    private var report: ProblemReport {
        ProblemReport(
            id: reportID, title: title, details: details,
            appVersion: AppInfo.versionDescription,
            platform: platform,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            locale: Locale.current.identifier,
            screenshots: screenshots.map(\.data)
        )
    }

    private var platform: String {
        #if os(iOS)
        "iOS"
        #else
        "macOS"
        #endif
    }

    var body: some View {
        Group {
            if isSent {
                ContentUnavailableView("Report Sent", systemImage: "checkmark.circle", description: Text("Thank you. Your report has been sent to the developer for review."))
            } else {
                form
            }
        }
        .navigationTitle("Report a Problem")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(isSent ? "Done" : "Cancel") {
                    if isSent || (title.isEmpty && details.isEmpty && screenshots.isEmpty) {
                        dismiss()
                    } else {
                        confirmsDiscard = true
                    }
                }
                .disabled(isSubmitting || isLoadingImages)
            }
            if !isSent {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send", action: submit)
                        .disabled(!report.isValid || isSubmitting || isLoadingImages || AppInfo.feedbackURL == nil)
                }
            }
        }
        .interactiveDismissDisabled(!isSent)
        .confirmationDialog("Discard this report?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Discard Report", role: .destructive) { dismiss() }
        }
        .fileImporter(isPresented: $importsFiles, allowedContentTypes: [.png, .jpeg], allowsMultipleSelection: true) { result in
            loadFiles(result)
        }
        .task(id: selectedPhotos) {
            guard !selectedPhotos.isEmpty else { return }
            isLoadingImages = true
            defer {
                isLoadingImages = false
                selectedPhotos = []
            }
            do {
                var additions: [ReportScreenshot] = []
                for photo in selectedPhotos {
                    guard let data = try await photo.loadTransferable(type: Data.self) else {
                        throw ScreenshotError.unreadable
                    }
                    additions.append(try ReportScreenshot(data: data))
                }
                try addScreenshots(additions)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .onChange(of: title) { _, _ in reportID = UUID() }
        .onChange(of: details) { _, _ in reportID = UUID() }
        .onChange(of: screenshots.map(\.id)) { _, _ in reportID = UUID() }
    }

    private var form: some View {
        Form {
            Section("Problem") {
                TextField("Summary", text: $title)
                TextField("What happened? What did you expect?", text: $details, axis: .vertical)
                    .lineLimit(5...10)
                if title.unicodeScalars.count > ProblemReport.maximumTitleLength || details.unicodeScalars.count > ProblemReport.maximumDetailsLength {
                    Text("Keep the summary under 200 characters and the description under 10,000 characters.")
                        .foregroundStyle(.red)
                }
            }
            Section {
                ForEach(screenshots) { screenshot in
                    HStack {
                        Image(decorative: screenshot.image, scale: 1)
                            .resizable().scaledToFit().frame(width: 72, height: 72)
                        Text("Screenshot")
                        Spacer()
                        Button(role: .destructive) {
                            screenshots.removeAll { $0.id == screenshot.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Remove Screenshot")
                    }
                }
                if screenshots.count < ProblemReport.maximumScreenshots {
                    #if os(iOS)
                    PhotosPicker(selection: $selectedPhotos,
                                 maxSelectionCount: ProblemReport.maximumScreenshots - screenshots.count,
                                 matching: .images) {
                        Label("Choose Screenshots", systemImage: "photo.on.rectangle")
                    }
                    #endif
                    Button {
                        importsFiles = true
                    } label: {
                        Label("Attach Image Files", systemImage: "paperclip")
                    }
                }
                if isLoadingImages { ProgressView("Preparing screenshots…") }
            } header: {
                Text("Screenshots (optional)")
            } footer: {
                Text("Attach up to three screenshots. Images are resized before sending. Check them for private information.")
            }
            Section {
                Text("Your summary, description, chosen screenshots, app version, operating system and language are sent to the developer’s Linear issue tracker. Music server addresses, passwords and listening history are not included automatically.")
                    .font(.footnote)
                Link("Privacy Policy", destination: AppInfo.privacyPolicyURL)
                if AppInfo.feedbackURL == nil {
                    Text(FeedbackError.unavailable.localizedDescription)
                        .foregroundStyle(.red)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("reportError")
                }
                if isSubmitting { ProgressView("Sending report…") }
            }
        }
        .formStyle(.grouped)
        .disabled(isSubmitting || isLoadingImages)
    }

    private func submit() {
        guard !isSubmitting, !isLoadingImages, let endpoint = AppInfo.feedbackURL else { return }
        let report = report
        isSubmitting = true
        errorMessage = nil
        Task {
            defer { isSubmitting = false }
            do {
                try await FeedbackClient(endpoint: endpoint).submit(report)
                isSent = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func addScreenshots(_ additions: [ReportScreenshot]) throws {
        guard screenshots.count + additions.count <= ProblemReport.maximumScreenshots else {
            throw ScreenshotError.tooMany
        }
        screenshots.append(contentsOf: additions)
        errorMessage = nil
    }

    private func loadFiles(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard urls.count + screenshots.count <= ProblemReport.maximumScreenshots else {
                throw ScreenshotError.tooMany
            }
            let additions = try urls.map { url in
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= ReportScreenshot.maximumInputBytes else { throw ScreenshotError.tooLarge }
                return try ReportScreenshot(data: Data(contentsOf: url))
            }
            try addScreenshots(additions)
        } catch let error as CocoaError where error.code == .userCancelled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
