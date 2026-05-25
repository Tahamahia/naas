import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class AdminRefundsPage extends StatefulWidget {
  const AdminRefundsPage({super.key});

  @override
  State<AdminRefundsPage> createState() => _AdminRefundsPageState();
}

class _AdminRefundsPageState extends State<AdminRefundsPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _refunds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRefunds();
  }

  Future<void> _loadRefunds() async {
    try {
      final res = await _api.get('/admin/transactions', queryParams: {'type': 'refund'});
      if (res.data['success'] == true && mounted) {
        setState(() { _refunds = (res.data['data'] as List).where((r) => r['status'] == 'pending').toList(); _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _processRefund(String refundId, String action) async {
    try {
      final res = await _api.post('/wallet/refund/process', data: {'refund_id': refundId, 'action': action});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.data['message'] ?? 'تم'), backgroundColor: Colors.green));
        _loadRefunds();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات الاسترجاع')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _refunds.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.replay, size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('لا توجد طلبات استرجاع', style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _refunds.length,
                  itemBuilder: (_, i) {
                    final r = _refunds[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text('استرجاع ${r['amount']} د.ل'),
                        subtitle: Text(r['description'] ?? '', maxLines: 2),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _processRefund(r['id'], 'reject'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _processRefund(r['id'], 'approve'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
