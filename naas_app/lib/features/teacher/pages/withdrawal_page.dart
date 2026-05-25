import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class WithdrawalPage extends StatefulWidget {
  const WithdrawalPage({super.key});

  @override
  State<WithdrawalPage> createState() => _WithdrawalPageState();
}

class _WithdrawalPageState extends State<WithdrawalPage> {
  final ApiClient _api = ApiClient();
  final _amountCtrl = TextEditingController();
  Map<String, dynamic>? _earnings;
  List<dynamic> _history = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final earningsRes = await _api.get('/teachers/my/earnings');
      final historyRes = await _api.get('/withdrawals/my');
      if (mounted) {
        setState(() {
          if (earningsRes.data['success'] == true) _earnings = earningsRes.data['data'];
          if (historyRes.data['success'] == true) _history = historyRes.data['data'] as List;
          _loading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _requestWithdrawal() async {
    if (_amountCtrl.text.isEmpty) return;
    
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('الرجاء إدخال مبلغ صحيح'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await _api.post('/withdrawals', data: {'amount': amount});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.data['message'] ?? 'تم إرسال الطلب'),
          backgroundColor: res.data['success'] == true ? Colors.green : AppTheme.errorColor,
        ));
        if (res.data['success'] == true) { _amountCtrl.clear(); _loadData(); }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('حدث خطأ أثناء الإرسال'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب سحب أرباح')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text('الرصيد المتاح للسحب', style: TextStyle(color: Colors.grey)),
                        Text('${(_earnings?['available_balance'] ?? 0).toStringAsFixed(2)} د.ل',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(labelText: 'المبلغ المطلوب', prefixText: 'د.ل '),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                Text('الحد الأدنى للسحب: 10 د.ل', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _requestWithdrawal,
                    child: _submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('طلب سحب'),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('طلبات السحب السابقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._history.map((w) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${w['amount']} د.ل'),
                    subtitle: Text(w['created_at']?.substring(0, 10) ?? ''),
                    trailing: _StatusChip(status: w['status'] ?? ''),
                  ),
                )),
              ],
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    final map = {'pending': 'معلق', 'approved': 'مقبول', 'completed': 'تم الدفع', 'rejected': 'مرفوض'};
    final colors = {'pending': Colors.orange, 'approved': Colors.blue, 'completed': Colors.green, 'rejected': Colors.red};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: (colors[status] ?? Colors.grey).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(map[status] ?? status, style: TextStyle(fontSize: 11, color: colors[status] ?? Colors.grey, fontWeight: FontWeight.w600)),
    );
  }
}
