import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class BundlesPage extends StatefulWidget {
  const BundlesPage({super.key});

  @override
  State<BundlesPage> createState() => _BundlesPageState();
}

class _BundlesPageState extends State<BundlesPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _bundles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBundles();
  }

  Future<void> _loadBundles() async {
    try {
      final res = await _api.get('/bundles');
      if (res.data['success'] == true && mounted) {
        setState(() { _bundles = res.data['data'] as List; _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _purchaseBundle(String bundleId) async {
    try {
      final res = await _api.post('/bundles/$bundleId/purchase');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.data['message'] ?? 'تم الشراء'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل'), backgroundColor: AppTheme.errorColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حزم الكورسات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bundles.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_offer, size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('لا توجد حزم حالياً', style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bundles.length,
                  itemBuilder: (_, i) {
                    final b = _bundles[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            if (b['description'] != null) ...[
                              const SizedBox(height: 4),
                              Text(b['description'], style: TextStyle(color: Colors.grey.shade600)),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (b['discount_percent'] != null && (b['discount_percent'] as num) > 0)
                                      Text('خصم ${b['discount_percent']}%', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                    Text('${b['price']} د.ل', style: TextStyle(
                                      fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () => _purchaseBundle(b['id']),
                                  child: const Text('اشترِ الحزمة'),
                                ),
                              ],
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
