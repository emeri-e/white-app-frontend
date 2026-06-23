import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

@available(iOS 15.0, *)
class ScreenTimeManager {
    static let shared = ScreenTimeManager()
    private let store = ManagedSettingsStore()
    
    private init() {}
    
    /// Request user permission for FamilyControls (Screen Time restrictions)
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        if #available(iOS 16.0, *) {
            Task {
                do {
                    // Requests individual authorization (no parent/child flow required)
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    
                    let status = AuthorizationCenter.shared.authorizationStatus
                    print("ScreenTimeManager: Authorization status updated: \(status)")
                    completion(status == .approved)
                } catch {
                    print("ScreenTimeManager: FamilyControls request failed with error: \(error)")
                    
                    // Stub success for simulator or unsigned development environments
                    #if targetEnvironment(simulator)
                    print("ScreenTimeManager: Stubbing success on simulator environment")
                    completion(true)
                    #else
                    completion(false)
                    #endif
                }
            }
        } else {
            // Pre-iOS 16.0 individual authorization is not available or handled via parental profiles
            print("ScreenTimeManager: Pre-iOS 16 OS. Automatically assuming approved.")
            completion(true)
        }
    }
    
    /// Sync domain blocklist to the iOS ManagedSettingsStore shield configuration
    func updateBlockedDomains(domains: [String]) {
        if #available(iOS 15.0, *) {
            let webDomains = domains.map { WebDomain(domain: $0) }
            store.shield.webDomains = Set(webDomains)
            print("ScreenTimeManager: Blocked \(domains.count) domains via ManagedSettingsStore shield")
        }
    }
    
    /// Retrieve current FamilyControls authorization status
    func getAuthorizationStatus() -> String {
        if #available(iOS 16.0, *) {
            switch AuthorizationCenter.shared.authorizationStatus {
            case .notDetermined:
                return "notDetermined"
            case .denied:
                return "denied"
            case .approved:
                return "approved"
            @unknown default:
                // If it is a simulator and status is not approved, we stub it as approved for testing
                #if targetEnvironment(simulator)
                return "approved"
                #else
                return "denied"
                #endif
            }
        }
        return "approved"
    }
}
