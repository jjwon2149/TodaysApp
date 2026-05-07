import AVFoundation
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

    func makeUIViewController(context: Context) -> CameraController {
        CameraController(captureView: self, coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: CameraController, context: Context) {
        uiViewController.captureView = self
        context.coordinator.captureView = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
}

extension CameraCaptureView {
    final class CameraController: UIViewController {
        var captureView: CameraCaptureView

        private let coordinator: Coordinator
        private var didStartCameraFlow = false
        private var activePicker: UIImagePickerController?

        init(captureView: CameraCaptureView, coordinator: Coordinator) {
            self.captureView = captureView
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)

            guard didStartCameraFlow == false else { return }
            didStartCameraFlow = true
            openCameraIfPermitted()
        }

        private func openCameraIfPermitted() {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                DispatchQueue.main.async {
                    self.captureView.onFailure(CameraCaptureError.cameraUnavailable)
                }
                return
            }

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                presentCamera()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        guard let self else { return }

                        if granted {
                            self.presentCamera()
                        } else {
                            self.showPermissionDeniedAlert()
                        }
                    }
                }
            case .denied, .restricted:
                showPermissionDeniedAlert()
            @unknown default:
                showPermissionDeniedAlert()
            }
        }

        private func presentCamera() {
            let picker = UIImagePickerController()
            picker.delegate = coordinator
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.allowsEditing = false
            activePicker = picker
            present(picker, animated: false)
        }

        private func showPermissionDeniedAlert() {
            let alert = UIAlertController(
                title: "카메라 권한 필요",
                message: "사진을 촬영하려면 설정에서 카메라 접근을 허용해 주세요.",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "설정으로 이동", style: .default) { [weak self] _ in
                guard let self else { return }

                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }

                self.captureView.onCancel()
            })

            alert.addAction(UIAlertAction(title: "취소", style: .cancel) { [weak self] _ in
                self?.captureView.onCancel()
            })

            present(alert, animated: true)
        }
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var captureView: CameraCaptureView

        init(parent: CameraCaptureView) {
            captureView = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                captureView.onFailure(CameraCaptureError.missingCapturedImage)
                return
            }

            captureView.onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            captureView.onCancel()
        }
    }
}
