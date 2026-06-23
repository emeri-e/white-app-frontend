import Foundation
import Flutter
import UIKit

class ScreenTimeMethodChannel {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.whiteapp/screentime", binaryMessenger: registrar.messenger())
        
        channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterMethodResult) in
            if #available(iOS 15.0, *) {
                switch call.method {
                case "requestAuthorization":
                    ScreenTimeManager.shared.requestAuthorization { success in
                        DispatchQueue.main.async {
                            result(success)
                        }
                    }
                case "updateBlockedDomains":
                    if let args = call.arguments as? [String: Any],
                       let domains = args["domains"] as? [String] {
                        ScreenTimeManager.shared.updateBlockedDomains(domains: domains)
                        result(true)
                    } else {
                        result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments must contain 'domains' list", details: nil))
                    }
                case "getStatus":
                    let status = ScreenTimeManager.shared.getAuthorizationStatus()
                    result(status)
                default:
                    result(FlutterMethodNotImplemented)
                }
            } else {
                result(FlutterError(code: "UNSUPPORTED_OS", message: "iOS 15.0 or higher is required for Screen Time APIs", details: nil))
            }
        }
    }
}
