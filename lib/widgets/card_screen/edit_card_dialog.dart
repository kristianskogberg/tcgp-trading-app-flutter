import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tcgp_trading_app/collection/collection.dart';
import 'package:tcgp_trading_app/collection/collection_draft.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/home_mode.dart';
import 'package:tcgp_trading_app/screens/trade_condition_picker_screen.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';
import 'package:tcgp_trading_app/widgets/shared/card_tile.dart';

/// Edits one card through a [CollectionDraft] and saves its changes with
/// [save], normally `CollectionStore.commit`. A failed save keeps the dialog
/// open with the user's choices and shows one error.
class EditCardDialog extends StatefulWidget {
  final PocketCard card;
  final CollectionDraft draft;
  final CollectionItemKind kind;
  final bool isEditing;
  final String? warningText;
  final Future<void> Function(Map<String, CardState> changes) save;

  const EditCardDialog({
    super.key,
    required this.card,
    required this.draft,
    required this.kind,
    required this.isEditing,
    required this.save,
    this.warningText,
  });

  @override
  State<EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<EditCardDialog> {
  late CollectionDraft _draft;
  bool _saving = false;
  String? _error;

  String get _cardId => widget.card.id;

  CardState get _state => _draft.stateOf(_cardId);

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
  }

  String get _title {
    if (widget.kind == CollectionItemKind.wishlist) {
      return widget.isEditing ? 'Edit Wishlist' : 'Add to Wishlist';
    }
    return widget.isEditing ? 'Edit Listing' : 'Create a Listing';
  }

  /// The languages shown on the card. A card that is turned off shows the
  /// default it would get when turned back on as a new entry.
  Set<String> get _languages => switch (_state) {
        Wishlisted(:final languages) => languages,
        Listed(:final language) => {language},
        NotInCollection() => widget.kind == CollectionItemKind.wishlist
            ? {anyLanguage}
            : {_draft.preferredLanguage},
      };

  List<TradeCondition> get _tradeConditions => switch (_state) {
        Listed(:final tradeConditions) => tradeConditions,
        _ => const [],
      };

  void _update(CollectionDraft Function(CollectionDraft) intent) {
    if (_saving) return;
    setState(() {
      _draft = intent(_draft);
      _error = null;
    });
  }

  Future<void> _openConditionsPicker() async {
    if (_saving) return;
    final result = await Navigator.push<List<TradeCondition>>(
      context,
      MaterialPageRoute(
        builder: (_) => TradeConditionPickerScreen(
          listedCard: widget.card,
          initialConditions: _tradeConditions,
        ),
      ),
    );
    if (result == null || !mounted) return;
    _update((d) => d.setTradeConditions(_cardId, result));
  }

  Future<void> _save() async {
    if (!_draft.hasChanges) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(_draft.changes);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Failed to save collection changes: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            "Couldn't save your changes. Check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return PopScope(
      canPop: !_saving,
      child: AppDialog<void>(
        centerContent: true,
        title: _title,
        primaryLoading: _saving,
        onPrimaryTap: _save,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              height: 200,
              child: CardTile(
                card: widget.card,
                mode: HomeMode.edit,
                isPendingWishlist: state is Wishlisted,
                isPendingListing: state is Listed,
                pendingLanguages: _languages,
                tradeConditionCount: _tradeConditions.length,
                onConditionsPressed: _openConditionsPicker,
                onWishlistToggle: widget.kind == CollectionItemKind.wishlist
                    ? (_) => _update((d) => d.toggleWishlist(_cardId))
                    : null,
                onListingToggle: widget.kind == CollectionItemKind.listing
                    ? (_) => _update((d) => d.toggleListing(_cardId))
                    : null,
                onLanguagesChanged: (_, langs) =>
                    _update((d) => d.setLanguages(_cardId, langs)),
              ),
            ),
            if (widget.warningText != null)
              _DialogNotice(
                icon: PhosphorIcons.warning(),
                color: Colors.amber,
                text: widget.warningText!,
              ),
            if (_error != null)
              _DialogNotice(
                icon: PhosphorIcons.warningCircle(),
                color: Colors.redAccent,
                text: _error!,
              ),
          ],
        ),
      ),
    );
  }
}

class _DialogNotice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _DialogNotice({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          PhosphorIcon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
