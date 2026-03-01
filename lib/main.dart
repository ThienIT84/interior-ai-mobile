import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
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

  // Hàm gửi ảnh sang Backend (GTX 1650)
  Future uploadImage() async {
    if (_image == null) return;
    setState(() => _status = "🚀 Đang gửi sang AI...");

    try {
      // Sử dụng config tự động (localhost với ADB reverse)
      var uri = Uri.parse(AppConfig.predictEndpoint);
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', _image!.path));

      // Send with timeout (120s for SAM processing)
      var streamedResponse = await request.send().timeout(
        AppConfig.uploadTimeout,
        onTimeout: () {
          throw Exception('Upload timeout - SAM processing took too long');
        },
      );
      
      if (streamedResponse.statusCode == 200) {
        var resBody = await streamedResponse.stream.bytesToString();
        setState(() => _status = "✅ AI phản hồi: $resBody");
      } else {
        var errorBody = await streamedResponse.stream.bytesToString();
        setState(() => _status = "❌ Lỗi ${streamedResponse.statusCode}: $errorBody");
      }
    } catch (e) {
      setState(() => _status = "❌ Không kết nối được Server: $e");
    }
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: uploadImage,
                    icon: const Icon(Icons.upload),
                    label: const Text("TEST OLD API"),
                    style: OutlinedButton.styleFrom(
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