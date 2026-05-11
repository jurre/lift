import Foundation
import UserNotifications

@MainActor
struct NotificationAuthorizationCoordinator {
    private let center: UNUserNotificationCenter
    private let userDefaults: UserDefaults
    private let hasRequestedKey = "hasRequestedNotificationAuthorization"

    init(
        center: UNUserNotificationCenter = .current(),
        userDefaults: UserDefaults = .standard
    ) {
        self.center = center
        self.userDefaults = userDefaults
    }

    func requestIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        guard userDefaults.bool(forKey: hasRequestedKey) == false else { return }

        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        userDefaults.set(true, forKey: hasRequestedKey)
    }
}
