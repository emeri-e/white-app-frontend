import 'package:flutter/material.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/rewards/services/rewards_service.dart';

class BadgeShopScreen extends StatefulWidget {
  static const String id = 'badge_shop_screen';

  const BadgeShopScreen({super.key});

  @override
  State<BadgeShopScreen> createState() => _BadgeShopScreenState();
}

class _BadgeShopScreenState extends State<BadgeShopScreen> {
  late Future<List<dynamic>> _badgesFuture;
  Map<String, dynamic>? _wallet;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _badgesFuture = RewardsService.getBadges();
      _loadWallet();
    });
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await RewardsService.getWallet();
      setState(() {
        _wallet = wallet;
      });
    } catch (e) {
      debugPrint('Error loading wallet: $e');
    }
  }

  Future<void> _purchaseBadge(int badgeId, int cost) async {
    try {
      await RewardsService.purchaseBadge(badgeId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Badge purchased successfully!')),
      );
      _loadData(); // Refresh data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Badge Shop'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_wallet != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_wallet!['gold']}',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: SafeArea(
          child: FutureBuilder<List<dynamic>>(
            future: _badgesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.white)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No badges available.', style: TextStyle(color: Colors.white)));
              }

              final badges = snapshot.data!;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: badges.length,
                itemBuilder: (context, index) {
                  final badge = badges[index];
                  final levels = badge['levels'] as List<dynamic>;
                  final firstLevel = levels.isNotEmpty ? levels[0] : null;
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield, size: 64, color: Colors.white70), // Placeholder icon
                        const SizedBox(height: 12),
                        Text(
                          badge['title'],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge['description'],
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        if (firstLevel != null)
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: ElevatedButton(
                              onPressed: () => _purchaseBadge(badge['id'], firstLevel['cost_gold']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text('${firstLevel['cost_gold']} Gold'),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
