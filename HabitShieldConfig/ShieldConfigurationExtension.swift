import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Customizes the shield UI shown when a user tries to open a blocked app
/// NOTE: Class name must match NSExtensionPrincipalClass in Info.plist
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private static let appGroupID = "group.com.incept5.SeedBed"

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(appName: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(appName: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(appName: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(appName: webDomain.domain)
    }

    // MARK: - Shared Configuration

    private func makeConfiguration(appName: String?) -> ShieldConfiguration {
        let displayName = appName ?? "This app"

        // Check if there are failure-blocked habits (Don't-Do limit exceeded)
        let failureInfo = loadFailureBlockedHabitInfo()
        if !failureInfo.isEmpty {
            return makeFailureConfiguration(displayName: displayName, habitInfo: failureInfo)
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .extraLight,
            backgroundColor: UIColor(red: 253/255, green: 248/255, blue: 231/255, alpha: 1.0),
            icon: UIImage(named: "IconNoBg"),
            title: ShieldConfiguration.Label(
                text: "Sorry, \(displayName) is blocked\u{1F512}",
                color: UIColor(red: 30/255, green: 42/255, blue: 74/255, alpha: 1.0)
            ),
            subtitle: ShieldConfiguration.Label(
                text: "\(displayName) can wait. Open up sown to see what you should be prioritising right now or unblock your apps for 5 mins.",
                color: UIColor(red: 140/255, green: 140/255, blue: 140/255, alpha: 1.0)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open Sown \u{1F331}",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 212/255, green: 160/255, blue: 40/255, alpha: 1.0),
            secondaryButtonLabel: nil
        )
    }

    /// Shield configuration for failure-blocked apps (Don't-Do limit exceeded)
    private func makeFailureConfiguration(displayName: String, habitInfo: [[String: Any]]) -> ShieldConfiguration {
        let habitNames = habitInfo.compactMap { $0["habitName"] as? String }

        var subtitle: String
        if let firstName = habitNames.first {
            subtitle = "You slipped on '\(firstName)'. \(displayName) is blocked until midnight. Open Sown to go through the unlock flow."
        } else {
            subtitle = "You exceeded a screen time limit. \(displayName) is blocked until midnight. Open Sown to go through the unlock flow."
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .extraLight,
            backgroundColor: UIColor(red: 253/255, green: 235/255, blue: 235/255, alpha: 1.0),
            icon: UIImage(named: "IconNoBg"),
            title: ShieldConfiguration.Label(
                text: "Habit slipped \u{1F625}",
                color: UIColor(red: 180/255, green: 50/255, blue: 50/255, alpha: 1.0)
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: UIColor(red: 120/255, green: 80/255, blue: 80/255, alpha: 1.0)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open Sown \u{1F331}",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 180/255, green: 50/255, blue: 50/255, alpha: 1.0),
            secondaryButtonLabel: nil
        )
    }

    /// Load failure-blocked habit info from shared defaults
    private func loadFailureBlockedHabitInfo() -> [[String: Any]] {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        return defaults?.array(forKey: "failureBlockedHabitInfo") as? [[String: Any]] ?? []
    }
}
