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
    
    var body: some View {
        EmptyView()
    }
}

struct HandCameraView: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let cameraVC = HandCameraViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
}

@Observable
class HandCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    var viewModel:
    
}

class HandCameraViewModel: ObservableObject {
    @Published var isCloseToMouth: Bool = false
}
