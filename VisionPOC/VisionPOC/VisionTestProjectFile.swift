import SwiftUI
import UIKit
import AVFoundation
import Vision

class CameraViewController1: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private var session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var overlayView: UIView!  // Overlay view for drawing points
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupOverlayView()  // Setup the overlay view for drawing landmarks
    }
    
    private func setupCamera() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            session.addInput(input)
        } catch {
            print("Error setting up camera input: \(error)")
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraQueue"))
        session.addOutput(videoOutput)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
        }
    }
    
    private func setupOverlayView() {
        overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = .clear
        view.addSubview(overlayView)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectFaceLandmarksRequest { [weak self] (request, error) in
            guard let results = request.results as? [VNFaceObservation], let self = self else { return }
            DispatchQueue.main.async {
                self.overlayView.layer.sublayers?.removeAll()  // Remove previous drawings
                for face in results {
                    self.drawFaceLandmarks(face: face)  // Draw new face landmarks
                    self.checkMouthOpen(face: face)    // Check if mouth is open or closed
                }
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
    
    private func drawFaceLandmarks(face: VNFaceObservation) {
        guard let landmarks = face.landmarks else { return }
        
        // Draw the outer lips (you can draw other landmarks similarly)
        if let outerLips = landmarks.outerLips {
            drawLandmark(points: outerLips.normalizedPoints, boundingBox: face.boundingBox)
        }
        
        // Draw other facial landmarks as needed, e.g.:
        // - landmarks.leftEye
        // - landmarks.rightEye
        // - landmarks.nose
    }
    
    private func drawLandmark(points: [CGPoint], boundingBox: CGRect) {
        let convertedPoints = points.map { point -> CGPoint in
            let x = boundingBox.origin.x + point.x * boundingBox.size.width
            let y = boundingBox.origin.y + point.y * boundingBox.size.height
            let convertedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: x, y: 1 - y)) // Flip the y-axis
            return convertedPoint
        }
        
        let path = UIBezierPath()
        path.move(to: convertedPoints.first!)
        for point in convertedPoints.dropFirst() {
            path.addLine(to: point)
        }
        path.close()
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 2.0
        shapeLayer.fillColor = UIColor.clear.cgColor
        
        overlayView.layer.addSublayer(shapeLayer)
    }
    
    // Function to check if the mouth is open
    private func checkMouthOpen(face: VNFaceObservation) {
        guard let landmarks = face.landmarks,
              let outerLips = landmarks.innerLips?.normalizedPoints else { return }
        
        // Get the top and bottom points of the lips
        let topLipPoint = outerLips[outerLips.count / 2]  // Mid-point of the upper lip
        let bottomLipPoint = outerLips[0]                 // Mid-point of the lower lip
        
        let leftCornerPoint = outerLips.first!            // First point in the outer lips array
        let rightCornerPoint = outerLips.last!            // Last point in the outer lips array
        
        
        // Calculate the vertical distance between the top and bottom lip points
        let verticalDistance = distanceBetweenPoints(topLipPoint, bottomLipPoint, boundingBox: face.boundingBox)
        
        // Calculate the horizontal distance between the left and right corners of the mouth
        let horizontalDistance = distanceBetweenPoints(leftCornerPoint, rightCornerPoint, boundingBox: face.boundingBox)
        
        // Compute the proportion of vertical to horizontal distance
        let mouthOpenRatio = verticalDistance / horizontalDistance
        
        
        // Calculate the distance between the top and bottom lip points
        let lipDistance = distanceBetweenPoints(topLipPoint, bottomLipPoint, boundingBox: face.boundingBox)
        
        //        // Threshold to determine if the mouth is open
        //        let mouthOpenThreshold: CGFloat = 40  // Adjust this value based on testing
        
        // Threshold to determine if the mouth is open
        let mouthOpenThreshold: CGFloat = 2  // Adjust this value based on testing
        
        if mouthOpenRatio < mouthOpenThreshold {
            print("Mouth is open")
            print("Mouth Open Ratio: \(mouthOpenRatio)")
            displayMouthStatus(isOpen: true)
        } else {
            print("Mouth is closed")
            displayMouthStatus(isOpen: false)
        }
    }
    
    // Function to calculate the distance between two points
    private func distanceBetweenPoints(_ point1: CGPoint, _ point2: CGPoint, boundingBox: CGRect) -> CGFloat {
        let point1Converted = convertPoint(point1, boundingBox: boundingBox)
        let point2Converted = convertPoint(point2, boundingBox: boundingBox)
        let xDiff = point1Converted.x - point2Converted.x
        let yDiff = point1Converted.y - point2Converted.y
        return sqrt(xDiff * xDiff + yDiff * yDiff)
    }
    
    // Convert the points from normalized face coordinates to view coordinates
    private func convertPoint(_ point: CGPoint, boundingBox: CGRect) -> CGPoint {
        let x = boundingBox.origin.x + point.x * boundingBox.size.width
        let y = boundingBox.origin.y + point.y * boundingBox.size.height
        return previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: x, y: 1 - y)) // Flip y-axis
    }
    
    // Display the mouth status on screen
    private func displayMouthStatus(isOpen: Bool) {
        let statusLabel = UILabel()
        statusLabel.text = isOpen ? "Mouth Open" : "Mouth Closed"
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        statusLabel.sizeToFit()
        statusLabel.center = overlayView.center
        
        overlayView.addSubview(statusLabel)
    }
}

struct CameraView1: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> CameraViewController1 {
        return CameraViewController1()
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController1, context: Context) {
        // Update as needed
    }
}

struct ContentView1: View {
    var body: some View {
        CameraView1()
            .edgesIgnoringSafeArea(.all)  // To make the camera view fullscreen
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
