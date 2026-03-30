import 'package:flutter/material.dart';

void showBadgeEarnedDialog(BuildContext context, List<dynamic> newBadges) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.celebration, color: Colors.amber, size: 32),
          SizedBox(width: 8),
          Text('New Badge Unlocked!'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: newBadges.map((badgeData) {
            final badge = badgeData['badge'];
            final level = badgeData['current_level'];
            return ListTile(
              leading: const Icon(Icons.shield, color: Colors.amber, size: 40),
              title: Text(badge['title']),
              subtitle: Text('Level ${level['level_number']} - ${badge['description']}'),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Awesome!'),
        ),
      ],
    ),
  );
}
