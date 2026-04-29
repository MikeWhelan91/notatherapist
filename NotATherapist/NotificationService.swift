import Foundation
import SwiftUI
import UIKit
import UserNotifications

enum ReminderWeekday: Int, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        }
    }
}

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isWeeklyReminderEnabled: Bool
    @Published private(set) var weeklyReminderWeekday: Int
    @Published private(set) var weeklyReminderTime: Date

    private let center = UNUserNotificationCenter.current()
    private let weeklyReviewIdentifier = "weekly-review-check-in"
    private let enabledKey = "weeklyReviewReminderEnabled"
    private let weekdayKey = "weeklyReviewReminderWeekday"
    private let hourKey = "weeklyReviewReminderHour"
    private let minuteKey = "weeklyReviewReminderMinute"

    private init() {
        let defaults = UserDefaults.standard
        isWeeklyReminderEnabled = defaults.bool(forKey: enabledKey)
        let savedWeekday = defaults.integer(forKey: weekdayKey)
        weeklyReminderWeekday = savedWeekday == 0 ? ReminderWeekday.sunday.rawValue : savedWeekday
        let hour = defaults.object(forKey: hourKey) == nil ? 18 : defaults.integer(forKey: hourKey)
        let minute = defaults.integer(forKey: minuteKey)
        weeklyReminderTime = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }

    var authorizationLabel: String {
        switch authorizationStatus {
        case .authorized: "Allowed"
        case .provisional: "Quietly allowed"
        case .ephemeral: "Allowed for now"
        case .denied: "Off"
        case .notDetermined: "Not asked"
        @unknown default: "Unknown"
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        if settings.authorizationStatus == .denied {
            isWeeklyReminderEnabled = false
            UserDefaults.standard.set(false, forKey: enabledKey)
        }
    }

    func setWeeklyReminderEnabled(_ enabled: Bool) async {
        if enabled {
            do {
                let granted = try await requestAuthorizationIfNeeded()
                guard granted else {
                    isWeeklyReminderEnabled = false
                    UserDefaults.standard.set(false, forKey: enabledKey)
                    return
                }
                try await scheduleWeeklyReviewReminder()
                isWeeklyReminderEnabled = true
                UserDefaults.standard.set(true, forKey: enabledKey)
            } catch {
                isWeeklyReminderEnabled = false
                UserDefaults.standard.set(false, forKey: enabledKey)
            }
        } else {
            cancelWeeklyReviewReminder()
            isWeeklyReminderEnabled = false
            UserDefaults.standard.set(false, forKey: enabledKey)
        }
    }

    func updateWeeklyReminderWeekday(_ weekday: Int) async {
        weeklyReminderWeekday = weekday
        UserDefaults.standard.set(weekday, forKey: weekdayKey)

        if isWeeklyReminderEnabled {
            try? await scheduleWeeklyReviewReminder()
        }
    }

    func updateWeeklyReminderTime(_ time: Date) async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        weeklyReminderTime = time
        UserDefaults.standard.set(components.hour ?? 18, forKey: hourKey)
        UserDefaults.standard.set(components.minute ?? 0, forKey: minuteKey)

        if isWeeklyReminderEnabled {
            try? await scheduleWeeklyReviewReminder()
        }
    }

    private func requestAuthorizationIfNeeded() async throws -> Bool {
        await refreshAuthorizationStatus()

        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        @unknown default:
            return false
        }
    }

    private func scheduleWeeklyReviewReminder() async throws {
        cancelWeeklyReviewReminder()

        let content = UNMutableNotificationContent()
        content.title = "Weekly review is ready"
        content.body = "I noticed a few patterns. Start a short check-in."
        content.sound = .default
        content.userInfo = ["route": "weeklyCheckIn"]

        var components = DateComponents()
        components.weekday = weeklyReminderWeekday
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: weeklyReminderTime)
        components.hour = timeComponents.hour ?? 18
        components.minute = timeComponents.minute ?? 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: weeklyReviewIdentifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    private func cancelWeeklyReviewReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [weeklyReviewIdentifier])
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

final class AppNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.content.userInfo["route"] as? String == "weeklyCheckIn" else {
            return
        }

        await MainActor.run {
            AppRouter.shared.openWeeklyCheckIn()
        }
    }
}
