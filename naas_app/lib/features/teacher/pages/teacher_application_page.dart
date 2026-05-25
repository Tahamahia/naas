import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class TeacherApplicationPage extends StatefulWidget {
  const TeacherApplicationPage({super.key});

  @override
  State<TeacherApplicationPage> createState() => _TeacherApplicationPageState();
}

class _TeacherApplicationPageState extends State<TeacherApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _api = ApiClient();
  final _bioCtrl = TextEditingController();
  final _qualCtrl = TextEditingController();
  String? _iban;
  String? _bankName;
  String? _accountHolder;
  bool _submitting = false;

  @override
  void dispose() {
    _bioCtrl.dispose();
    _qualCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final res = await _api.post('/teachers/apply', data: {
        'bio': _bioCtrl.text,
        'qualification': _qualCtrl.text,
        'id_document_url': 'https://placeholder.ly/id.pdf',
        'certificate_url': 'https://placeholder.ly/cert.pdf',
        'photo_url': 'https://placeholder.ly/photo.jpg',
        'iban': _iban,
        'bank_name': _bankName,
        'account_holder': _accountHolder,
      });

      if (mounted) {
        if (res.data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تقديم الطلب، انتظر موافقة الإدارة'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? 'فشل'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${e.toString()}'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقديم كأستاذ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.school, size: 60, color: AppTheme.primaryColor),
              const SizedBox(height: 8),
              const Text('انضم كأستاذ في منصة ناس', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('املأ المعلومات أدناه. سيقوم فريقنا بمراجعة طلبك.', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 24),

              TextFormField(
                controller: _bioCtrl,
                decoration: const InputDecoration(labelText: 'نبذة عنك', alignLabelWithHint: true),
                maxLines: 4,
                validator: (v) => v == null || v.length < 10 ? 'اكتب نبذة عن خبراتك' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qualCtrl,
                decoration: const InputDecoration(labelText: 'المؤهلات العلمية'),
                maxLines: 2,
                validator: (v) => v == null || v.length < 2 ? 'أدخل مؤهلاتك' : null,
              ),
              const SizedBox(height: 24),

              const Text('معلومات الحساب البنكي (للسحب)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'IBAN'),
                onChanged: (v) => _iban = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'اسم البنك'),
                onChanged: (v) => _bankName = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'صاحب الحساب'),
                onChanged: (v) => _accountHolder = v,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('إرسال الطلب'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
