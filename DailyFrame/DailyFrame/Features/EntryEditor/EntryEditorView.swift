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
                        isActionDisabled: shouldHoldCompletionDismissal,
                        isActionInFlight: isSavedNotificationInFlight
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
                viewModel.isShowingErrorAlert
            }, set: { newValue in
                if newValue == false {
                    viewModel.dismissErrorAlert()
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
                saveStatusSection
                saveSection
            }
            .padding(AppTheme.Spacing.medium)
            .disabled(viewModel.isSaving)
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
                photoPreview

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
                    .disabled(isCameraAvailable == false || viewModel.isSaving)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(existingEntry == nil ? L10n.string("editor.photo.pick") : L10n.string("editor.photo.repick"), systemImage: "photo.stack")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppTheme.Colors.secondaryAccent)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .disabled(viewModel.isSaving)
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

    private var photoPreview: some View {
        ZStack {
            if let previewImage = viewModel.previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(emptyPhotoBackground)
                    .overlay {
                        VStack(spacing: AppTheme.Spacing.small) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(emptyPhotoForeground)

                            Text("editor.photo.empty")
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text("editor.photo.empty_detail")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(AppTheme.Spacing.medium)
                    }
            }

            if viewModel.isSaving {
                savingOverlay
            }
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(emptyPhotoStroke, lineWidth: viewModel.hasPhoto ? 0 : 1)
        }
    }

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.34)

            VStack(spacing: AppTheme.Spacing.small) {
                ProgressView()
                    .tint(.white)

                Text("editor.saving")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
        }
    }

    private var emptyPhotoBackground: Color {
        viewModel.errorMessage != nil && viewModel.hasPhoto == false
            ? Color.red.opacity(0.12)
            : AppTheme.Colors.muted
    }

    private var emptyPhotoForeground: Color {
        viewModel.errorMessage != nil && viewModel.hasPhoto == false
            ? Color.red
            : AppTheme.Colors.textSecondary
    }

    private var emptyPhotoStroke: Color {
        viewModel.errorMessage != nil && viewModel.hasPhoto == false
            ? Color.red.opacity(0.45)
            : Color.clear
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
                    .disabled(viewModel.isSaving)
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
                        .disabled(viewModel.isSaving)
                    }
                }
            }
        }
    }

    private var saveStatusSection: some View {
        let status = saveStatus

        return HStack(alignment: .top, spacing: AppTheme.Spacing.small) {
            Image(systemName: status.symbolName)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(status.tint)
                .frame(width: 24)

            Text(status.message)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var saveStatus: EntryEditorSaveStatus {
        if viewModel.isSaving {
            return EntryEditorSaveStatus(
                message: L10n.string("editor.status.saving"),
                symbolName: "clock.fill",
                tint: AppTheme.Colors.accent,
                background: AppTheme.Colors.secondaryAccent
            )
        }

        if let errorMessage = viewModel.errorMessage {
            return EntryEditorSaveStatus(
                message: errorMessage,
                symbolName: "exclamationmark.triangle.fill",
                tint: Color.red,
                background: Color.red.opacity(0.10)
            )
        }

        if viewModel.hasPhoto {
            return EntryEditorSaveStatus(
                message: L10n.string("editor.status.photo_ready"),
                symbolName: "checkmark.circle.fill",
                tint: AppTheme.Colors.success,
                background: AppTheme.Colors.success.opacity(0.12)
            )
        }

        return EntryEditorSaveStatus(
            message: L10n.string("editor.status.photo_required"),
            symbolName: "photo.badge.plus",
            tint: AppTheme.Colors.textSecondary,
            background: AppTheme.Colors.muted
        )
    }

    private var saveSection: some View {
        Button {
            guard isSaveButtonDisabled == false else { return }

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
        .disabled(isSaveButtonDisabled)
    }

    private var isSaveButtonDisabled: Bool {
        viewModel.isSaving || viewModel.hasPhoto == false
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

private struct EntryEditorSaveStatus {
    let message: String
    let symbolName: String
    let tint: Color
    let background: Color
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
    let isActionInFlight: Bool
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
            HStack(spacing: AppTheme.Spacing.small) {
                if isActionInFlight {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "house.fill")
                }

                Text(isActionInFlight ? L10n.string("editor.completion.returning") : actionTitle)
            }
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isActionDisabled ? AppTheme.Colors.muted : AppTheme.Colors.accent)
            .foregroundStyle(isActionDisabled ? AppTheme.Colors.textSecondary : Color.white)
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
