import SwiftUI

struct TranslatorView: View {
    @ObservedObject var viewModel: TranslationViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(spacing: 0) {
                historyList
                    .frame(width: 220)
                Divider()
                translationContent
            }
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe.asia.australia")
                .font(.title2)

            TextField("Model", text: $viewModel.model)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 190)

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                Task {
                    await viewModel.captureAndTranslate()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Translate")

            Button {
                Task {
                    await viewModel.rewriteCurrentSource()
                }
            } label: {
                Image(systemName: "wand.and.stars")
            }
            .help("Rewrite Source")
            .disabled(viewModel.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                Task {
                    await viewModel.replaceSelectionWithRewrite()
                }
            } label: {
                Image(systemName: "text.insert")
            }
            .help("Replace Selection")
            .disabled(!viewModel.canReplaceSelection)

            Button {
                viewModel.copyVietnameseToClipboard()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy Vietnamese")
            .disabled(viewModel.vietnameseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            if viewModel.historyService.items.isEmpty {
                Text("No recent clipboard text")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                Spacer()
            } else {
                List(viewModel.historyService.items, id: \.self) { item in
                    Button {
                        viewModel.translateHistoryItem(item)
                    } label: {
                        Text(item)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
            }
        }
    }

    private var translationContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !SelectionCaptureService.isAccessibilityTrusted {
                    permissionBanner
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                section(title: "Source", text: viewModel.sourceText, empty: "Selection or clipboard text appears here")

                switch viewModel.outputMode {
                case .rewrite:
                    section(title: "Rewritten", text: viewModel.rewriteText, empty: "Rewritten text streams here")
                case .translation:
                    section(title: "English", text: viewModel.englishText, empty: "Meaning and usage notes stream here")
                    section(title: "Vietnamese", text: viewModel.vietnameseText, empty: "Translation streams here")
                case .none:
                    EmptyView()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")
            Text("Accessibility permission is needed for selected-text capture. Clipboard fallback still works.")
                .lineLimit(2)
            Spacer()
            Button("Allow") {
                SelectionCaptureService.requestAccessibilityPermission()
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func section(title: String, text: String, empty: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            Text(text.isEmpty ? empty : text)
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
