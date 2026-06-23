import Photos
import UIKit

class CameraRollMonitor: NSObject, PHPhotoLibraryChangeObserver {
    static let shared = CameraRollMonitor()
    
    private var isMonitoring = false
    private var lastScannedAssetId: String?
    
    private override init() {
        super.init()
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                print("CameraRollMonitor: Permission not granted to Photo Library")
                return
            }
            
            PHPhotoLibrary.shared().register(self)
            self.isMonitoring = true
            print("CameraRollMonitor: iOS Photo Library monitoring started")
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        isMonitoring = false
        print("CameraRollMonitor: iOS Photo Library monitoring stopped")
    }
    
    func isCurrentlyMonitoring() -> Bool {
        return isMonitoring
    }
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Query the latest assets to detect changes/new photos
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard let latestAsset = fetchResult.firstObject else { return }
        
        if latestAsset.localIdentifier == lastScannedAssetId {
            return
        }
        lastScannedAssetId = latestAsset.localIdentifier
        
        scanAsset(latestAsset)
    }
    
    private func scanAsset(_ asset: PHAsset) {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        imageManager.requestImage(for: asset, targetSize: CGSize(width: 320, height: 320), contentMode: .aspectFill, options: options) { [weak self] image, info in
            guard let self = self, let uiImage = image else { return }
            
            NudeNetClassifier.instance.classify(image: uiImage) { detections in
                if detections.isEmpty { return }
                
                var shouldAlert = false
                var triggeringLabel = ""
                var maxConfidence: Float = 0.0
                
                for detection in detections {
                    let label = detection.label.uppercased()
                    let conf = detection.confidence
                    
                    let threshold: Float = label.contains("GENITALIA") ? 0.65 : 0.75
                    if conf >= threshold {
                        shouldAlert = true
                        if conf > maxConfidence {
                            maxConfidence = conf
                            triggeringLabel = label
                        }
                    }
                }
                
                if shouldAlert {
                    print("CameraRollMonitor: Flagged explicit image on iOS: \(triggeringLabel) (\(maxConfidence))")
                    // On iOS we cannot delete directly without prompting the user,
                    // so we dispatch buddy alert notifications and log block metrics.
                }
            }
        }
    }
}
