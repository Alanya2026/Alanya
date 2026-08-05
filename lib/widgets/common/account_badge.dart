import 'package:flutter/material.dart';

/// Badge dérivé de `account_type` + `verification_status` — jamais stocké côté client.
enum AccountBadge {
  none,
  panierDeclare,
  panierVerifie,
  officiel,
}

const Color kOfficialSealGold = Color(0xFFC9A227);

AccountBadge resolveAccountBadge(int accountType, int verificationStatus) {
  if (accountType == 2) return AccountBadge.officiel;
  if (accountType == 1) {
    return verificationStatus == 2
        ? AccountBadge.panierVerifie
        : AccountBadge.panierDeclare;
  }
  return AccountBadge.none;
}

class AccountBadgeIcon extends StatelessWidget {
  const AccountBadgeIcon({
    super.key,
    required this.accountType,
    required this.verificationStatus,
    this.size = 14,
  });

  final int accountType;
  final int verificationStatus;
  final double size;

  @override
  Widget build(BuildContext context) {
    final badge = resolveAccountBadge(accountType, verificationStatus);
    if (badge == AccountBadge.none) return const SizedBox.shrink();
    if (badge == AccountBadge.officiel) {
      return Icon(Icons.verified, size: size, color: kOfficialSealGold);
    }
    if (badge == AccountBadge.panierVerifie) {
      return Icon(Icons.shopping_bag, size: size, color: Colors.green.shade700);
    }
    return Icon(Icons.shopping_bag_outlined, size: size, color: Colors.blueGrey);
  }
}

/// Nom de contact + icône de badge inline (liste conversations, détail contact…).
class AccountBadgeLabel extends StatelessWidget {
  const AccountBadgeLabel({
    super.key,
    required this.name,
    required this.accountType,
    required this.verificationStatus,
    this.style,
    this.maxLines = 1,
  });

  final String name;
  final int accountType;
  final int verificationStatus;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final badge = resolveAccountBadge(accountType, verificationStatus);
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            style: style,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (badge != AccountBadge.none) ...[
          const SizedBox(width: 4),
          AccountBadgeIcon(
            accountType: accountType,
            verificationStatus: verificationStatus,
            size: (style?.fontSize ?? 14) + 2,
          ),
        ],
      ],
    );
  }
}
