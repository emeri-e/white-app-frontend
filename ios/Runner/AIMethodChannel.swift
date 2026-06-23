import Foundation
import Flutter
import UIKit

class AIMethodChannel {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.whiteapp/ai_ios", binaryMessenger: registrar.messenger())
        
        channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterMethodResult) in
            switch call.method {
            case "startCameraRollMonitoring":
                CameraRollMonitor.shared.startMonitoring()
                result(true)
            case "stopCameraRollMonitoring":
                CameraRollMonitor.shared.stopMonitoring()
                result(true)
            case "isCameraRollMonitoring":
                result(CameraRollMonitor.shared.isCurrentlyMonitoring())
            case "classifyImage":
                guard let args = call.arguments as? [String: Any],
                      let data = args["imageBytes"] as? FlutterStandardTypedData else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing imageBytes", details: nil))
                    return
                }
                
                guard let image = UIImage(data: data.data) else {
                    result(FlutterError(code: "DECODE_FAIL", message: "Failed to decode UIImage from bytes", details: nil))
                    return
                }
                
                NudeNetClassifier.instance.classify(image: image) { detections in
                    let resultList = detections.map { detection -> [String: Any] in
                        return [
                            "label": detection.label,
                            "confidence": detection.confidence,
                            "boundingBox": [
                                "x": detection.x,
                                "y": detection.y,
                                "w": detection.w,
                                "h": detection.h
                            ]
                        ]
                    }
                    DispatchQueue.main.async {
                        result(resultList)
                    }
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
