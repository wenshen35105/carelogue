import SwiftUI
import AVFoundation
import UIKit

/// 拍照 (T24): the system camera, wrapped for SwiftUI. Photos taken here go
/// through the same importer as the photo library, so they are downscaled and
/// re-encoded as JPEG before they ever reach the store.
///
/// The simulator has no camera, so `CameraPicker.isAvailable` is false there
/// and the editor hides the entry — this path can only be checked on a device.
struct CameraPicker: UIViewControllerRepresentable {
    /// Called with the captured image's data (JPEG/PNG as the camera hands it
    /// over); the caller compresses it.
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// Camera permission, asked for before the sheet is presented so a denial
    /// can be explained instead of showing a black viewfinder.
    static func requestAccess() async -> AVAuthorizationStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .notDetermined else { return status }
        return await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 1) else {
                onCancel()
                return
            }
            onCapture(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
