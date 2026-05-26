import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/wallet/pages/wallet_page.dart';
import '../../../features/teacher/pages/teacher_settings_page.dart';
import '../../../features/teacher_dashboard/pages/teacher_dashboard.dart';
import '../../../features/teacher/pages/teacher_application_page.dart';
import '../../../features/admin/pages/admin_dashboard.dart';
import '../../../features/admin/pages/admin_users_page.dart';
import '../../../features/admin/pages/admin_withdrawals_page.dart';
import '../../../features/admin/pages/admin_teachers_page.dart';
import '../../../features/admin/pages/admin_reports_page.dart';
import '../../../features/admin/pages/admin_categories_page.dart';
import '../../../features/admin/pages/admin_courses_page.dart';
import '../../../features/settings/pages/settings_page.dart';
import '../../../features/subscriptions/pages/subscriptions_page.dart';
import '../../../features/notifications/pages/notifications_page.dart';
import '../../../core/utils/ui_helpers.dart';

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
          // Profile header (Modern)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                    child: user.avatarUrl == null ? Text(user.fullName[0], style: const TextStyle(fontSize: 28, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)) : null,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(user.email, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (user.role == 'teacher')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                              child: const Text('أستاذ', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          if (user.isAdmin)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                              child: Text(user.isSuperAdmin ? 'مشرف عام' : 'مشرف', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
                _MenuItem(icon: Icons.subscriptions, title: 'اشتراكاتي', color: Colors.green, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsPage()));
                }),
                const Divider(height: 1),
                _MenuItem(icon: Icons.favorite_border, title: 'المفضلة', color: Colors.red, onTap: () => showComingSoon(context)),
                const Divider(height: 1),
                _MenuItem(icon: Icons.notifications_outlined, title: 'الإشعارات', color: Colors.orange, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
                }),
                const Divider(height: 1),
                _MenuItem(icon: Icons.download_outlined, title: 'الدروس المحملة', color: Colors.teal, onTap: () => showComingSoon(context)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Teacher section
          if (user.isTeacher)
            Card(
              child: Column(
                children: [
                  _MenuItem(icon: Icons.dashboard, title: 'لوحة الأستاذ', color: Colors.indigo, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherDashboard()));
                  }),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.video_library, title: 'كورساتي', color: Colors.blue, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherDashboard()));
                  }),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.settings, title: 'إعدادات الأستاذ والسحب', color: Colors.orange, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherSettingsPage()));
                  }),
                ],
              ),
            ),

          // Admin section
          if (user.isAdmin)
            Card(
              child: Column(
                children: [
                  _MenuItem(icon: Icons.dashboard, title: 'لوحة الإدارة', color: Colors.purple, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
                  }),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.people, title: 'المستخدمين', color: Colors.teal, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersPage()));
                  }),
                  const Divider(height: 1),
                  // TODO: إضافة صفحة مخصصة للأساتذة
                  _MenuItem(icon: Icons.school, title: 'الأساتذة', color: Colors.indigo, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTeachersPage()));
                  }),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.category, title: 'الأقسام', color: Colors.blue, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCategoriesPage()));
                  }),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.video_library, title: 'الكورسات', color: Colors.green, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCoursesPage()));
                  }),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.money_off, title: 'طلبات السحب', color: Colors.red, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminWithdrawalsPage()));
                  }),
                  const Divider(height: 1),
                  _MenuItem(icon: Icons.flag, title: 'البلاغات', color: Colors.purple, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReportsPage()));
                  }),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Student section - Apply as teacher
          if (user.role == 'student')
            Card(
              child: Column(
                children: [
                  _MenuItem(icon: Icons.school, title: 'التقديم كأستاذ', color: Colors.indigo, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherApplicationPage()));
                  }),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Settings & Logout
          Card(
            child: Column(
              children: [
                _MenuItem(icon: Icons.settings, title: 'الإعدادات', color: Colors.grey, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                }),
                const Divider(height: 1),
                _MenuItem(icon: Icons.dark_mode, title: 'الوضع الليلي', color: Colors.black87, onTap: () => showComingSoon(context)),
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
