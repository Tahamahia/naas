import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class AdminWithdrawalsPage extends StatefulWidget {
  const AdminWithdrawalsPage({super.key});

  @override
  State<AdminWithdrawalsPage> createState() => _AdminWithdrawalsPageState();
}

class _AdminWithdrawalsPageState extends State<AdminWithdrawalsPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _withdrawals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWithdrawals();
  }

  Future<void> _loadWithdrawals() async {
    try {
      final res = await _api.get('/withdrawals/pending');
      if (res.data['success'] == true && mounted) {
        setState(() { _withdrawals = res.data['data'] as List; _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _processWithdrawal(String id, String action) async {
    try {
      final res = await _api.post('/withdrawals/$id/process', data: {'action': action, 'proof_url': action == 'approve' ? 'manual_transfer' : null});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.data['message'] ?? 'تم'), backgroundColor: Colors.green));
        _loadWithdrawals();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات السحب')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _withdrawals.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.money_off, size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('لا توجد طلبات سحب معلقة', style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadWithdrawals,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _withdrawals.length,
                    itemBuilder: (_, i) {
                      final w = _withdrawals[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('${w['full_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Text('${w['amount']} د.ل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('IBAN: ${w['iban'] ?? '-'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              if (w['bank_name'] != null) Text('البنك: ${w['bank_name']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              if (w['account_holder'] != null) Text('صاحب الحساب: ${w['account_holder']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              Text('طلب: ${w['created_at']?.substring(0, 16) ?? ""}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _processWithdrawal(w['id'], 'reject'),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('رفض'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _processWithdrawal(w['id'], 'approve'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    child: const Text('تم التحويل'),
                                  ),
                                ],
                              ),
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
