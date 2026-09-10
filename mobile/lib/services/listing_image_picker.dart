import 'package:image_picker/image_picker.dart';

abstract class ListingImagePicker {
  Future<XFile?> takePhoto();

  Future<List<XFile>> chooseFromGallery({required int limit});

  Future<List<XFile>> recoverLostPhotos();
}

class DeviceListingImagePicker implements ListingImagePicker {
  final ImagePicker _picker;

  DeviceListingImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  @override
  Future<XFile?> takePhoto() {
    return _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      imageQuality: 88,
    );
  }

  @override
  Future<List<XFile>> chooseFromGallery({required int limit}) {
    return _picker.pickMultiImage(
      maxWidth: 2048,
      imageQuality: 88,
      limit: limit,
    );
  }

  @override
  Future<List<XFile>> recoverLostPhotos() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) {
        return const [];
      }
      if (response.exception != null) {
        throw response.exception!;
      }
      if (response.files != null) {
        return response.files!;
      }
      return <XFile>[if (response.file != null) response.file!];
    } on UnimplementedError {
      // Lost-data recovery is an Android-only API.
      return const [];
    }
  }
}
