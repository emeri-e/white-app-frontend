import UIKit
import CoreML
import Vision

struct iOSDetection {
    let label: String
    let confidence: Float
    let x: Float
    let y: Float
    let w: Float
    let h: Float
}

class NudeNetClassifier {
    static let instance = NudeNetClassifier()
    
    private var isDummyMode = false
    private var model: VNCoreMLModel?
    
    private init() {
        // Load CoreML model or fallback to dummy mode
        guard let modelPath = Bundle.main.path(forResource: "nudenet_320n", ofType: "mlmodel") else {
            print("NudeNetClassifier: Model file not found, initializing in DUMMY mock mode")
            isDummyMode = true
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: modelPath))
            if let contentString = String(data: data.prefix(100), encoding: .utf8), contentString.contains("DUMMY") {
                print("NudeNetClassifier: Initializing iOS classifier in DUMMY mock mode")
                isDummyMode = true
            } else {
                // If it is a real compiled mlmodelc bundle in production
                if let compiledUrl = Bundle.main.url(forResource: "nudenet_320n", withExtension: "mlmodelc") {
                    let coreMLModel = try MLModel(contentsOf: compiledUrl)
                    model = try VNCoreMLModel(for: coreMLModel)
                    isDummyMode = false
                    print("NudeNetClassifier: Successfully loaded iOS CoreML model")
                } else {
                    isDummyMode = true
                }
            }
        } catch {
            print("NudeNetClassifier loading failed, falling back to dummy mock mode: \(error.localizedDescription)")
            isDummyMode = true
        }
    }
    
    func classify(image: UIImage, completion: @escaping ([iOSDetection]) -> Void) {
        if isDummyMode {
            completion(generateMockDetections(for: image))
            return
        }
        
        guard let model = self.model, let cgImage = image.cgImage else {
            completion([])
            return
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            guard let results = request.results as? [VNRecognizedObjectObservation] else {
                completion([])
                return
            }
            
            let detections = results.compactMap { observation -> iOSDetection? in
                guard let topLabel = observation.labels.first else { return nil }
                
                let rect = observation.boundingBox // normalized coordinates [0.0, 1.0]
                return iOSDetection(
                    label: topLabel.identifier,
                    confidence: topLabel.confidence,
                    x: Float(rect.midX),
                    y: Float(rect.midY),
                    w: Float(rect.width),
                    h: Float(rect.height)
                )
            }
            completion(detections)
        }
        
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("NudeNetClassifier Vision request failed: \(error.localizedDescription)")
                completion([])
            }
        }
    }
    
    private func generateMockDetections(for image: UIImage) -> [iOSDetection] {
        var detections: [iOSDetection] = []
        
        // Analyze color of pixel at (0,0) to trigger deterministic mock detections
        guard let cgImage = image.cgImage,
              let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data else {
            return []
        }
        
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        // RGBA or BGRA format
        let r = data[0]
        let g = data[1]
        let b = data[2]
        
        if r == 255 && g == 0 && b == 0 {
            detections.append(
                iOSDetection(
                    label: "GENITALIA_EXPOSED",
                    confidence: 0.93,
                    x: 0.5, y: 0.5, w: 0.3, h: 0.4
                )
            )
        } else if r == 0 && g == 255 && b == 0 {
            detections.append(
                iOSDetection(
                    label: "FEMALE_BREAST_EXPOSED",
                    confidence: 0.87,
                    x: 0.4, y: 0.3, w: 0.2, h: 0.2
                )
            )
        } else if r == 0 && g == 0 && b == 255 {
            detections.append(
                iOSDetection(
                    label: "BELLY_EXPOSED",
                    confidence: 0.81,
                    x: 0.5, y: 0.6, w: 0.2, h: 0.2
                )
            )
            detections.append(
                iOSDetection(
                    label: "BUTTOCKS_EXPOSED",
                    confidence: 0.55,
                    x: 0.5, y: 0.7, w: 0.3, h: 0.3
                )
            )
        }
        
        return detections
    }
}
