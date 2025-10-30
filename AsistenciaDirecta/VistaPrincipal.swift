//
//  VistaPrincipal.swift
//  AsistenciaDirecta
//
//  Created by Miguel Carlos Elizondo Martinez on 29/10/25.
//

import SwiftUI
import AVFoundation

// MARK: - VistaPrincipal
struct VistaPrincipal: View {
    var body: some View {
        ZStack {
            Color.purple.ignoresSafeArea()
            VStack {
                CameraPreviewView()
                    .frame(width: 200, height: 200)
            }
            .frame(width: 200, height: 200)
        }
    }
}

#Preview {
    VistaPrincipal()
}

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    // Cambia a .back si la quieres trasera
    var position: AVCaptureDevice.Position = .front
    private let session = AVCaptureSession()

    func makeUIView(context: Context) -> UIView {
        let view = ResizingPreviewContainer()
        Task { await setupCamera(in: view) }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    // MARK: - Configuración mínima (frontal + alta calidad si se puede)
    private func setupCamera(in container: ResizingPreviewContainer) async {
        // 1) Permisos
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else { return }

        // 2) Elegir el mejor dispositivo frontal disponible
        let device = bestFrontDevice(for: position)

        guard let device,
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        session.beginConfiguration()

        // 3) Elegir el mejor preset que soporte la sesión con ese input
        if session.canSetSessionPreset(.hd4K3840x2160) {
            session.sessionPreset = .hd4K3840x2160
        } else if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        } else {
            session.sessionPreset = .photo // buen “fallback” para preview
        }

        guard session.canAddInput(input) else { session.commitConfiguration(); return }
        session.addInput(input)
        session.commitConfiguration()

        // 4) Preview layer
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.videoOrientation = .portrait

        // Mirroring (selfie)
        if layer.connection?.isVideoMirroringSupported == true,
           position == .front {
            layer.connection?.isVideoMirrored = true
        }

        container.attachPreviewLayer(layer)

        // 5) Iniciar
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    private func bestFrontDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // Intenta TrueDepth primero; si no, wide-angle frontal
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )
        return discovery.devices.first
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }
}

/// Contenedor que mantiene el `previewLayer` ajustado al tamaño de la vista
final class ResizingPreviewContainer: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer?.removeFromSuperlayer()
        previewLayer = layer
        self.layer.addSublayer(layer)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

