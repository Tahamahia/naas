import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/admin/reports');
      if (res.data['success'] == true && mounted) {
        setState(() { _reports = res.data['data'] as List; _loading = false; });
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

  Future<void> _resolveReport(String reportId, String action) async {
    final label = action == 'resolve' ? 'حل' : 'رفض';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label البلاغ'),
        content: Text('هل تريد $label هذا البلاغ؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(label)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.post('/admin/reports/$reportId/resolve', data: {'action': action});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم $label البلاغ'), backgroundColor: Colors.green),
        );
      }
      _loadReports();
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
      appBar: AppBar(title: const Text('إدارة البلاغات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.flag_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد بلاغات', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reports.length,
                    itemBuilder: (_, i) {
                      final r = _reports[i];
                      final isPending = r['status'] == 'pending';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(Icons.flag, color: isPending ? Colors.orange : Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(child: Text(r['type'] ?? 'بلاغ', style: const TextStyle(fontWeight: FontWeight.bold))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(isPending ? 'معلق' : 'تم الحل', style: TextStyle(fontSize: 11, color: isPending ? Colors.orange : Colors.green)),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Text(r['description'] ?? '', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('من: ${r['reporter_name'] ?? r['reporter_email'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            if (isPending) ...[
                              const SizedBox(height: 12),
                              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                OutlinedButton(onPressed: () => _resolveReport(r['id'], 'dismiss'), child: const Text('رفض', style: TextStyle(color: Colors.grey))),
                                const SizedBox(width: 8),
                                ElevatedButton(onPressed: () => _resolveReport(r['id'], 'resolve'), child: const Text('تم الحل')),
                              ]),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
