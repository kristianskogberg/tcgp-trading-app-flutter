import 'package:flutter/material.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController textController;
  final bool enabled;
  final bool hasFriendId;
  final VoidCallback onSend;
  final VoidCallback onSendFriendId;
  final VoidCallback onShowQuickMessages;

  const ChatInputBar({
    super.key,
    required this.textController,
    required this.enabled,
    required this.hasFriendId,
    required this.onSend,
    required this.onSendFriendId,
    required this.onShowQuickMessages,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        color: const Color(0xFF1E1E24),
        child: Row(
          children: [
            PopupMenuButton<String>(
              icon: Icon(
                Icons.add_circle_rounded,
                color: enabled
                    ? const Color(0xFF02F8AE)
                    : Colors.white24,
              ),
              enabled: enabled,
              color: const Color(0xFF242429),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              position: PopupMenuPosition.over,
              onSelected: (value) {
                if (value == 'friend_id') onSendFriendId();
                if (value == 'quick_message') onShowQuickMessages();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  height: 44,
                  value: 'friend_id',
                  enabled: hasFriendId,
                  child: const Row(
                    children: [
                      Icon(Icons.person_add_outlined,
                          size: 20, color: Colors.white70),
                      SizedBox(width: 12),
                      Text('Send my Friend ID',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  height: 44,
                  value: 'quick_message',
                  child: Row(
                    children: [
                      Icon(Icons.message_outlined,
                          size: 20, color: Colors.white70),
                      SizedBox(width: 12),
                      Text('Send a Quick Message',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: TextField(
                controller: textController,
                enabled: enabled,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                maxLength: 100,
                maxLines: 4,
                minLines: 1,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        required maxLength}) =>
                    null,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(
                      color: Colors.white24, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFF2A2A30),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: enabled ? onSend : null,
              icon: Icon(
                Icons.send_rounded,
                color: enabled
                    ? const Color(0xFF02F8AE)
                    : Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
