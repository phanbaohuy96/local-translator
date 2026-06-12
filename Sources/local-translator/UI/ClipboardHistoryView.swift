import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @ObservedObject private var historyService: ClipboardHistoryService
    @State private var isAccessibilityTrusted = SelectionCaptureService.isAccessibilityTrusted

    private let permissionRefreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
        self.historyService = viewModel.historyService
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clipboard History")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            if !isAccessibilityTrusted {
                permissionBanner
                    .padding(.horizontal, 16)
            }

            if historyService.items.isEmpty {
                Text("No recent clipboard text")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                Spacer()
            } else {
                List(historyService.items, id: \.self) { item in
                    HStack(spacing: 8) {
                        Text(item)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            viewModel.copyHistoryItemToClipboard(item)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy Clipboard Text")
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 360, minHeight: 420)
        .onReceive(permissionRefreshTimer) { _ in
            isAccessibilityTrusted = SelectionCaptureService.isAccessibilityTrusted
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")

            Text("Accessibility permission is needed for selected-text capture.")
                .lineLimit(2)

            Spacer()

            Button("Allow") {
                SelectionCaptureService.requestAccessibilityPermission()
                isAccessibilityTrusted = SelectionCaptureService.isAccessibilityTrusted
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
