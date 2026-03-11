import 'package:flutter/material.dart';
import 'package:tcgp_trading_app/auth/profile_service.dart';
import 'package:tcgp_trading_app/models/card.dart';
import 'package:tcgp_trading_app/models/home_mode.dart';
import 'package:tcgp_trading_app/utils/input_fields.dart';
import 'package:tcgp_trading_app/auth/auth_service.dart';
import 'package:tcgp_trading_app/services/card_service.dart';
import 'package:tcgp_trading_app/services/user_card_service.dart';
import 'package:tcgp_trading_app/widgets/home_screen/card_tile.dart';
import 'package:tcgp_trading_app/widgets/shared/app_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileSaved;
  const ProfileScreen({super.key, this.onProfileSaved});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _friendIdController = TextEditingController();
  final _profileService = ProfileService();
  final _userCardService = UserCardService();

  String? _usernameErrorMessage;
  String? _friendIdErrorMessage;
  String? _selectedIcon;
  bool _editing = false;
  bool _loading = true;
  bool _saving = false;

  // Snapshot values to restore on cancel
  String _savedUsername = '';
  String _savedFriendId = '';
  String? _savedIcon;

  late final TabController _tabController;
  List<PocketCard> _wishlistCards = [];
  List<PocketCard> _listingCards = [];
  bool _loadingCards = false;

  static const _profileIcons = [
    'pikachu.png',
    'eevee.png',
    'charizard.png',
    'blastoise.png',
    'venusaur.png',
    'mewtwo.png',
    'mew.png',
    'snorlax.png',
    'slowpoke.png',
    'meowth.png',
    'gardevoir.png',
    'electrode.png',
    'piplup.png',
    'turtwig.png',
    'chimchar.png',
    'erika.png',
    'giovanni.png',
    'blue.png',
    'pokeball.png',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _usernameController.addListener(_onFieldChanged);
    _friendIdController.addListener(_onFieldChanged);
    _loadProfile();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getProfile();
      if (profile != null && mounted) {
        if (_usernameController.text.isEmpty) {
          _usernameController.text = profile['player_name'] ?? '';
        }
        if (_friendIdController.text.isEmpty) {
          _friendIdController.text = profile['friend_id']?.toString() ?? '';
        }
        _selectedIcon = profile['icon'] as String?;
      } else if (mounted) {
        _editing = true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load profile')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!_editing) _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _loadingCards = true);
    await _userCardService.loadMyCards();
    final allCards = await CardService().getAllCards();
    final wishlistIds = _userCardService.wishlistCardIds;
    final ownedIds = _userCardService.ownedCardIds;
    if (!mounted) return;
    setState(() {
      _wishlistCards =
          allCards.where((c) => wishlistIds.contains(c.id)).toList();
      _listingCards = allCards.where((c) => ownedIds.contains(c.id)).toList();
      _loadingCards = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _friendIdController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    final username = _usernameController.text.trim();
    final friendId = _friendIdController.text.trim();

    String? usernameErr;
    String? friendIdErr;

    if (username.isEmpty) {
      usernameErr = "Player Name cannot be empty.";
    } else if (username.length < 2) {
      usernameErr = "Min 2 characters.";
    } else if (username.length > 14) {
      usernameErr = "Max 14 characters.";
    }

    if (friendId.isEmpty) {
      friendIdErr = "Friend ID cannot be empty.";
    } else if (friendId.length != 12) {
      friendIdErr = "Friend ID must be 12 digits.";
    }

    setState(() {
      _usernameErrorMessage = usernameErr;
      _friendIdErrorMessage = friendIdErr;
    });

    return usernameErr == null && friendIdErr == null;
  }

  Future<void> _saveProfile() async {
    if (!_validateInputs()) return;
    setState(() => _saving = true);
    try {
      await _profileService.saveProfile(
        playerName: _usernameController.text.trim(),
        friendId: _friendIdController.text.trim(),
        icon: _selectedIcon,
      );
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
        _loadCards();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _enterEditMode() {
    setState(() {
      _savedUsername = _usernameController.text;
      _savedFriendId = _friendIdController.text;
      _savedIcon = _selectedIcon;
      _editing = true;
    });
  }

  Future<void> _signOut() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Sign out',
      content: const Text('Are you sure you want to sign out?'),
      primaryText: 'Sign out',
      onPrimaryPressed: () => true,
    );
    if (confirmed != true) return;
    try {
      await UserCardService().clearCache();
      await ProfileService().clearProfileCache();
      await AuthService().signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sign out')),
        );
      }
    }
  }

  void _cancelEdit() {
    setState(() {
      _usernameController.text = _savedUsername;
      _friendIdController.text = _savedFriendId;
      _selectedIcon = _savedIcon;
      _usernameErrorMessage = null;
      _friendIdErrorMessage = null;
      _editing = false;
    });
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF141418),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Select Icon',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                      ),
                      itemCount: _profileIcons.length,
                      itemBuilder: (context, index) {
                        final icon = _profileIcons[index];
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedIcon = icon);
                            Navigator.pop(context);
                          },
                          child: CircleAvatar(
                            radius: 36,
                            backgroundImage: AssetImage('images/profile/$icon'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formValid = _usernameErrorMessage == null &&
        _friendIdErrorMessage == null &&
        _usernameController.text.trim().length >= 2 &&
        _usernameController.text.trim().length <= 14 &&
        _friendIdController.text.trim().length == 12;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profile'),
        actions: [
          if (!_loading && !_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _enterEditMode,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _editing
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildEditMode(formValid),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildProfileHeader(),
                        ),
                        const SizedBox(height: 16),
                        _buildCardTabs(),
                      ],
                    ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: const Color(0xFF2A2A2E),
          backgroundImage: _selectedIcon != null
              ? AssetImage('images/profile/$_selectedIcon')
              : null,
          child: _selectedIcon == null
              ? Text(
                  _usernameController.text.trim().isNotEmpty
                      ? _usernameController.text.trim()[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 40, color: Colors.white70),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          _usernameController.text,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '${_friendIdController.text.substring(0, 4)}-${_friendIdController.text.substring(4, 8)}-${_friendIdController.text.substring(8, 12)}',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildCardTabs() {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: TabBar(
              controller: _tabController,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Color(0xFF02F8AE), width: 2),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerHeight: 0,
              labelColor: const Color(0xFF02F8AE),
              unselectedLabelColor: Colors.white60,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: [
                Tab(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.favorite_border, size: 16),
                      SizedBox(width: 6),
                      Text('Wishlist'),
                    ],
                  ),
                ),
                Tab(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check_circle_outline, size: 16),
                      SizedBox(width: 6),
                      Text('Listings'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingCards
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCardGrid(_wishlistCards, 'wishlist'),
                      _buildCardGrid(_listingCards, 'listings'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGrid(List<PocketCard> cards, String type) {
    if (cards.isEmpty) {
      return Center(
        child: Text(
          type == 'wishlist' ? 'No wishlisted cards' : 'No listed cards',
          style: const TextStyle(color: Colors.white38),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth ~/ 180).clamp(3, 4);
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.7,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => CardTile(
              card: cards[index],
              mode: HomeMode.browse,
              isPendingWishlist: false,
              isPendingOwned: false,
              pendingLanguages: const {},
              heroTag: 'profile-card-hero-${cards[index].id}',
              onWishlistToggle: (_) {},
              onOwnedToggle: (_) {},
              onLanguagesChanged: (_, __) {},
            ),
        );
      },
    );
  }

  Widget _buildEditMode(bool formValid) {
    return Column(
      children: [
        GestureDetector(
          onTap: _showIconPicker,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFF2A2A2E),
                backgroundImage: _selectedIcon != null
                    ? AssetImage('images/profile/$_selectedIcon')
                    : null,
                child: _selectedIcon == null
                    ? Text(
                        _usernameController.text.trim().isNotEmpty
                            ? _usernameController.text.trim()[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 40, color: Colors.white70),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A2A2E),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.edit, size: 20, color: Colors.white70),
                ),
              ),
              if (_selectedIcon != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIcon = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2A2A2E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 20, color: Colors.white70),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PlayerNameField(
          controller: _usernameController,
          errorText: _usernameErrorMessage,
        ),
        const SizedBox(height: 20),
        FriendIdField(
          controller: _friendIdController,
          errorText: _friendIdErrorMessage,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _cancelEdit,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saving ? null : (formValid ? _saveProfile : null),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
