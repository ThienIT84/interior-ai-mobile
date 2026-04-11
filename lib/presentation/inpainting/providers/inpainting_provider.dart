import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

enum InpaintingStatus {
  initializing,
  submitting,
  processing,
  completed,
  failed,
}

class InpaintingProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  String? _jobId;
  String? _imageId;
  String? _maskId;
  
  InpaintingStatus _status = InpaintingStatus.initializing;
  double _progress = 0.0;
  String? _resultUrl;
  String? _errorMessage;
  
  Timer? _pollTimer;
  int _elapsedSeconds = 0;
  Timer? _timeTimer;

  // Getters
  InpaintingStatus get status => _status;
  double get progress => _progress;
  String? get resultUrl => _resultUrl;
  String? get errorMessage => _errorMessage;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isProcessing => _status == InpaintingStatus.processing || _status == InpaintingStatus.submitting;
  String? get imageId => _imageId;

  String get statusText {
    switch (_status) {
      case InpaintingStatus.initializing:
        return 'Ready to start...';
      case InpaintingStatus.submitting:
        return 'Submitting to AI...';
      case InpaintingStatus.processing:
        return 'AI is removing objects...';
      case InpaintingStatus.completed:
        return 'Removal complete!';
      case InpaintingStatus.failed:
        return 'Process failed';
    }
  }

  void initialize(String imageId, String maskId) {
    _imageId = imageId;
    _maskId = maskId;
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
    _timeTimer?.cancel();
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isProcessing) {
        _elapsedSeconds++;
        notifyListeners();
      }
    });
  }

  Future<void> _startInpainting() async {
    if (_imageId == null || _maskId == null) return;

    try {
      _status = InpaintingStatus.submitting;
      _progress = 0.1;
      _errorMessage = null;
      notifyListeners();

      final jobId = await _apiService.removeObjectAsync(
        imageId: _imageId!,
        maskId: _maskId!,
      );

      _jobId = jobId;
      _status = InpaintingStatus.processing;
      _progress = 0.2;
      notifyListeners();

      // Start polling
      _startPolling();
    } catch (e) {
      _status = InpaintingStatus.failed;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    int pollCount = 0;
    const maxPolls = 300; // 15 minutes
    
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_jobId == null) return;
      
      pollCount++;
      if (pollCount > maxPolls) {
        _status = InpaintingStatus.failed;
        _errorMessage = 'Processing timeout. Please try again.';
        timer.cancel();
        notifyListeners();
        return;
      }

      try {
        final statusResponse = await _apiService.checkJobStatus(_jobId!);
        
        final String remoteStatus = statusResponse['status'] ?? 'unknown';
        _progress = (statusResponse['progress'] as num?)?.toDouble() ?? _progress;
        
        if (remoteStatus == 'completed') {
          _status = InpaintingStatus.completed;
          _resultUrl = statusResponse['result_url'];
          timer.cancel();
        } else if (remoteStatus == 'failed') {
          _status = InpaintingStatus.failed;
          _errorMessage = statusResponse['error'] ?? 'Unknown backend error';
          timer.cancel();
        }
        
        notifyListeners();
      } catch (e) {
        // Continue polling on transient errors
      }
    });
  }

  void retry() {
    _elapsedSeconds = 0;
    _resultUrl = null;
    _startInpainting();
  }
}
