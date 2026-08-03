import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/datasources/remote_datasource.dart';
import '../../../data/exceptions/remote_data_source_exception.dart';

enum InpaintingStatus {
  initializing,
  submitting,
  processing,
  completed,
  failed,
}

class InpaintingProvider extends ChangeNotifier {
  InpaintingProvider({
    RemoteDataSource? dataSource,
    Duration pollInterval = const Duration(seconds: 3),
    int maxPolls = 300,
  }) : _dataSource = dataSource ?? RemoteDataSource(),
       _pollInterval = pollInterval,
       _maxPolls = maxPolls;

  final RemoteDataSource _dataSource;
  final Duration _pollInterval;
  final int _maxPolls;

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
  bool _disposed = false;

  // Getters
  InpaintingStatus get status => _status;
  double get progress => _progress;
  String? get resultUrl => _resultUrl;
  String? get errorMessage => _errorMessage;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isProcessing =>
      _status == InpaintingStatus.processing ||
      _status == InpaintingStatus.submitting;
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
    _disposed = true;
    _pollTimer?.cancel();
    _timeTimer?.cancel();
    super.dispose();
  }

  void _startTimeCounter() {
    _timeTimer?.cancel();
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isProcessing) {
        _elapsedSeconds++;
        _notify();
      }
    });
  }

  Future<void> _startInpainting() async {
    if (_imageId == null || _maskId == null) return;

    try {
      _status = InpaintingStatus.submitting;
      _progress = 0.1;
      _errorMessage = null;
      _notify();

      final jobId = await _dataSource.submitInpainting(
        imageId: _imageId!,
        maskId: _maskId!,
      );
      if (_disposed) return;

      _jobId = jobId;
      _status = InpaintingStatus.processing;
      _progress = 0.2;
      _notify();

      // Start polling
      _startPolling();
    } on RemoteDataSourceException catch (error) {
      _status = InpaintingStatus.failed;
      _errorMessage = error.isRedisUnavailable
          ? 'Background processing is temporarily unavailable. '
                'Please start Redis and try again.'
          : error.message;
      _notify();
    } catch (_) {
      _status = InpaintingStatus.failed;
      _errorMessage = 'Inpainting submission failed. Please try again.';
      _notify();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    int pollCount = 0;
    _pollTimer = Timer.periodic(_pollInterval, (timer) async {
      if (_disposed) {
        timer.cancel();
        return;
      }
      if (_jobId == null) return;

      pollCount++;
      if (pollCount > _maxPolls) {
        _status = InpaintingStatus.failed;
        _errorMessage = 'Processing timeout. Please try again.';
        timer.cancel();
        _notify();
        return;
      }

      try {
        final statusResponse = await _dataSource.checkJobStatus(
          _jobId!,
          type: 'inpainting',
        );

        final String remoteStatus = statusResponse['status'] ?? 'unknown';
        _progress =
            (statusResponse['progress'] as num?)?.toDouble() ?? _progress;

        if (remoteStatus == 'completed') {
          _status = InpaintingStatus.completed;
          _resultUrl = statusResponse['result_url'];
          timer.cancel();
        } else if (remoteStatus == 'failed') {
          _status = InpaintingStatus.failed;
          _errorMessage = statusResponse['error'] ?? 'Unknown backend error';
          timer.cancel();
        }

        _notify();
      } catch (e) {
        // Continue polling on transient errors
      }
    });
  }

  void retry() {
    _pollTimer?.cancel();
    _elapsedSeconds = 0;
    _resultUrl = null;
    _startInpainting();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
