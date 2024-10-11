//
//  HandDetection.swift
//  VisionPOC
//
//  Created by Lucas Dantas de Moura Carvalho on 09/10/24.
//

import AVFoundation
import Vision
import SwiftUI

struct HandDetectionView: View {
    @StateObject var viewModel = HandCameraViewModel()
    
    var body: some View {
        ZStack {
            HandCameraView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                Text(viewModel.isCloseToMouth ? "Escovando..." : "Sem escovar...")
                    .font(.largeTitle)
                    .foregroundStyle(viewModel.isCloseToMouth ? .green : .red)
                    .padding()
                Spacer()
            }
        }
    }
}

struct HandCameraView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: HandCameraViewModel
    
    func makeUIViewController(context: Context) -> HandCameraViewController {
        let cameraVC = HandCameraViewController()
        cameraVC.viewModel = viewModel
        return cameraVC
    }
    
    func updateUIViewController(_ uiViewController: HandCameraViewController, context: Context) {
        // Não necessário agora
    }
}

@Observable
class HandCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    var viewModel: HandCameraViewModel?
    
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
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // executa aqui tranquilo
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
//        var handResult: VNHumanHandPoseObservation?
//        var faceResult: VNFaceObservation?
        
        let faceRequest = VNDetectFaceLandmarksRequest { request, error in
            if let faceResults = request.results as? [VNFaceObservation] {
                DispatchQueue.main.async {
                    self.viewModel?.faceResult = faceResults.first
                }
            }
        }
        
        let handRequest = VNDetectHumanHandPoseRequest { request, error in
            if let handResults = request.results as? [VNHumanHandPoseObservation] {
                DispatchQueue.main.async {
                    self.viewModel?.handResult = handResults.first
                }
            }
        }
        
//        print(handResult ?? "")
        
        if let faceResult = viewModel?.faceResult, let handResult = viewModel?.handResult {
            self.handleObservations(faceResult: faceResult, handResult: handResult)
        }
        
        let handRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handRequestHandler.perform([handRequest])
        let faceRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? faceRequestHandler.perform([faceRequest])
    }
    
    private func handleObservations(faceResult: VNFaceObservation, handResult: VNHumanHandPoseObservation) {
        print("tamo entrando aqui")
        do {
            // Get the face landmarks (inner lips in this case)
            if let innerLipsRegion = faceResult.landmarks?.innerLips {
                let innerLipsPoints = innerLipsRegion.normalizedPoints // Array of CGPoints
                if let mouthCenter = innerLipsPoints.first {
                    // No need to convert the points to image size
                    let mouthPositionInImage = CGPoint(x: mouthCenter.x, y: mouthCenter.y)
                    
                    // Get the hand points (they are already normalized)
                    let handPoints = try handResult.recognizedPoints(.all)
                    if let indexPoint = handPoints[.indexDIP] {
                        let indexPosition = indexPoint.location
                        
                        // Compare normalized coordinates
                        print("ta fazendo essa checagem aqui, pqp não tá ainda vei")
                        if isHandCloseToMouth(handPoint: indexPosition, mouthPoint: mouthPositionInImage) {
                            DispatchQueue.main.async {
                                self.viewModel?.isCloseToMouth = true
                            }
                            print("Hand is close to the mouth.")
                        } else {
                            DispatchQueue.main.async {
                                self.viewModel?.isCloseToMouth = false
                            }
                            print("Hand is not close to the mouth.")
                        }
                    }
                }
            }
        } catch {
            print("Error processing observations: \(error.localizedDescription)")
        }
    }
    
    private func isHandCloseToMouth(handPoint: CGPoint, mouthPoint: CGPoint) -> Bool {
        // Calculate distance between normalized hand and mouth points
        print(handPoint)
        print(mouthPoint)
        print("\n\n")
        let dx = handPoint.x - mouthPoint.x
        let dy = handPoint.y - mouthPoint.y
        let distance = sqrt(dx * dx + dy * dy)
        print("Distance: \(distance)")
        
        // Define a threshold for what is considered "close" in normalized coordinates
        let threshold: CGFloat = 0.1 // Adjust this threshold based on your needs
        return distance < threshold
    }
}

class HandCameraViewModel: ObservableObject {
    @Published var isCloseToMouth: Bool = false
    @Published var handResult: VNHumanHandPoseObservation?
    @Published var faceResult: VNFaceObservation?
}
