import SwiftUI

struct SettingsView: View {
    @ObservedObject var loginItemService: LoginItemService
    @ObservedObject var viewModel: TranslationViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Start at Login", isOn: Binding(
                    get: { loginItemService.isEnabled },
                    set: { loginItemService.setEnabled($0) }
                ))

                Text(loginItemService.statusDescription)
                    .foregroundStyle(.secondary)

                if let lastError = loginItemService.lastError {
                    Text(lastError)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            Section {
                TextField("Ollama Model", text: $viewModel.model)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text(SelectionCaptureService.isAccessibilityTrusted ? "Accessibility permission granted" : "Accessibility permission missing")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Request") {
                        SelectionCaptureService.requestAccessibilityPermission()
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 440, height: 280)
    }
}
