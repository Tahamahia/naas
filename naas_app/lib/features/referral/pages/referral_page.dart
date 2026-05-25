import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  final ApiClient _api = ApiClient();
  String? _code;
  int _totalReferrals = 0;
  double _totalEarned = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final res = await _api.get('/referral/stats');
      if (res.data['success'] == true && mounted) {
        final d = res.data['data'];
        setState(() {
          _code = d['referral_code'];
          _totalReferrals = d['total_referrals'] ?? 0;
          _totalEarned = (d['total_earned'] ?? 0).toDouble();
          _loading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _redeemCode() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة كود إحالة'),
        content: TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'كود الإحالة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () async {
            try {
              final res = await _api.post('/referral/redeem', data: {'code': codeCtrl.text});
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(res.data['message'] ?? 'تم'),
                  backgroundColor: res.data['success'] == true ? Colors.green : AppTheme.errorColor,
                ));
                if (res.data['success'] == true) _loadStats();
              }
            } catch (_) {}
          }, child: const Text('تأكيد')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإحالة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.share, size: 60, color: AppTheme.primaryColor),
                        const SizedBox(height: 8),
                        const Text('ادعُ أصدقاءك و اكسب رصيداً مجاناً!', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('كل صديق يسجل بكودك تكسب أنت وهو ${1.0} د.ل', style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 16),
                        if (_code != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_code!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _code!));
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ')));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _StatCard(label: 'الأصدقاء', value: '$_totalReferrals', icon: Icons.people, color: Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(label: 'المكاسب', value: '${_totalEarned.toStringAsFixed(2)} د.ل', icon: Icons.monetization_on, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _redeemCode,
                    icon: const Icon(Icons.discount),
                    label: const Text('عندي كود إحالة'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
