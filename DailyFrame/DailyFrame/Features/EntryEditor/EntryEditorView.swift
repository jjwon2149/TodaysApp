import PhotosUI
import SwiftUI
import UIKit

struct EntryEditorView: View {
    let existingEntry: DailyPhotoEntry?
    let completionActionTitle: String
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EntryEditorViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isPresentingCamera = false
    @State private var didNotifySaved = false
    @State private var isSavedNotificationInFlight = false

    init(
        existingEntry: DailyPhotoEntry?,
        completionActionTitle: String = "홈으로 돌아가기",
        onSaved: @escaping () async -> Void
    ) {
        self.existingEntry = existingEntry
        self.completionActionTitle = completionActionTitle
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: EntryEditorViewModel(existingEntry: existingEntry))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let completionSummary = viewModel.completionSummary {
                    EntryCompletionView(
                        summary: completionSummary,
                        actionTitle: completionActionTitle,
                        isActionDisabled: shouldHoldCompletionDismissal
                    ) {
                        Task {
                            await notifySavedOnce()
                            dismiss()
                        }
                    }
                } else {
                    editorContent
                }
            }
            .sheet(isPresented: $isPresentingCamera) {
                CameraCaptureView { image in
                    viewModel.loadCapturedImage(image)
                    isPresentingCamera = false
                } onCancel: {
                    isPresentingCamera = false
                } onFailure: { error in
                    viewModel.handleCameraCaptureFailure(error)
                    isPresentingCamera = false
                }
            }
            .alert("저장할 수 없습니다", isPresented: Binding(get: {
                viewModel.errorMessage != nil
            }, set: { newValue in
                if newValue == false {
                    viewModel.errorMessage = nil
                }
            })) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving || shouldHoldCompletionDismissal)
    }

    private var editorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                previewSection
                memoSection
                moodSection
                saveSection
            }
            .padding(AppTheme.Spacing.medium)
        }
        .background(KeyboardDismissTapHandler())
        .scrollDismissesKeyboard(.immediately)
        .background(AppTheme.Colors.background)
        .navigationTitle(existingEntry == nil ? "오늘 기록" : "기록 수정")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPhotoItem) {
            await viewModel.loadPhotoItem(selectedPhotoItem)
        }
    }

    private var previewSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                if let previewImage = viewModel.previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 280)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.Colors.muted)
                        .frame(height: 280)
                        .overlay {
                            VStack(spacing: AppTheme.Spacing.small) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)

                                Text("오늘의 한 장을 골라주세요")
                                    .font(.system(.headline, design: .rounded, weight: .semibold))
                            }
                        }
                }

                VStack(spacing: AppTheme.Spacing.small) {
                    Button {
                        isPresentingCamera = true
                    } label: {
                        Label(cameraButtonTitle, systemImage: "camera.fill")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(isCameraAvailable ? AppTheme.Colors.accent : AppTheme.Colors.muted)
                            .foregroundStyle(isCameraAvailable ? Color.white : AppTheme.Colors.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .disabled(isCameraAvailable == false)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(existingEntry == nil ? "앨범에서 사진 선택" : "앨범에서 다시 선택", systemImage: "photo.stack")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppTheme.Colors.secondaryAccent)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }

                if isCameraAvailable == false {
                    Text("이 기기에서는 카메라를 사용할 수 없습니다. 앨범에서 사진을 선택해주세요.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var cameraButtonTitle: String {
        if isCameraAvailable == false {
            return "카메라 사용 불가"
        }

        return existingEntry == nil ? "카메라로 촬영" : "카메라로 다시 촬영"
    }

    private var memoSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("오늘의 한 줄")
                    .font(.system(.headline, design: .rounded, weight: .semibold))

                TextField("이 사진을 고른 이유를 남겨보세요", text: $viewModel.memo, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(AppTheme.Spacing.medium)
                    .background(AppTheme.Colors.muted)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var moodSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("오늘 기분")
                    .font(.system(.headline, design: .rounded, weight: .semibold))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    ForEach(viewModel.moodOptions, id: \.self) { mood in
                        Button {
                            viewModel.selectedMood = mood
                        } label: {
                            Text(mood)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(viewModel.selectedMood == mood ? AppTheme.Colors.accent : AppTheme.Colors.muted)
                                .foregroundStyle(viewModel.selectedMood == mood ? Color.white : AppTheme.Colors.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private var saveSection: some View {
        Button {
            Task {
                let saved = await viewModel.saveEntry()
                guard saved else { return }
                await notifySavedOnce()
            }
        } label: {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                }

                Text(viewModel.isSaving ? "저장 중..." : viewModel.saveButtonTitle)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(AppTheme.Colors.accent)
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .disabled(viewModel.isSaving)
    }

    private var shouldHoldCompletionDismissal: Bool {
        viewModel.completionSummary != nil && (didNotifySaved == false || isSavedNotificationInFlight)
    }

    @MainActor
    private func notifySavedOnce() async {
        guard didNotifySaved == false else { return }

        didNotifySaved = true
        isSavedNotificationInFlight = true
        defer { isSavedNotificationInFlight = false }

        await onSaved()
    }
}

private struct KeyboardDismissTapHandler: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false

        DispatchQueue.main.async {
            context.coordinator.installRecognizer(from: view)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.installRecognizer(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.removeRecognizer()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var recognizer: UITapGestureRecognizer?

        func installRecognizer(from view: UIView) {
            guard recognizer == nil, let window = view.window else { return }

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            self.recognizer = recognizer
        }

        func removeRecognizer() {
            guard let recognizer else { return }

            recognizer.view?.removeGestureRecognizer(recognizer)
            self.recognizer = nil
        }

        @objc private func dismissKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let currentView = view {
                if currentView is UITextField || currentView is UITextView {
                    return false
                }

                view = currentView.superview
            }

            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private struct EntryCompletionView: View {
    let summary: EntryCompletionSummary
    let actionTitle: String
    let isActionDisabled: Bool
    let onAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                headerSection
                rewardSection
                actionButton
            }
            .padding(AppTheme.Spacing.medium)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("완료")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.success)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("기록 완료")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(summary.returnMessage)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppTheme.Spacing.xLarge)
    }

    private var rewardSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                Text("오늘 보상")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                completionRow(
                    title: "현재 스트릭",
                    value: "\(summary.currentStreak)일",
                    symbol: "flame.fill",
                    tint: AppTheme.Colors.accent
                )

                completionRow(
                    title: summary.missionTitle,
                    value: summary.missionCompleted ? "미션 완료" : "확인 필요",
                    symbol: "checkmark.seal.fill",
                    tint: AppTheme.Colors.success
                )

                completionRow(
                    title: "기록 포인트",
                    value: summary.rewardText,
                    symbol: "sparkles",
                    tint: AppTheme.Colors.textPrimary
                )
            }
        }
    }

    private var actionButton: some View {
        Button(action: onAction) {
            Label(actionTitle, systemImage: "house.fill")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(AppTheme.Colors.accent)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .disabled(isActionDisabled)
    }

    private func completionRow(title: String, value: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: symbol)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                Text(value)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }

            Spacer(minLength: AppTheme.Spacing.small)
        }
    }
}
