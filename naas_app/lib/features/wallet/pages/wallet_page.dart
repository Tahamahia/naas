import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/transaction_model.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final ApiClient _api = ApiClient();
  double _balance = 0;
  int _points = 0;
  List<TransactionModel> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final res = await _api.get('/wallet/balance');
      if (res.data['success'] == true && mounted) {
        final data = res.data['data'];
        setState(() {
          _balance = (data['balance'] ?? 0).toDouble();
          _points = data['points'] ?? 0;
          _transactions = (data['transactions'] as List? ?? [])
              .map((t) => TransactionModel.fromJson(t)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDepositSheet() {
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('شحن الرصيد', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('حول المبلغ إلى حساب المنصة ثم أدخل بيانات التحويل', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            TextFormField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'المبلغ (د.ل)', prefixIcon: Icon(Icons.monetization_on)),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: refCtrl,
              decoration: const InputDecoration(labelText: 'رقم العملية', prefixIcon: Icon(Icons.receipt)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (amountCtrl.text.isEmpty) return;
                  try {
                    await _api.post('/wallet/deposit/manual', data: {
                      'amount': double.parse(amountCtrl.text),
                      'reference_number': refCtrl.text,
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم إرسال طلب الشحن، انتظر التأكيد'), backgroundColor: Colors.green),
                      );
                      _loadWallet();
                    }
                  } catch (_) {}
                },
                child: const Text('إرسال طلب الشحن'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Balance card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text('الرصيد الحالي', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text('${_balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        const Text('دينار ليبي', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.stars, color: AppTheme.goldColor, size: 20),
                            const SizedBox(width: 4),
                            Text('$_points نقطة', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showDepositSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('شحن الرصيد'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('آخر العمليات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._transactions.map((t) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _getColor(t.type).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_getIcon(t.type), color: _getColor(t.type)),
                    ),
                    title: Text(t.typeLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(t.createdAt.substring(0, 10)),
                    trailing: Text(
                      '${t.amount > 0 ? '+' : ''}${t.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: t.amount > 0 ? Colors.green : Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )),
              ],
            ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'deposit_manual': return Icons.account_balance;
      case 'payment': return Icons.shopping_cart;
      case 'refund': return Icons.replay;
      case 'commission': return Icons.trending_up;
      default: return Icons.receipt;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'deposit_manual': return Colors.green;
      case 'payment': return Colors.red;
      case 'refund': return Colors.orange;
      case 'commission': return Colors.blue;
      default: return Colors.grey;
    }
  }
}
