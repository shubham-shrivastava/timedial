import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class LoginItemManager: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published var lastErrorMessage: String?

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        lastErrorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastErrorMessage = "Unable to update login item setting. Please check System Settings → General → Login Items."
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
