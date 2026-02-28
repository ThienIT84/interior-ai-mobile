import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';

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
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _timeTimer?.cancel();
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
            _resultUrl = status['result_url'];
            timer.cancel();
          } else if (status['status'] == 'failed') {
            _isProcessing = false;
            _error = status['error'] ?? 'Unknown error';
            timer.cancel();
          }
        });
      } catch (e) {
        // Continue polling on temporary errors
        print('Polling error (attempt $pollCount/$maxPolls): $e');
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

  Widget _buildProcessing() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: 0.8 + (value * 0.2),
                  child: const Icon(
                    Icons.auto_fix_high,
                    size: 80,
                    color: Colors.deepPurple,
                  ),
                );
              },
              onEnd: () {
                // Loop animation
                if (mounted && _isProcessing) {
                  setState(() {});
                }
              },
            ),
            
            const SizedBox(height: 32),
            
            // Status text
            Text(
              _status,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Progress bar
            SizedBox(
              width: 250,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                minHeight: 8,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              '${(_progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Time elapsed
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(_elapsedSeconds),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Info text
            Text(
              'This may take 13-15 minutes',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Using AI to remove object and\ngenerate empty room',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final fullResultUrl = '${_apiService.getResultUrl(_resultUrl!.split('/').last)}';
    
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Image.network(
              fullResultUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const CircularProgressIndicator();
              },
              errorBuilder: (context, error, stackTrace) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Failed to load result: $error'),
                  ],
                );
              },
            ),
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
                        // TODO: Navigate to generation screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Design generation coming soon!'),
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
