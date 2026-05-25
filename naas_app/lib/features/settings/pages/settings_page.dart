import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDark = false;

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
                SwitchListTile(
                  title: const Text('الوضع الليلي'),
                  subtitle: const Text('تغيير مظهر التطبيق'),
                  secondary: Icon(_isDark ? Icons.dark_mode : Icons.light_mode, color: _isDark ? Colors.amber : Colors.grey),
                  value: _isDark,
                  onChanged: (v) {
                    setState(() => _isDark = v);
                    // In a full implementation, this would update theme
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('اللغة'),
                  subtitle: const Text('العربية'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('الإشعارات'),
                  subtitle: const Text('إدارة إشعارات التطبيق'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {},
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
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('الشروط و الأحكام'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('سياسة الخصوصية'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('حذف الحساب', style: TextStyle(color: Colors.red)),
              onTap: () {},
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
