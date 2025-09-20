import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;

class AlertBadge extends StatelessWidget {
  final int count;
  final Widget child;
  final Color? badgeColor;
  final Color? textColor;

  const AlertBadge({
    super.key,
    required this.count,
    required this.child,
    this.badgeColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return child;
    }

    return badges.Badge(
      badgeContent: Text(
        count > 99 ? '99+' : count.toString(),
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      badgeStyle: badges.BadgeStyle(
        badgeColor: badgeColor ?? Colors.red,
        padding: const EdgeInsets.all(5),
        borderRadius: BorderRadius.circular(10),
      ),
      position: badges.BadgePosition.topEnd(top: -8, end: -8),
      child: child,
    );
  }
}
