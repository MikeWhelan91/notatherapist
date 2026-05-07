import FirebaseAnalytics

enum AnalyticsService {
    static func logScreen(_ name: String, screenClass: String) {
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: name,
                AnalyticsParameterScreenClass: screenClass
            ]
        )
    }
}
