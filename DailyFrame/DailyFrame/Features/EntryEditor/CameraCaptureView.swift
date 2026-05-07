import SwiftUI
import UIKit

enum CameraCaptureError: LocalizedError {
    case cameraUnavailable
    case missingCapturedImage

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "이 기기에서는 카메라를 사용할 수 없습니다. 앨범에서 사진을 선택해주세요."
        case .missingCapturedImage:
            return "촬영한 사진을 불러오지 못했습니다. 다시 촬영하거나 앨범에서 선택해주세요."
        }
    }
}

struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void
    let onFailure: (Error) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            let viewController = UIViewController()
            DispatchQueue.main.async {
                onFailure(CameraCaptureError.cameraUnavailable)
            }
            return viewController
        }

        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
}

extension CameraCaptureView {
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraCaptureView

        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.onFailure(CameraCaptureError.missingCapturedImage)
                return
            }

            parent.onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
