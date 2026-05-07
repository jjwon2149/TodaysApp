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
        completionActionTitle: String = L10n.string("editor.completion.home_action"),
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
            .alert(L10n.string("editor.error.alert_title"), isPresented: Binding(get: {
                viewModel.errorMessage != nil
            }, set: { newValue in
                if newValue == false {
                    viewModel.errorMessage = nil
                }
            })) {
                Button(L10n.string("common.ok"), role: .cancel) {}
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
        .navigationTitle(existingEntry == nil ? L10n.string("editor.title.new") : L10n.string("editor.title.edit"))
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

                                Text("editor.photo.empty")
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
                        Label(existingEntry == nil ? L10n.string("editor.photo.pick") : L10n.string("editor.photo.repick"), systemImage: "photo.stack")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppTheme.Colors.secondaryAccent)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }

                if isCameraAvailable == false {
                    Text("error.camera.unavailable")
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
            return L10n.string("editor.camera.unavailable")
        }

        return existingEntry == nil ? L10n.string("editor.camera.capture") : L10n.string("editor.camera.recapture")
    }

    private var memoSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("editor.memo.title")
                    .font(.system(.headline, design: .rounded, weight: .semibold))

                TextField(L10n.string("editor.memo.placeholder"), text: $viewModel.memo, axis: .vertical)
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
                Text("editor.mood.title")
                    .font(.system(.headline, design: .rounded, weight: .semibold))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    ForEach(viewModel.moodOptions) { mood in
                        Button {
                            viewModel.selectedMood = mood.id
                        } label: {
                            Text(mood.title)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(viewModel.selectedMood == mood.id ? AppTheme.Colors.accent : AppTheme.Colors.muted)
                                .foregroundStyle(viewModel.selectedMood == mood.id ? Color.white : AppTheme.Colors.textPrimary)
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

                Text(viewModel.isSaving ? L10n.string("editor.saving") : viewModel.saveButtonTitle)
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
        .navigationTitle(L10n.string("editor.completion.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.success)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("editor.completion.header")
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
                Text("editor.completion.reward_title")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                completionRow(
                    title: L10n.string("editor.completion.current_streak"),
                    value: L10n.format("common.days_count", summary.currentStreak),
                    symbol: "flame.fill",
                    tint: AppTheme.Colors.accent
                )

                completionRow(
                    title: summary.missionTitle,
                    value: summary.missionCompleted ? L10n.string("editor.completion.mission_complete") : L10n.string("editor.completion.needs_review"),
                    symbol: "checkmark.seal.fill",
                    tint: AppTheme.Colors.success
                )

                completionRow(
                    title: L10n.string("editor.completion.reward_points"),
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
