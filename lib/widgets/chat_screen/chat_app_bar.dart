import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/utils/activity_utils.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String displayName;
  final String? displayIcon;
  final DateTime? lastActiveAt;

  const ChatAppBar({
    super.key,
    required this.displayName,
    this.displayIcon,
    this.lastActiveAt,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          color: const Color(0xFF242429),
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          position: PopupMenuPosition.under,
          onSelected: (_) {},
          itemBuilder: (context) => [
            const PopupMenuItem(
              height: 44,
              value: 'view_profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 20, color: Colors.white70),
                  SizedBox(width: 12),
                  Text('View profile',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const PopupMenuItem(
              height: 44,
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block, size: 20, color: Colors.white70),
                  SizedBox(width: 12),
                  Text('Block user', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ],
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF2A2A30),
            backgroundImage: displayIcon != null
                ? AssetImage('images/profile/$displayIcon')
                : null,
            child: displayIcon == null
                ? Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : '?',
                    style:
                        const TextStyle(fontSize: 16, color: Colors.white70),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (lastActiveAt != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activityColor(lastActiveAt),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        activityLabel(lastActiveAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
