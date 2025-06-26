import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    enum SourceType {
        case camera
        case photoLibrary

        var uiSourceType: UIImagePickerController.SourceType {
            switch self {
            case .camera:
                return .camera
            case .photoLibrary:
                return .photoLibrary
            }
        }
    }

    let sourceType: SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType.uiSourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }

            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ImagePickerActionSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false

    var body: some View {
        VStack {
            // This is just a placeholder - the action sheet will be presented modally
        }
        .actionSheet(isPresented: $isPresented) {
            ActionSheet(
                title: Text("Select Profile Image"),
                message: Text("Choose how you'd like to add your profile image"),
                buttons: [
                    .default(Text("Take Photo")) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showingCamera = true
                        }
                    },
                    .default(Text("Choose from Library")) {
                        showingPhotoLibrary = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage)
        }
    }
}


