import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'screens/segmentation_screen.dart';

void main() => runApp(const MaterialApp(
  home: InteriorApp(),
  debugShowCheckedModeBanner: false,
));

class InteriorApp extends StatefulWidget {
  const InteriorApp({super.key});
  @override
  State<InteriorApp> createState() => _InteriorAppState();
}

class _InteriorAppState extends State<InteriorApp> {
  File? _image;
  final picker = ImagePicker();
  String _status = "Hãy chọn một tấm ảnh nội thất";

  // Hàm chọn ảnh
  Future getImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _status = "Đã chọn ảnh, sẵn sàng gửi!";
      });
    }
  }

  // Navigate to segmentation screen
  void goToSegmentation() {
    if (_image == null) {
      setState(() => _status = "⚠️ Vui lòng chọn ảnh trước!");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SegmentationScreen(imageFile: _image!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Interior Design")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _image == null 
              ? Container(height: 300, color: Colors.grey[200], child: const Icon(Icons.image, size: 100))
              : Image.file(_image!, height: 300),
          const SizedBox(height: 20),
          Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(onPressed: () => getImage(ImageSource.camera), icon: const Icon(Icons.camera), label: const Text("Chụp ảnh")),
              ElevatedButton.icon(onPressed: () => getImage(ImageSource.gallery), icon: const Icon(Icons.photo), label: const Text("Thư viện")),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: goToSegmentation,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text("START SEGMENTATION"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}