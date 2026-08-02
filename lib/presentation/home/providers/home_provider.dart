import 'package:image_picker/image_picker.dart';
import '../../../../core/services/image_picker_service.dart';
import '../../../../core/providers/base_provider.dart';
import '../../../../data/models/app_image.dart';

class HomeProvider extends BaseProvider {
  HomeProvider({ImagePickerService? imagePicker})
    : _imagePicker = imagePicker ?? DefaultImagePickerService();

  final ImagePickerService _imagePicker;
  AppImage? _selectedImage;

  AppImage? get selectedImage => _selectedImage;

  Future<void> pickImage(ImageSource source) async {
    try {
      setLoading(true);
      clearError();

      final XFile? pickedFile = await _imagePicker.pickImage(source);

      if (pickedFile != null) {
        _selectedImage = await AppImage.fromXFile(pickedFile);
        notifyListeners();
      }
    } on AppImageValidationException catch (e) {
      setError(e.message);
    } catch (e) {
      setError('Unable to read this image. Please try another file.');
    } finally {
      setLoading(false);
    }
  }

  void clearImage() {
    _selectedImage = null;
    notifyListeners();
  }
}
