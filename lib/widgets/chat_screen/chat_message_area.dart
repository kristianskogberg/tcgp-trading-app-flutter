import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/message.dart';

class ChatMessageArea extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<Message> messages;
  final bool hasMore;
  final ScrollController scrollController;
  final Widget Function(Message message) messageBubbleBuilder;
  final VoidCallback onLoadMore;

  const ChatMessageArea({
    super.key,
    required this.loading,
    this.error,
    required this.messages,
    required this.hasMore,
    required this.scrollController,
    required this.messageBubbleBuilder,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(error!,
                style: const TextStyle(fontSize: 14, color: Colors.white38)),
          ],
        ),
      );
    }

    if (messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              'Send a message to start the conversation',
              style: TextStyle(fontSize: 14, color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          onLoadMore();
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )),
          );
        }
        return messageBubbleBuilder(messages[index]);
      },
    );
  }
}
