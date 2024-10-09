import SwiftUI
import AVFoundation
import Vision

struct ContentView: View {
    @StateObject var viewModel = CameraViewModel() // Use an observable view model
    
    var body: some View {
        ZStack {
            CameraView(viewModel: viewModel) // Pass the view model to the camera view
                .edgesIgnoringSafeArea(.all)
            
            // Display a message about whether the wrist is close to the nose
            VStack {
                Spacer()
                
                Text(viewModel.isCloseToHead ? "Escovando..." : "Sem escovar...")
                    .font(.largeTitle)
                    .foregroundColor(viewModel.isCloseToHead ? .green : .red)
                    .padding()
                
                Spacer()
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: CameraViewModel
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let cameraVC = CameraViewController()
        cameraVC.viewModel = viewModel // Pass view model to the controller
        return cameraVC
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // Nothing to update
    }
}

@Observable
class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    //    var rightClose: Bool = false
    //    var leftClose: Bool = false
    //    @Published var isCloseToHead: Bool = false
    
    var viewModel: CameraViewModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        // Set up the camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            fatalError("No camera available")
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            captureSession.addInput(input)
        } catch {
            print("Error accessing the camera: \(error)")
            return
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(videoOutput)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    // Process each frame from the camera
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Create a human body pose request
        let request = VNDetectHumanBodyPoseRequest { request, error in
            if let results = request.results as? [VNHumanBodyPoseObservation], let result = results.first {
                self.handleHumanBodyPoseObservation(result)
            }
        }
        
        // Process the image
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? requestHandler.perform([request])
    }
    
    // Handle the human body detection result
    private func handleHumanBodyPoseObservation(_ observation: VNHumanBodyPoseObservation) {
        do {
            let recognizedPoints = try observation.recognizedPoints(.all)
            
            if let nose = recognizedPoints[.nose],
               let leftWrist = recognizedPoints[.leftWrist],
               let rightWrist = recognizedPoints[.rightWrist] {
                
                var isClose = false
                
                if nose.confidence > 0.4 && leftWrist.confidence > 0.4 {
                    isClose = isHandCloseToHead(handPoint: leftWrist, headPoint: nose)
                }
                if nose.confidence > 0.4 && rightWrist.confidence > 0.4 {
                    isClose = isClose || isHandCloseToHead(handPoint: rightWrist, headPoint: nose)
                }
                
                
                DispatchQueue.main.async {
                    self.viewModel?.isCloseToHead = isClose
                }
            }
            
            //            let joints = recognizedPoints.map { $0.key.rawValue.rawValue + ": " + String($0.value.confidence) }
            //            DispatchQueue.main.async {
            //                print("Detected human body points with confidence: \(joints)")
            //            }
        } catch {
            print("Error processing body pose observation: \(error)")
        }
    }
    
    private func isHandCloseToHead(handPoint: VNRecognizedPoint, headPoint: VNRecognizedPoint) -> Bool {
        // Calculate Euclidean distance between head and hand
        let dx = handPoint.location.x - headPoint.location.x
        let dy = handPoint.location.y - headPoint.location.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Define a threshold for "closeness" (you can tune this value)
        let threshold: CGFloat = 0.3 // Adjust based on what you consider "close"
        
        return distance < threshold
    }
}


class CameraViewModel: ObservableObject {
    @Published var isCloseToHead: Bool = false
}
