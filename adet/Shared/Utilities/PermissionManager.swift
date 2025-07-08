import Foundation
import AVFoundation
import Photos
import UIKit

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var cameraPermission: AVAuthorizationStatus = .notDetermined
    @Published var microphonePermission: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryPermission: PHAuthorizationStatus = .notDetermined

    private init() {
        updatePermissionStatuses()
    }

    func updatePermissionStatuses() {
        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        microphonePermission = AVCaptureDevice.authorizationStatus(for: .audio)
        photoLibraryPermission = PHPhotoLibrary.authorizationStatus()
    }

    func requestCameraPermission() async -> Bool {
        let status = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            cameraPermission = status ? .authorized : .denied
        }
        return status
    }

    func requestMicrophonePermission() async -> Bool {
        let status = await AVCaptureDevice.requestAccess(for: .audio)
        await MainActor.run {
            microphonePermission = status ? .authorized : .denied
        }
        return status
    }

    func requestPhotoLibraryPermission() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            photoLibraryPermission = status
        }
        return status == .authorized || status == .limited
    }

    func requestAllPermissions() async -> (camera: Bool, microphone: Bool, photoLibrary: Bool) {
        async let camera = requestCameraPermission()
        async let microphone = requestMicrophonePermission()
        async let photoLibrary = requestPhotoLibraryPermission()

        return await (camera: camera, microphone: microphone, photoLibrary: photoLibrary)
    }

    func showPermissionAlert(for type: PermissionType) {
        let alert = UIAlertController(
            title: "Permission Required",
            message: type.message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
    }
}

enum PermissionType {
    case camera
    case microphone
    case photoLibrary

    var message: String {
        switch self {
        case .camera:
            return "Camera access is required to take photos for habit proof. Please enable it in Settings."
        case .microphone:
            return "Microphone access is required to record audio for habit proof. Please enable it in Settings."
        case .photoLibrary:
            return "Photo Library access is required to select images for habit proof. Please enable it in Settings."
        }
    }
}
