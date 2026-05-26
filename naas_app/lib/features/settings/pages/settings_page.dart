import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../auth/bloc/auth_bloc.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ApiClient _api = ApiClient();

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'هل أنت متأكد من حذف حسابك نهائياً؟\n\nسيتم حذف جميع بياناتك ولن تتمكن من استرجاعها.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف نهائياً'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // تأكيد ثاني
    final doubleConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد أخير'),
        content: const Text('هذا الإجراء لا يمكن التراجع عنه. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا، تراجع')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، احذف حسابي'),
          ),
        ],
      ),
    );
    if (doubleConfirm != true || !mounted) return;

    try {
      await _api.delete('/auth/account');
      if (mounted) {
        context.read<AuthBloc>().add(LogoutEvent());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف حسابك بنجاح'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل حذف الحساب'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('اللغة'),
                  subtitle: const Text('العربية'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('اللغة العربية هي اللغة الوحيدة المدعومة حالياً')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('الإشعارات'),
                  subtitle: const Text('إدارة إشعارات التطبيق'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('إعدادات الإشعارات ستتوفر في التحديث القادم')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blue),
                  title: const Text('حول التطبيق'),
                  subtitle: const Text('ناس — منصة تعليمية ليبية'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'ناس',
                      applicationVersion: '1.0.0',
                      children: [const Text('منصة تعليمية ليبية لتعلم من أفضل الأساتذة')],
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('الشروط و الأحكام'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الشروط والأحكام ستتوفر قريباً')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('سياسة الخصوصية'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('سياسة الخصوصية ستتوفر قريباً')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('حذف الحساب', style: TextStyle(color: Colors.red)),
              subtitle: const Text('حذف حسابك وجميع بياناتك نهائياً'),
              onTap: _deleteAccount,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('الإصدار 1.0.0', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
