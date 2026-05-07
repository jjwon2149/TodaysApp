import PhotosUI
import SwiftUI
import UIKit

struct EntryEditorView: View {
    let existingEntry: DailyPhotoEntry?
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EntryEditorViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isPresentingCamera = false

    init(existingEntry: DailyPhotoEntry?, onSaved: @escaping () async -> Void) {
        self.existingEntry = existingEntry
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: EntryEditorViewModel(existingEntry: existingEntry))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    previewSection
                    memoSection
                    moodSection
                    saveSection
                }
                .padding(AppTheme.Spacing.medium)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(existingEntry == nil ? "오늘 기록" : "기록 수정")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: selectedPhotoItem) {
                await viewModel.loadPhotoItem(selectedPhotoItem)
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
                await onSaved()
                dismiss()
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
}
