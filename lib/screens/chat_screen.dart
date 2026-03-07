import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/trade_match.dart';
import 'package:tcgp_trading_app/utils/activity_utils.dart';

class ChatScreen extends StatelessWidget {
  final PocketCard contextCard;
  final PocketCard matchCard;
  final TradeMatch tradeMatch;
  final bool isWantTab;

  const ChatScreen({
    super.key,
    required this.contextCard,
    required this.matchCard,
    required this.tradeMatch,
    required this.isWantTab,
  });

  @override
  Widget build(BuildContext context) {
    final offerCard = isWantTab ? matchCard : contextCard;
    final receiveCard = isWantTab ? contextCard : matchCard;

    return Scaffold(
      appBar: AppBar(
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
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                height: 44,
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined,
                        size: 20, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Text('Report user',
                        style: TextStyle(color: Colors.redAccent)),
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
              child: const Icon(Icons.person, size: 20, color: Colors.white54),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tradeMatch.playerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activityColor(tradeMatch.lastActiveAt),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        activityLabel(tradeMatch.lastActiveAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTradeHeader(offerCard, receiveCard),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 48, color: Colors.white24),
                  SizedBox(height: 12),
                  Text(
                    'Chat coming soon',
                    style: TextStyle(fontSize: 14, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF1E1E24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      enabled: false,
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
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: null,
                    icon: const Icon(Icons.send, color: Colors.white24),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeHeader(PocketCard offerCard, PocketCard receiveCard) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildCardColumn(offerCard)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.swap_horiz, size: 28, color: Color(0xFF02F8AE)),
          ),
          Expanded(child: _buildCardColumn(receiveCard)),
        ],
      ),
    );
  }

  Widget _buildCardColumn(PocketCard card) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: card.imageUrl,
            height: 100,
            fit: BoxFit.contain,
            placeholder: (context, url) => Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image, color: Colors.white24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          card.name,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
