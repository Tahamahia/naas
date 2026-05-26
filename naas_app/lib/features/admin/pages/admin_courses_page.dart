import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class AdminCoursesPage extends StatefulWidget {
  const AdminCoursesPage({super.key});

  @override
  State<AdminCoursesPage> createState() => _AdminCoursesPageState();
}

class _AdminCoursesPageState extends State<AdminCoursesPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _courses = [];
  bool _loading = true;
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{'limit': '100'};
      if (_statusFilter.isNotEmpty) params['status'] = _statusFilter;
      final res = await _api.get('/admin/courses', queryParams: params);
      if (res.data['success'] == true && mounted) {
        setState(() { _courses = res.data['data'] as List; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _changeStatus(String courseId, String newStatus) async {
    final label = newStatus == 'published' ? 'نشر' : newStatus == 'disabled' ? 'تعطيل' : newStatus;
    try {
      await _api.put('/admin/courses/$courseId/status', data: {'status': newStatus});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم $label الكورس'), backgroundColor: Colors.green));
      _loadCourses();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشلت العملية'), backgroundColor: Colors.red));
    }
  }

  Color _statusColor(String? s) => switch(s) { 'published' => Colors.green, 'draft' => Colors.grey, 'pending' => Colors.orange, 'disabled' => Colors.red, _ => Colors.grey };
  String _statusLabel(String? s) => switch(s) { 'published' => 'منشور', 'draft' => 'مسودة', 'pending' => 'معلق', 'disabled' => 'معطل', _ => s ?? '' };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الكورسات')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          ChoiceChip(label: const Text('الكل'), selected: _statusFilter.isEmpty, onSelected: (_) { _statusFilter = ''; _loadCourses(); }),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('منشور'), selected: _statusFilter == 'published', onSelected: (_) { _statusFilter = 'published'; _loadCourses(); }),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('مسودة'), selected: _statusFilter == 'draft', onSelected: (_) { _statusFilter = 'draft'; _loadCourses(); }),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('معلق'), selected: _statusFilter == 'pending', onSelected: (_) { _statusFilter = 'pending'; _loadCourses(); }),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('معطل'), selected: _statusFilter == 'disabled', onSelected: (_) { _statusFilter = 'disabled'; _loadCourses(); }),
        ]))),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _courses.isEmpty
                ? const Center(child: Text('لا توجد كورسات', style: TextStyle(fontSize: 18, color: Colors.grey)))
                : RefreshIndicator(onRefresh: _loadCourses, child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _courses.length,
                    itemBuilder: (_, i) {
                      final c = _courses[i];
                      return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                        title: Text(c['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${c['teacher_name'] ?? ''} • ${c['price'] ?? 0} د.ل', style: const TextStyle(fontSize: 12)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: _statusColor(c['status']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(_statusLabel(c['status']), style: TextStyle(fontSize: 11, color: _statusColor(c['status']))),
                          ),
                          PopupMenuButton(itemBuilder: (_) => [
                            if (c['status'] != 'published') const PopupMenuItem(value: 'published', child: Text('نشر', style: TextStyle(color: Colors.green))),
                            if (c['status'] != 'disabled') const PopupMenuItem(value: 'disabled', child: Text('تعطيل', style: TextStyle(color: Colors.red))),
                            if (c['status'] == 'disabled') const PopupMenuItem(value: 'draft', child: Text('إرجاع كمسودة')),
                          ], onSelected: (v) => _changeStatus(c['id'], v.toString())),
                        ]),
                      ));
                    },
                  ))),
      ]),
    );
  }
}
