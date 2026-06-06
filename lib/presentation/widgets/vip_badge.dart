import 'package:flutter/material.dart';

class VipBadge extends StatelessWidget {
  final double size;
  const VipBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.4, vertical: size * 0.1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFAB00), Color(0xFFFF6D00)],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        'VIP',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.65,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class VipLockIcon extends StatelessWidget {
  final double size;
  const VipLockIcon({super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.workspace_premium,
      color: const Color(0xFFFFAB00),
      size: size,
    );
  }
}
