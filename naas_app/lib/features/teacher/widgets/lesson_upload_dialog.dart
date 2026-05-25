import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class LessonUploadDialog extends StatefulWidget {
  final String courseId;
  final String sectionId;

  const LessonUploadDialog({
    super.key,
    required this.courseId,
    required this.sectionId,
  });

  @override
  State<LessonUploadDialog> createState() => _LessonUploadDialogState();
}

class _LessonUploadDialogState extends State<LessonUploadDialog> {
  final _titleCtrl = TextEditingController();
  XFile? _selectedFile;
  int? _fileLength;
  bool _uploading = false;
  double _progress = 0.0;
  String _status = '';
  final ApiClient _api = ApiClient();

  Future<void> _pickFile() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'videos',
        extensions: <String>['mp4', 'mov', 'avi', 'mkv'],
      );
      final XFile? video = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (video != null) {
        final length = await video.length();
        setState(() {
          _selectedFile = video;
          _fileLength = length;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('حدث خطأ أثناء فتح مدير الملفات: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _upload() async {
    if (_titleCtrl.text.isEmpty || _selectedFile == null || _fileLength == null) return;
    setState(() {
      _uploading = true;
      _status = 'جاري إنشاء الدرس...';
    });

    try {
      // 1. Create video in Bunny Stream via backend
      final res = await _api.post(
        '/courses/${widget.courseId}/sections/${widget.sectionId}/bunny-video',
        data: {'title': _titleCtrl.text},
      );

      if (res.data['success'] == true) {
        final data = res.data['data'];
        final String videoId = data['guid'];
        final String libraryId = data['libraryId'].toString();
        final String uploadKey = data['uploadKey'];

        setState(() {
          _status = 'جاري رفع الفيديو...';
        });

        // 2. Upload video file to Bunny Stream directly
        final dio = Dio();
        final url = 'https://video.bunnycdn.com/library/$libraryId/videos/$videoId';

        await dio.put(
          url,
          data: _selectedFile!.openRead(),
          options: Options(
            headers: {
              'AccessKey': uploadKey,
              'Content-Type': 'application/octet-stream',
              'Content-Length': _fileLength.toString(),
            },
          ),
          onSendProgress: (sent, total) {
            setState(() {
              _progress = sent / total;
              if (_progress >= 1.0) {
                _status = 'جاري معالجة الفيديو...';
              }
            });
          },
        );

        if (mounted) {
          Navigator.pop(context, true); // success
        }
      } else {
        setState(() {
          _status = 'حدث خطأ: ${res.data['message']}';
          _uploading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'حدث خطأ أثناء الرفع';
        _uploading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة درس فيديو'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'عنوان الدرس'),
              enabled: !_uploading,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _pickFile,
                icon: const Icon(Icons.video_file),
                label: Text(
                  _selectedFile != null ? _selectedFile!.name : 'اختر ملف فيديو',
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedFile != null ? Colors.green.shade50 : null,
                  foregroundColor: _selectedFile != null ? Colors.green : null,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            if (_uploading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]
          ],
        ),
      ),
      actions: [
        if (!_uploading)
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: (_uploading || _selectedFile == null) ? null : _upload,
          child: const Text('رفع وحفظ'),
        ),
      ],
    );
  }
}
