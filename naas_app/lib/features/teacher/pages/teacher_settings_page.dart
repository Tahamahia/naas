import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class TeacherSettingsPage extends StatefulWidget {
  const TeacherSettingsPage({super.key});

  @override
  State<TeacherSettingsPage> createState() => _TeacherSettingsPageState();
}

class _TeacherSettingsPageState extends State<TeacherSettingsPage> {
  final ApiClient _api = ApiClient();
  final _ibanCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // The backend needs a route to get and update teacher profile.
      // Assuming GET /teachers/my exists (let's check backend or just use a generic route if it exists)
      final res = await _api.get('/teachers/my/profile');
      if (res.data['success'] == true && mounted) {
        final t = res.data['data'];
        setState(() {
          _ibanCtrl.text = t['iban'] ?? '';
          _bankNameCtrl.text = t['bank_name'] ?? '';
          _accountHolderCtrl.text = t['account_holder'] ?? '';
          _bioCtrl.text = t['bio'] ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final res = await _api.put('/teachers/my/profile', data: {
        'iban': _ibanCtrl.text,
        'bank_name': _bankNameCtrl.text,
        'account_holder': _accountHolderCtrl.text,
        'bio': _bioCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.data['message'] ?? 'تم الحفظ'),
          backgroundColor: res.data['success'] == true ? Colors.green : AppTheme.errorColor,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('حدث خطأ أثناء الحفظ'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _ibanCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountHolderCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات حساب الأستاذ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('تفضيلات السحب البنكي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _accountHolderCtrl,
                  decoration: const InputDecoration(labelText: 'اسم صاحب الحساب'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bankNameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم البنك'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _ibanCtrl,
                  decoration: const InputDecoration(labelText: 'رقم الحساب أو IBAN'),
                ),
                const SizedBox(height: 32),
                const Text('النبذة التعريفية (تظهر للطلاب)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _bioCtrl,
                  decoration: const InputDecoration(labelText: 'نبذة عنك'),
                  maxLines: 4,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('حفظ التغييرات'),
                  ),
                ),
              ],
            ),
    );
  }
}
