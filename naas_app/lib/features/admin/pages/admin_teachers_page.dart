import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class AdminTeachersPage extends StatefulWidget {
  const AdminTeachersPage({super.key});

  @override
  State<AdminTeachersPage> createState() => _AdminTeachersPageState();
}

class _AdminTeachersPageState extends State<AdminTeachersPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/teachers/pending');
      if (res.data['success'] == true && mounted) {
        setState(() { _pending = res.data['data'] as List; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleAction(String teacherId, String action) async {
    final isApprove = action == 'approve';
    final label = isApprove ? 'قبول' : 'رفض';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label الطلب'),
        content: Text('هل تريد $label هذا الطلب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: isApprove ? Colors.green : Colors.red),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.post('/teachers/$teacherId/$action');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم $label الطلب بنجاح'), backgroundColor: Colors.green),
        );
      }
      _loadPending();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشلت العملية'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات الأساتذة المعلقة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
              ? const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                    SizedBox(height: 16),
                    Text('لا توجد طلبات معلقة', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadPending,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pending.length,
                    itemBuilder: (_, i) {
                      final t = _pending[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                CircleAvatar(backgroundColor: Colors.orange, child: Text((t['full_name'] as String? ?? '?')[0], style: const TextStyle(color: Colors.white))),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(t['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(t['email'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                ])),
                              ]),
                              const Divider(height: 24),
                              if (t['specialization'] != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('التخصص: ${t['specialization']}', style: const TextStyle(fontSize: 13))),
                              if (t['bio'] != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('النبذة: ${t['bio']}', style: const TextStyle(fontSize: 13))),
                              const SizedBox(height: 8),
                              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                OutlinedButton.icon(
                                  onPressed: () => _handleAction(t['id'], 'reject'),
                                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                  label: const Text('رفض', style: TextStyle(color: Colors.red)),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _handleAction(t['id'], 'approve'),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('قبول'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
