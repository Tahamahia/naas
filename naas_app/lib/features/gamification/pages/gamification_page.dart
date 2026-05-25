import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class GamificationPage extends StatefulWidget {
  const GamificationPage({super.key});

  @override
  State<GamificationPage> createState() => _GamificationPageState();
}

class _GamificationPageState extends State<GamificationPage> with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;
  List<dynamic> _badges = [];
  List<dynamic> _myBadges = [];
  final List<dynamic> _leaderboard = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final badgesRes = await _api.get('/gamification/badges');
      final myBadgesRes = await _api.get('/gamification/my-badges');
      final leaderboardRes = await _api.get('/gamification/leaderboard');
      if (mounted) {
        setState(() {
          if (badgesRes.data['success'] == true) _badges = badgesRes.data['data'] as List;
          if (myBadgesRes.data['success'] == true) _myBadges = myBadgesRes.data['data'] as List;
          if (leaderboardRes.data['success'] == true) {
            _leaderboard.clear();
            _leaderboard.addAll(leaderboardRes.data['data'] as List);
          }
          _loading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإنجازات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'شاراتي'), Tab(text: 'كل الشارات'), Tab(text: 'المتصدرون'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabController, children: [
              _myBadgesList(),
              _allBadgesList(),
              _leaderboardList(),
            ]),
    );
  }

  Widget _myBadgesList() {
    if (_myBadges.isEmpty) return Center(child: Text('لم تحصل على شارات بعد', style: TextStyle(color: Colors.grey.shade500)));
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: _myBadges.length,
      itemBuilder: (_, i) {
        final b = _myBadges[i];
        return Card(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: AppTheme.goldColor, size: 36),
              const SizedBox(height: 4),
              Text(b['name'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              Text('${b['points']} نقطة', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
        );
      },
    );
  }

  Widget _allBadgesList() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: _badges.length,
      itemBuilder: (_, i) {
        final b = _badges[i];
        final has = _myBadges.any((m) => m['id'] == b['id']);
        return Card(
          color: has ? null : Colors.grey.shade100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(has ? Icons.emoji_events : Icons.lock_outline, color: has ? AppTheme.goldColor : Colors.grey, size: 36),
              const SizedBox(height: 4),
              Text(b['name'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: has ? null : Colors.grey), textAlign: TextAlign.center),
              if (!has) Text('${b['points']} نقطة', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        );
      },
    );
  }

  Widget _leaderboardList() {
    return _leaderboard.isEmpty
        ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(Icons.leaderboard, size: 60, color: Colors.grey.shade300), const SizedBox(height: 16), Text('لا توجد بيانات بعد', style: TextStyle(color: Colors.grey.shade500))],
          ))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _leaderboard.length,
            itemBuilder: (_, i) {
              final u = _leaderboard[i];
              return ListTile(
                leading: CircleAvatar(child: Text('${u['rank']}')),
                title: Text(u['full_name'] ?? ''),
                trailing: Text('${u['points'] ?? 0} نقطة', style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          );
  }
}
