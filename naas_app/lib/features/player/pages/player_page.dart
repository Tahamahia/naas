import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../models/course_model.dart';

class PlayerPage extends StatefulWidget {
  final LessonModel lesson;
  const PlayerPage({super.key, required this.lesson});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final ApiClient _api = ApiClient();
  bool _isPlaying = true;
  int _progressSeconds = 0;
  late String _viewId;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _viewId = 'video-player-${widget.lesson.id}';
    _registerVideoView();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isPlaying) {
        _progressSeconds += 30;
        try {
          await _api.put('/progress/${widget.lesson.id}', data: {
            'progress_seconds': _progressSeconds,
            'total_seconds': widget.lesson.videoDuration ?? 0,
            'completed': _progressSeconds >= (widget.lesson.videoDuration ?? 0) ? 1 : 0,
          });
        } catch (_) {}
      }
    });
  }

  void _registerVideoView() {
    final videoUrl = widget.lesson.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        if (videoUrl.contains('.mp4') || videoUrl.contains('.m3u8') || videoUrl.contains('.webm')) {
          // رابط فيديو مباشر - استخدم عنصر video HTML5
          final videoElement = web.document.createElement('video') as web.HTMLVideoElement;
          videoElement.src = videoUrl;
          videoElement.controls = true;
          videoElement.autoplay = true;
          videoElement.style.width = '100%';
          videoElement.style.height = '100%';
          videoElement.style.backgroundColor = 'black';
          videoElement.style.objectFit = 'contain';
          videoElement.setAttribute('playsinline', 'true');
          return videoElement;
        } else {
          // رابط بث (مثل Bunny CDN embed) - استخدم iframe
          final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
          iframe.src = videoUrl;
          iframe.style.width = '100%';
          iframe.style.height = '100%';
          iframe.style.border = 'none';
          iframe.style.backgroundColor = 'black';
          iframe.allow = 'accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture';
          iframe.setAttribute('allowfullscreen', 'true');
          return iframe;
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title, style: const TextStyle(fontSize: 16)),
      ),
      body: Column(
        children: [
          // Video / PDF / Article area
          Expanded(
            child: lesson.type == 'video'
                ? _buildVideoPlayer(lesson)
                : lesson.type == 'pdf'
                    ? _buildPdfViewer(lesson)
                    : lesson.type == 'article'
                        ? _buildArticleViewer(lesson)
                        : _buildPlaceholder(lesson),
          ),

          // Bottom controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (lesson.videoDuration != null)
                        Text('المدة: ${Duration(seconds: lesson.videoDuration!).toString().substring(2, 7)}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(LessonModel lesson) {
    if (lesson.videoUrl == null || lesson.videoUrl!.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, size: 80, color: Colors.white38),
              SizedBox(height: 16),
              Text('رابط الفيديو غير متوفر', style: TextStyle(color: Colors.white70, fontSize: 18)),
            ],
          ),
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: HtmlElementView(viewType: _viewId),
    );
  }

  Widget _buildPdfViewer(LessonModel lesson) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text('عارض PDF', style: TextStyle(fontSize: 18)),
          if (lesson.pdfName != null)
            Text(lesson.pdfName!, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (lesson.pdfUrl != null && lesson.pdfUrl!.isNotEmpty) {
                // Open PDF in new tab via url_launcher or web approach
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('جاري فتح الملف...')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ملف PDF غير متوفر')),
                );
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('تحميل PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleViewer(LessonModel lesson) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lesson.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(lesson.articleContent ?? 'المحتوى غير متوفر',
            style: const TextStyle(fontSize: 16, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(LessonModel lesson) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.live_tv, size: 80, color: Colors.purple.shade200),
          const SizedBox(height: 16),
          Text('${lesson.type} - ${lesson.title}', style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
