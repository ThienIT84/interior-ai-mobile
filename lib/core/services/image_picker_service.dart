import 'package:image_picker/image_picker.dart';

abstract interface class ImagePickerService {
  Future<XFile?> pickImage(ImageSource source);
}

class DefaultImagePickerService implements ImagePickerService {
  DefaultImagePickerService([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickImage(ImageSource source) {
    return _picker.pickImage(source: source, imageQuality: 85);
  }
}
