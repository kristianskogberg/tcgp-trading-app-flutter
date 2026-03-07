import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FriendIdChip extends StatelessWidget {
  final String friendId;
  const FriendIdChip({super.key, required this.friendId});

  static String _formatFriendId(String id) {
    final digits = id.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write('-');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (friendId.isEmpty) return;
        await Clipboard.setData(ClipboardData(text: friendId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Friend ID copied ($friendId)')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatFriendId(friendId),
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy, size: 16, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
