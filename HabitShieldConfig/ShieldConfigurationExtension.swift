import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Customizes the shield UI shown when a user tries to open a blocked app
/// NOTE: Class name must match NSExtensionPrincipalClass in Info.plist
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

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

        return ShieldConfiguration(
            backgroundBlurStyle: .extraLight,
            backgroundColor: UIColor(red: 253/255, green: 248/255, blue: 231/255, alpha: 1.0), // paper color
            icon: UIImage(named: "IconNoBg"),
            title: ShieldConfiguration.Label(
                text: "Sorry, \(displayName) is blocked🔒",
                color: UIColor(red: 30/255, green: 42/255, blue: 74/255, alpha: 1.0) // inkBlack
            ),
            subtitle: ShieldConfiguration.Label(
                text: "\(displayName) can wait. Open up sown to see what you should be prioritising right now or unblock your apps for 5 mins.",
                color: UIColor(red: 140/255, green: 140/255, blue: 140/255, alpha: 1.0)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open Sown 🌱",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 212/255, green: 160/255, blue: 40/255, alpha: 1.0), // amber
            secondaryButtonLabel: nil
        )
    }
}
