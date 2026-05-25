import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/wallet/pages/wallet_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) =>
      b.state is AuthAuthenticated ? (b.state as AuthAuthenticated).user : null);

    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                    child: user.avatarUrl == null ? Text(user.fullName[0], style: const TextStyle(fontSize: 24)) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(user.email, style: TextStyle(color: Colors.grey.shade600)),
                        if (user.role == 'teacher')
                          Chip(
                            label: const Text('أستاذ', style: TextStyle(fontSize: 11)),
                            backgroundColor: Colors.green.shade50,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (user.isAdmin)
                          Chip(
                            label: Text(user.isSuperAdmin ? 'مشرف عام' : 'مشرف', style: const TextStyle(fontSize: 11)),
                            backgroundColor: Colors.purple.shade50,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Menu items
          Card(
            child: Column(
              children: [
                _MenuItem(icon: Icons.account_balance_wallet, title: 'المحفظة', color: Colors.blue, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage()));
                }),
                const Divider(height: 1),
                _MenuItem(icon: Icons.subscriptions, title: 'اشتراكاتي', color: Colors.green, onTap: () {}),
                const Divider(height: 1),
                _MenuItem(icon: Icons.favorite_border, title: 'المفضلة', color: Colors.red, onTap: () {}),
                const Divider(height: 1),
                _MenuItem(icon: Icons.notifications_outlined, title: 'الإشعارات', color: Colors.orange, onTap: () {}),
                const Divider(height: 1),
                _MenuItem(icon: Icons.download_outlined, title: 'الدروس المحملة', color: Colors.teal, onTap: () {}),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Teacher section
          if (user.isTeacher)
            Card(
              child: Column(
                children: [
                  _MenuItem(icon: Icons.dashboard, title: 'لوحة الأستاذ', color: Colors.indigo, onTap: () {}),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.video_library, title: 'كورساتي', color: Colors.blue, onTap: () {}),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.monetization_on, title: 'الأرباح', color: Colors.green, onTap: () {}),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.people, title: 'طلابي', color: Colors.orange, onTap: () {}),
                ],
              ),
            ),

          // Admin section
          if (user.isAdmin)
            Card(
              child: Column(
                children: [
                  _MenuItem(icon: Icons.dashboard, title: 'لوحة الإدارة', color: Colors.purple, onTap: () {}),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.people, title: 'المستخدمين', color: Colors.teal, onTap: () {}),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.school, title: 'الأساتذة', color: Colors.indigo, onTap: () {}),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.monetization_on, title: 'العمولات', color: Colors.green, onTap: () {}),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.money_off, title: 'طلبات السحب', color: Colors.red, onTap: () {}),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.flag, title: 'البلاغات', color: Colors.purple, onTap: () {}),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Settings & Logout
          Card(
            child: Column(
              children: [
                _MenuItem(icon: Icons.settings, title: 'الإعدادات', color: Colors.grey, onTap: () {}),
                const Divider(height: 1),
                _MenuItem(icon: Icons.dark_mode, title: 'الوضع الليلي', color: Colors.black87, onTap: () {}),
                const Divider(height: 1),
                _MenuItem(icon: Icons.logout, title: 'تسجيل الخروج', color: Colors.red, onTap: () {
                  context.read<AuthBloc>().add(LogoutEvent());
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: const Icon(Icons.chevron_left, size: 20),
      onTap: onTap,
    );
  }
}
