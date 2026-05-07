import Foundation
import FirebaseCore
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
    @Published private(set) var isDailyReminderEnabled: Bool
    @Published private(set) var dailyReminderTime: Date
    @Published private(set) var isWeeklyReminderEnabled: Bool
    @Published private(set) var weeklyReminderWeekday: Int
    @Published private(set) var weeklyReminderTime: Date

    private let center = UNUserNotificationCenter.current()
    private let dailyReminderIdentifier = "daily-mood-log-reminder"
    private let weeklyReviewIdentifier = "weekly-review-check-in"
    private let dailyReminderCategoryIdentifier = "daily-log-actions"
    private let weeklyReviewCategoryIdentifier = "weekly-review-actions"
    private let actionLogNow = "daily-action-log-now"
    private let actionStartCheckIn = "weekly-action-start-check-in"
    private let actionReviewToday = "weekly-action-review-today"
    private let dailyEnabledKey = "dailyReminderEnabled"
    private let dailyHourKey = "dailyReminderHour"
    private let dailyMinuteKey = "dailyReminderMinute"
    private let dailyCustomizedKey = "dailyReminderCustomizedByUser"
    private let enabledKey = "weeklyReviewReminderEnabled"
    private let weekdayKey = "weeklyReviewReminderWeekday"
    private let hourKey = "weeklyReviewReminderHour"
    private let minuteKey = "weeklyReviewReminderMinute"

    private init() {
        let defaults = UserDefaults.standard
        isDailyReminderEnabled = defaults.bool(forKey: dailyEnabledKey)
        let dailyHour = defaults.object(forKey: dailyHourKey) == nil ? 22 : defaults.integer(forKey: dailyHourKey)
        let dailyMinute = defaults.integer(forKey: dailyMinuteKey)
        dailyReminderTime = Calendar.current.date(from: DateComponents(hour: dailyHour, minute: dailyMinute)) ?? Date()
        isWeeklyReminderEnabled = defaults.bool(forKey: enabledKey)
        let savedWeekday = defaults.integer(forKey: weekdayKey)
        weeklyReminderWeekday = savedWeekday == 0 ? ReminderWeekday.sunday.rawValue : savedWeekday
        let hour = defaults.object(forKey: hourKey) == nil ? 18 : defaults.integer(forKey: hourKey)
        let minute = defaults.integer(forKey: minuteKey)
        weeklyReminderTime = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        registerNotificationCategories()
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
            isDailyReminderEnabled = false
            UserDefaults.standard.set(false, forKey: dailyEnabledKey)
            isWeeklyReminderEnabled = false
            UserDefaults.standard.set(false, forKey: enabledKey)
        }
    }

    func setDailyReminderEnabled(_ enabled: Bool) async {
        if enabled {
            do {
                let granted = try await requestAuthorizationIfNeeded()
                guard granted else {
                    isDailyReminderEnabled = false
                    UserDefaults.standard.set(false, forKey: dailyEnabledKey)
                    return
                }
                try await scheduleDailyReminder()
                isDailyReminderEnabled = true
                UserDefaults.standard.set(true, forKey: dailyEnabledKey)
            } catch {
                isDailyReminderEnabled = false
                UserDefaults.standard.set(false, forKey: dailyEnabledKey)
            }
        } else {
            cancelDailyReminder()
            isDailyReminderEnabled = false
            UserDefaults.standard.set(false, forKey: dailyEnabledKey)
        }
    }

    func updateDailyReminderTime(_ time: Date) async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        dailyReminderTime = time
        UserDefaults.standard.set(components.hour ?? 22, forKey: dailyHourKey)
        UserDefaults.standard.set(components.minute ?? 0, forKey: dailyMinuteKey)
        UserDefaults.standard.set(true, forKey: dailyCustomizedKey)

        if isDailyReminderEnabled {
            try? await scheduleDailyReminder()
        }
    }

    func applyOnboardingCheckInPreference(_ preference: String, enableReminder: Bool = true) async {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: dailyCustomizedKey) == false {
            let mapped = mappedReminderTime(for: preference)
            dailyReminderTime = mapped
            let components = Calendar.current.dateComponents([.hour, .minute], from: mapped)
            defaults.set(components.hour ?? 21, forKey: dailyHourKey)
            defaults.set(components.minute ?? 0, forKey: dailyMinuteKey)
        }

        if enableReminder {
            await setDailyReminderEnabled(true)
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
        content.body = "Your weekly review is ready. Start a short check-in."
        content.sound = .default
        content.categoryIdentifier = weeklyReviewCategoryIdentifier
        content.userInfo = ["route": "weeklyCheckIn"]

        var components = DateComponents()
        components.calendar = Calendar.current
        components.timeZone = TimeZone.current
        components.weekday = weeklyReminderWeekday
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: weeklyReminderTime)
        components.hour = timeComponents.hour ?? 18
        components.minute = timeComponents.minute ?? 0
        components.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: weeklyReviewIdentifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    private func scheduleDailyReminder() async throws {
        cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = "Log your mood"
        content.body = "Take a minute to log how today felt."
        content.sound = .default
        content.categoryIdentifier = dailyReminderCategoryIdentifier
        content.userInfo = ["route": "dailyLog"]

        var components = DateComponents()
        components.calendar = Calendar.current
        components.timeZone = TimeZone.current
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: dailyReminderTime)
        components.hour = timeComponents.hour ?? 22
        components.minute = timeComponents.minute ?? 0
        components.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderIdentifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    private func cancelWeeklyReviewReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [weeklyReviewIdentifier])
    }

    private func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func registerNotificationCategories() {
        let logNow = UNNotificationAction(
            identifier: actionLogNow,
            title: "Log now",
            options: [.foreground]
        )
        let startCheckIn = UNNotificationAction(
            identifier: actionStartCheckIn,
            title: "Start check-in",
            options: [.foreground]
        )
        let reviewToday = UNNotificationAction(
            identifier: actionReviewToday,
            title: "Review today",
            options: [.foreground]
        )
        let weeklyCategory = UNNotificationCategory(
            identifier: weeklyReviewCategoryIdentifier,
            actions: [startCheckIn, reviewToday],
            intentIdentifiers: [],
            options: []
        )
        let dailyCategory = UNNotificationCategory(
            identifier: dailyReminderCategoryIdentifier,
            actions: [logNow],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([weeklyCategory, dailyCategory])
    }

    private func mappedReminderTime(for preference: String) -> Date {
        let normalized = preference.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hour: Int
        switch normalized {
        case "morning":
            hour = 9
        case "afternoon":
            hour = 14
        case "night":
            hour = 21
        case "evening":
            fallthrough
        default:
            hour = 19
        }
        return Calendar.current.date(from: DateComponents(hour: hour, minute: 0)) ?? Date()
    }
}

final class AppNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
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
        await MainActor.run {
            switch response.notification.request.content.userInfo["route"] as? String {
            case "weeklyCheckIn":
                switch response.actionIdentifier {
                case "weekly-action-review-today":
                    AppRouter.shared.runDailyReview()
                case "weekly-action-start-check-in", UNNotificationDefaultActionIdentifier:
                    AppRouter.shared.openWeeklyCheckIn()
                default:
                    break
                }
            case "dailyLog":
                switch response.actionIdentifier {
                case "daily-action-log-now", UNNotificationDefaultActionIdentifier:
                    AppRouter.shared.openNewQuickThought()
                default:
                    break
                }
            default:
                break
            }
        }
    }
}
