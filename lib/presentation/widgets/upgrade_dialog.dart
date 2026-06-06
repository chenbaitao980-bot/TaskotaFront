import 'package:flutter/material.dart';
import '../pages/profile/vip_page.dart';

class UpgradeDialog {
  static void show(BuildContext context, {required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFFFAB00), size: 28),
            SizedBox(width: 8),
            Text('升级VIP'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VipPage()),
              );
            },
            child: const Text('去开通'),
          ),
        ],
      ),
    );
  }
}
