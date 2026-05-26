import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';

class AdminDepositsPage extends StatefulWidget {
  const AdminDepositsPage({super.key});

  @override
  State<AdminDepositsPage> createState() => _AdminDepositsPageState();
}

class _AdminDepositsPageState extends State<AdminDepositsPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _deposits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDeposits();
  }

  Future<void> _loadDeposits() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/admin/pending-deposits');
      if (res.data['success'] == true && mounted) {
        setState(() { _deposits = res.data['data'] as List; _loading = false; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _processDeposit(String txId, String action) async {
    final isConfirm = action == 'confirm';
    final label = isConfirm ? 'تأكيد' : 'رفض';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label الإيداع'),
        content: Text('هل تريد $label هذا الإيداع؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: isConfirm ? Colors.green : Colors.red), child: Text(label)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.post('/wallet/deposit/$action', data: {'transaction_id': txId});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم $label الإيداع'), backgroundColor: Colors.green));
      _loadDeposits();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشلت العملية'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الإيداعات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _deposits.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد إيداعات معلقة', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ]))
              : RefreshIndicator(onRefresh: _loadDeposits, child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _deposits.length,
                  itemBuilder: (_, i) {
                    final d = _deposits[i];
                    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.account_balance, color: Colors.indigo),
                        const SizedBox(width: 8),
                        Expanded(child: Text(d['full_name'] ?? d['email'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Text('${d['amount']?.toStringAsFixed(2) ?? '0'} د.ل', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                      ]),
                      const SizedBox(height: 8),
                      if (d['reference_id'] != null) Text('المرجع: ${d['reference_id']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      if (d['created_at'] != null) Text('التاريخ: ${d['created_at']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        OutlinedButton(onPressed: () => _processDeposit(d['id'], 'reject'), child: const Text('رفض', style: TextStyle(color: Colors.red))),
                        const SizedBox(width: 8),
                        ElevatedButton(onPressed: () => _processDeposit(d['id'], 'confirm'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('تأكيد')),
                      ]),
                    ])));
                  },
                )),
    );
  }
}
