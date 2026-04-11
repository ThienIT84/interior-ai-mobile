import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../presentation/generation/views/generation_view.dart';

/// Screen to display inpainting progress and result
class InpaintingScreen extends StatefulWidget {
  final String imageId;
  final String maskId;

  const InpaintingScreen({
    Key? key,
    required this.imageId,
    required this.maskId,
  }) : super(key: key);

  @override
  State<InpaintingScreen> createState() => _InpaintingScreenState();
}

class _InpaintingScreenState extends State<InpaintingScreen> {
  final ApiService _apiService = ApiService();
  
  String? _jobId;
  String _status = 'Initializing...';
  double _progress = 0.0;
  String? _resultUrl;
  String? _error;
  Timer? _pollTimer;
  
  bool _isProcessing = true;
  int _elapsedSeconds = 0;
  Timer? _timeTimer;

  @override
  void initState() {
    super.initState();
    _startInpainting();
    _startTimeCounter();
    _startTipTimer();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _timeTimer?.cancel();
    _tipTimer?.cancel();
    super.dispose();
  }

  void _startTimeCounter() {
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isProcessing) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _startInpainting() async {
    try {
      setState(() {
        _status = 'Submitting job...';
        _progress = 0.1;
      });

      // Submit async job
      final jobId = await _apiService.removeObjectAsync(
        imageId: widget.imageId,
        maskId: widget.maskId,
      );

      setState(() {
        _jobId = jobId;
        _status = 'Processing...';
        _progress = 0.2;
      });

      // Wait 2 seconds for backend to start background task
      await Future.delayed(const Duration(seconds: 2));

      // Start polling for status
      _startPolling();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  void _startPolling() {
    int pollCount = 0;
    const maxPolls = 300; // 300 * 3s = 15 minutes max
    
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_jobId == null) return;
      
      pollCount++;
      
      // Timeout after 15 minutes
      if (pollCount > maxPolls) {
        if (mounted) {
          setState(() {
            _error = 'Processing timeout after 15 minutes. Please check backend logs.';
            _isProcessing = false;
          });
        }
        timer.cancel();
        return;
      }

      try {
        final status = await _apiService.checkJobStatus(_jobId!);
        
        if (!mounted) return;

        setState(() {
          _status = status['status'] ?? 'Unknown';
          _progress = (status['progress'] as num?)?.toDouble() ?? _progress;
          
          if (status['status'] == 'completed') {
            _isProcessing = false;
            _tipTimer?.cancel();
            _resultUrl = status['result_url'];
            timer.cancel();
          } else if (status['status'] == 'failed') {
            _isProcessing = false;
            _tipTimer?.cancel();
            _error = status['error'] ?? 'Unknown error';
            timer.cancel();
          }
        });
      } catch (e) {
        // Continue polling on temporary errors
        // Don't show error to user, just keep polling
        // Backend might be busy processing
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Removing Object'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildError();
    }

    if (_resultUrl != null) {
      return _buildResult();
    }

    return _buildProcessing();
  }

  Future<void> _saveToGallery(String imageUrl) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Downloading image...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      // Download image
      final response = await http.get(Uri.parse(imageUrl));
      
      if (response.statusCode == 200) {
        // Save to gallery
        await Gal.putImageBytes(
          response.bodyBytes,
          name: "inpaint_result_${DateTime.now().millisecondsSinceEpoch}",
        );
        
        // Hide loading and show success
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 16),
                Text('Saved to gallery!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(child: Text('Save failed: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _shareImage(String imageUrl) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Preparing to share...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      // Download image
      final response = await http.get(Uri.parse(imageUrl));
      
      if (response.statusCode == 200) {
        // Save to temp directory
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/inpaint_result_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(response.bodyBytes);
        
        // Hide loading
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        // Share
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Check out my AI-generated empty room! 🏠✨',
        );
      } else {
        throw Exception('Failed to download image: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(child: Text('Share failed: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildImagePage({
    required String imageUrl,
    required String label,
    required Color labelColor,
  }) {
    return Stack(
      children: [
        // Image
        Center(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Failed to load image: $error'),
                ],
              );
            },
          ),
        ),
        
        // Label badge
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: labelColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        // Swipe hint
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.swipe, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Swipe to compare',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Premium UI ─────────────────────────────────────────────────────────────
  
  int _currentTipIndex = 0;
  Timer? _tipTimer;
  final List<String> _loadingTips = [
    "Việc xóa vật thể giúp AI hiểu rõ cấu trúc phòng hơn.",
    "Chọn vùng sát vật thể để kết quả xóa tự nhiên nhất.",
    "Bề mặt phẳng (sàn, tường) là nơi AI hoạt động tốt nhất.",
    "Mẹo: Xóa bớt đồ cũ trước khi thiết kế mới giúp AI sáng tạo hơn.",
    "Đang phân tích các điểm ảnh xung quanh để bù đắp vùng trống.",
    "AI đang tái tạo lại vân gỗ và hoa văn tường một cách liền mạch.",
    "Phòng trống là bước đệm hoàn hảo cho một thiết kế đột phá."
  ];

  void _startTipTimer() {
    _tipTimer?.cancel();
    _currentTipIndex = Random().nextInt(_loadingTips.length);
    _tipTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _isProcessing) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _loadingTips.length;
        });
      }
    });
  }

  Widget _buildProcessing() {
    // Determine current step based on progress
    int currentStep = 1;
    if (_progress > 0.3) currentStep = 2;
    if (_progress > 0.8) currentStep = 3;

    final List<Map<String, dynamic>> steps = [
      {'title': 'Phân tích', 'icon': Icons.search},
      {'title': 'AI Xóa', 'icon': Icons.auto_fix_high},
      {'title': 'Hoàn thiện', 'icon': Icons.check_circle_outline},
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[50]!, Colors.grey[200]!],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Upper Section: Icon & Steps
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(steps.length, (index) {
                bool isActive = currentStep >= index + 1;
                bool isDone = currentStep > index + 1;
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDone ? Colors.green : (isActive ? Colors.deepPurple : Colors.white),
                        shape: BoxShape.circle,
                        boxShadow: isActive ? [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 8)] : [],
                      ),
                      child: Icon(
                        isDone ? Icons.check : steps[index]['icon'] as IconData,
                        color: (isActive || isDone) ? Colors.white : Colors.grey[400],
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[index]['title'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? Colors.deepPurple : Colors.grey[500],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          
          const SizedBox(height: 60),

          // Central Pulse Animation
          Stack(
            alignment: Alignment.center,
            children: [
              _buildPulseCircle(160, Colors.deepPurple.withOpacity(0.05)),
              _buildPulseCircle(120, Colors.deepPurple.withOpacity(0.1)),
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 2)],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(_elapsedSeconds),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.deepPurple),
                      ),
                      const Text('elapsed', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              // Circular progress
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 4,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 50),

          // Status & Info Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white),
              ),
              child: Column(
                children: [
                  Text(
                    _status,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Quá trình này thường mất 15-45 giây',
                    style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 15),
                  // Rotating Tips
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            _loadingTips[_currentTipIndex],
                            key: ValueKey<int>(_currentTipIndex),
                            style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          Text(
            'Powered by AI Removal Engine',
            style: TextStyle(color: Colors.grey[400], fontSize: 11, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseCircle(double size, Color color) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.8, end: 1.2),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (context, double value, child) {
        return Container(
          width: size * value,
          height: size * value,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
      },
      onEnd: () => setState(() {}),
    );
  }

  Widget _buildResult() {
    final fullResultUrl = '${_apiService.getResultUrl(_resultUrl!.split('/').last)}';
    final originalImageUrl = _apiService.getImageUrl(widget.imageId);
    
    return Column(
      children: [
        Expanded(
          child: PageView(
            children: [
              // Before (Original)
              _buildImagePage(
                imageUrl: originalImageUrl,
                label: 'BEFORE',
                labelColor: Colors.orange,
              ),
              // After (Result)
              _buildImagePage(
                imageUrl: fullResultUrl,
                label: 'AFTER',
                labelColor: Colors.green,
              ),
            ],
          ),
        ),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Object Removed Successfully!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Completed in ${_formatTime(_elapsedSeconds)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _saveToGallery(fullResultUrl);
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _shareImage(fullResultUrl);
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final resultId = _resultUrl!.split('/').last;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GenerationView(
                              imageId: resultId,
                              imageUrl: _apiService.getResultUrl(resultId),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generate Design'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Processing Failed',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 32),
            
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
