import SwiftUI
import FacebookCore

/// User privacy choices, stored on device.
enum URPrivacyPreferences {
    static let usageAnalyticsKey = "ur.privacy.usageAnalyticsEnabled"
    static let metaMeasurementKey = "ur.privacy.metaMeasurementConsent"

    /// First-party product analytics (app_first_open / app_open) sent to UR's own backend. On unless the user turns it off.
    static var usageAnalyticsEnabled: Bool {
        UserDefaults.standard.object(forKey: usageAnalyticsKey) as? Bool ?? true
    }

    /// Optional Meta ad measurement. Off until the user opts in.
    static var metaMeasurementConsent: Bool {
        UserDefaults.standard.bool(forKey: metaMeasurementKey)
    }
}

/// Controls the Meta SDK. The SDK is never initialized (and makes no network calls) unless
/// the build has a client token, the build enables Meta app events, and the user has opted in.
/// Advertiser-ID collection is always off and the app never requests ATT.
@MainActor
enum URMetaMeasurement {
    private static var initialized = false

    /// True when this build is allowed to offer Meta measurement at all.
    static var isAvailableInBuild: Bool {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "FacebookClientToken") as? String,
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !token.hasPrefix("$("),
              token != "paste_client_token_here" else { return false }
        return (Bundle.main.object(forInfoDictionaryKey: "URMetaAppEventsEnabled") as? String)?.uppercased() == "YES"
    }

    static func configureAtLaunch(_ application: UIApplication,
                                  launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard isAvailableInBuild, URPrivacyPreferences.metaMeasurementConsent else { return }
        applySettings(eventsEnabled: true)
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        AppEvents.shared.flushBehavior = .auto
        initialized = true
    }

    /// Applies a consent change made in the app. Opting in starts the SDK and records activation.
    /// Opting out stops event logging and sending at once and discards queued events; the SDK
    /// cannot be shut down mid-session, so it is fully inactive from the next launch.
    static func setConsent(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: URPrivacyPreferences.metaMeasurementKey)
        if !granted { resetAnonymousID() }
        guard isAvailableInBuild else { return }
        if granted {
            // Never send events that were queued before an earlier opt-out.
            _AppEventsStateManager.shared.clearPersistedAppEventsStates()
            applySettings(eventsEnabled: true)
            if !initialized {
                ApplicationDelegate.shared.initializeSDK()
                initialized = true
            }
            AppEvents.shared.flushBehavior = .auto
            AppEvents.shared.activateApp()
        } else if initialized {
            applySettings(eventsEnabled: false)
            AppEvents.shared.flushBehavior = .explicitOnly
            _AppEventsStateManager.shared.clearPersistedAppEventsStates()
            AppEvents.shared.clearUserData()
            AppEvents.shared.userID = nil
        }
    }

    /// File where SDK 18.x keeps its random `anon_id` (FBSDKBasicUtility, Library directory).
    /// The SDK re-reads it on every use, so deleting it gives a fresh ID if the user opts in again.
    static let anonymousIDFileName = "com-facebook-sdk-PersistedAnonymousID.json"

    static func resetAnonymousID() {
        guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }
        try? FileManager.default.removeItem(at: library.appendingPathComponent(anonymousIDFileName))
    }

    // Runtime values persist, and SDK 18.x can let Events Manager override the Info.plist default,
    // so both are set explicitly whenever the SDK is used.
    private static func applySettings(eventsEnabled: Bool) {
        Settings.shared.isAdvertiserIDCollectionEnabled = false
        Settings.shared.isAutoLogAppEventsEnabled = eventsEnabled
    }
}

struct URPrivacySettingsView: View {
    @AppStorage(URPrivacyPreferences.usageAnalyticsKey) private var usageAnalytics = true
    @AppStorage(URPrivacyPreferences.metaMeasurementKey) private var metaMeasurement = false

    var body: some View {
        Form {
            Section {
                Toggle("مشاركة بيانات الاستخدام مع أور", isOn: $usageAnalytics)
            } footer: {
                Text("أحداث فتح التطبيق مع معرّف تثبيت عشوائي، لتحسين الخدمة. لا تتضمن مبالغ أو كلمات مرور أو بيانات بنكية.")
            }
            if URMetaMeasurement.isAvailableInBuild {
                Section {
                    Toggle("قياس الإعلانات عبر Meta", isOn: Binding(
                        get: { metaMeasurement },
                        set: { metaMeasurement = $0; URMetaMeasurement.setConsent($0) }
                    ))
                } footer: {
                    Text("عند التفعيل نرسل إلى Meta أحداث تشغيل التطبيق وبيانات تقنية عن الجهاز لقياس أداء إعلانات تثبيت التطبيق. لا نستخدم معرّف الإعلانات ولا نرسل بيانات الحوالات أو الحساب. يمكنك الإيقاف في أي وقت.")
                }
            }
            Section {
                Link("سياسة الخصوصية", destination: URL(string: "https://urremit.com/privacy")!)
            }
        }
        .navigationTitle("إعدادات الخصوصية")
        .environment(\.layoutDirection, .rightToLeft)
    }
}
