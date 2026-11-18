import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../data/models/live.dart';
import '../data/models/phone.dart';
import '../data/api_service.dart';
import '../hooks/cart.dart';
import '../hooks/language.dart';
import '../hooks/live.dart';
import '../theme/app_theme.dart';
import '../components/common.dart';
import '../components/effects.dart';
import '../components/motion.dart';
import '../components/ux.dart';
import 'cart_screen.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';

// Live shopping: the seller's YouTube Live stream on top, the comments viewers
// type running underneath (new ones arrive every few seconds), the phones the
// seller pinned in a strip at the bottom, and "Buy now" in a sheet that opens
// over the stream, so nobody has to leave the live to buy.
class LiveShoppingScreen extends StatefulWidget {
  final LiveSession session;

  const LiveShoppingScreen({super.key, required this.session});

  // The video. Tests swap it for a plain box (there is no browser in a test).
  static Widget Function(String youtubeId) playerBuilder = (id) =>
      _YoutubeLive(videoId: id);

  @override
  State<LiveShoppingScreen> createState() => _LiveShoppingScreenState();
}

class _LiveShoppingScreenState extends State<LiveShoppingScreen> {
  late LiveSession _session = widget.session;
  final List<LiveComment> _comments = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _commentsTimer, _sessionTimer;
  bool _sending = false;

  int get _lastId => _comments.isEmpty ? 0 : _comments.last.id;

  @override
  void initState() {
    super.initState();
    _loadComments();
    // New comments every 3 seconds; whether the live is still on every 20
    _commentsTimer = Live.poll(
      () => context,
      _loadComments,
      every: const Duration(seconds: 3),
    );
    _sessionTimer = Live.poll(() => context, _reloadSession);
  }

  @override
  void dispose() {
    _commentsTimer?.cancel();
    _sessionTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final fresh = await ApiService.fetchLiveComments(after: _lastId);
      if (!mounted || fresh.isEmpty) return;
      setState(() => _comments.addAll(fresh));
      _toBottom();
    } catch (_) {
      // Offline for a moment: try again on the next tick
    }
  }

  Future<void> _reloadSession() async {
    try {
      final session = await ApiService.fetchLive();
      if (mounted) setState(() => _session = session);
    } catch (_) {}
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: Motion.medium,
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    if (!await requireLogin(
          context,
          reason: trf('សូម Login ដើម្បីសរសេរមតិ', 'Log in to join the chat'),
        ) ||
        !mounted) {
      return;
    }
    setState(() => _sending = true);
    try {
      final comment = await ApiService.postLiveComment(text);
      if (!mounted) return;
      _input.clear();
      Haptics.success();
      setState(() {
        if (comment.id > _lastId) _comments.add(comment);
      });
      _toBottom();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _buy(Phone phone) {
    Haptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickBuySheet(phone: phone),
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = _session.isLive && _session.youtubeId.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF050505), // a cinema: always dark
      body: SafeArea(
        child: Column(
          children: [
            _topBar(live),
            // The stream, 16:9, never more than 40% of the screen's height
            // (on a wide screen it would push the chat and phones off)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.4,
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: live
                    ? LiveShoppingScreen.playerBuilder(_session.youtubeId)
                    : const ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: Icon(
                            Icons.videocam_off_rounded,
                            color: Colors.white38,
                            size: 48,
                          ),
                        ),
                      ),
              ),
            ),
            Expanded(child: live ? _commentList() : _ended()),
            if (_session.products.isNotEmpty) _pinned(),
            if (live) _composer(),
          ],
        ),
      ),
    );
  }

  Widget _topBar(bool live) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            color: Colors.white,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          if (live) ...[
            const LiveDot(color: Color(0xFFFF453A), textColor: Colors.white),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              _session.title.isEmpty
                  ? trf('ទិញផ្ទាល់', 'Live shopping')
                  : _session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // The cart, with its count, without leaving the live
          ListenableBuilder(
            listenable: Cart.instance,
            builder: (context, _) => IconButton(
              tooltip: trf('កន្ត្រក', 'Cart'),
              color: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
              icon: Badge(
                isLabelVisible: Cart.instance.count > 0,
                label: BumpOnChange(
                  value: Cart.instance.count,
                  child: Text('${Cart.instance.count}'),
                ),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ended() {
    return StatusView(
      icon: Icons.live_tv_rounded,
      title: trf('ការផ្សាយផ្ទាល់បានបញ្ចប់', 'The live has ended'),
      message: trf(
        'អ្នកនៅតែអាចទិញទូរស័ព្ទខាងក្រោមបាន',
        'You can still buy the phones below',
      ),
    );
  }

  Widget _commentList() {
    if (_comments.isEmpty) {
      return Center(
        child: Text(
          trf(
            'សួរអ្វីក៏បាន អ្នកលក់កំពុងឆ្លើយ',
            'Ask anything, the seller is answering',
          ),
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    return ShaderMask(
      // Older comments fade out towards the top, like a live feed
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white],
        stops: [0, 0.25],
      ).createShader(r),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 8),
        itemCount: _comments.length,
        itemBuilder: (context, i) => Entrance(
          key: ValueKey(_comments[i].id),
          child: _CommentBubble(comment: _comments[i]),
        ),
      ),
    );
  }

  // The pinned phones, side by side, each with "Buy now"
  Widget _pinned() {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        itemCount: _session.products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final phone = _session.products[i];
          return PopIn(
            index: i,
            child: Container(
              width: 250,
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: const Color(0x1FFFFFFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: i == 0
                      ? AppColors
                            .accent // the one being shown right now
                      : const Color(0x24FFFFFF),
                  width: i == 0 ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: ColoredBox(
                      color: const Color(
                        0x14FFFFFF,
                      ), // pictures are see-through now
                      child: PhoneImage(url: phone.imageUrl, size: 60),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          phone.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          money(phone.price),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PressScale(
                    child: FilledButton(
                      onPressed: phone.stock > 0 ? () => _buy(phone) : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(
                        phone.stock > 0
                            ? trf('ទិញ', 'Buy now')
                            : trf('អស់', 'Sold out'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              maxLength: 300,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                hintText: trf('សរសេរមតិ...', 'Say something...'),
                hintStyle: const TextStyle(color: Colors.white38),
                fillColor: const Color(0x1FFFFFFF),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  borderSide: const BorderSide(color: Color(0x24FFFFFF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: trf('ផ្ញើ', 'Send'),
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(backgroundColor: AppColors.accent),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: DotsLoader(color: Colors.white, size: 5),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final LiveComment comment;

  const _CommentBubble({required this.comment});

  @override
  Widget build(BuildContext context) {
    final initial = comment.name.isEmpty
        ? '?'
        : comment.name.characters.first.toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.accent.withValues(alpha: 0.25),
            foregroundImage: comment.avatarUrl.isEmpty
                ? null
                : NetworkImage(comment.avatarUrl),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.name,
                    style: const TextStyle(
                      color: Color(0xFF8FB3FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.message,
                    style: const TextStyle(color: Colors.white, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// The YouTube stream, playing as soon as the page opens
class _YoutubeLive extends StatefulWidget {
  final String videoId;

  const _YoutubeLive({required this.videoId});

  @override
  State<_YoutubeLive> createState() => _YoutubeLiveState();
}

class _YoutubeLiveState extends State<_YoutubeLive> {
  late final _controller = YoutubePlayerController.fromVideoId(
    videoId: widget.videoId,
    autoPlay: true,
    params: const YoutubePlayerParams(
      showFullscreenButton: true,
      strictRelatedVideos: true,
      // Muted at first: browsers only autoplay muted video; one tap unmutes
      mute: true,
    ),
  );

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(controller: _controller, aspectRatio: 16 / 9);
  }
}

// "Buy now" over the stream: pick colour, size and how many, then add to the
// cart (and stay on the live) or go straight to checkout.
class QuickBuySheet extends StatefulWidget {
  final Phone phone;

  const QuickBuySheet({super.key, required this.phone});

  @override
  State<QuickBuySheet> createState() => _QuickBuySheetState();
}

class _QuickBuySheetState extends State<QuickBuySheet> {
  late String _color = widget.phone.colors.firstOrNull ?? '';
  late String _storage = widget.phone.storageOptions.firstOrNull?.storage ?? '';
  int _qty = 1;

  Phone get _phone => widget.phone;

  Future<bool> _addToCart() async {
    if (!await requireLogin(context) || !mounted) return false;
    final ok = Cart.instance.add(_phone, _qty, _color, _storage);
    ok ? Haptics.success() : Haptics.warning();
    if (!ok) showMessage(context, tr('ស្តុកមិនគ្រប់គ្រាន់'), error: true);
    return ok;
  }

  Widget _chips(List<String> options, String picked, ValueChanged<String> on) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(option),
              selected: option == picked,
              showCheckmark: false,
              selectedColor: AppColors.accent,
              labelStyle: TextStyle(
                color: option == picked ? Colors.white : AppColors.text,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                Haptics.tap();
                setState(() => on(option));
              },
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final price = _phone.priceFor(_storage);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.tileLow,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    child: PhoneImage(
                      key: ValueKey(_phone.imageFor(_color)),
                      url: _phone.imageFor(_color),
                      size: 76,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _phone.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      CountUpMoney(
                        price * _qty,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_phone.colors.length > 1) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                trf('ពណ៌', 'Colour'),
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.xs),
              _chips(_phone.colors, _color, (c) => _color = c),
            ],
            if (_phone.storageOptions.length > 1) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Storage', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: AppSpacing.xs),
              _chips(
                [for (final o in _phone.storageOptions) o.storage],
                _storage,
                (s) => _storage = s,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  trf('ចំនួន', 'Quantity'),
                  style: TextStyle(color: AppColors.muted),
                ),
                const Spacer(),
                IconButton.outlined(
                  tooltip: 'បន្ថយ',
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '$_qty',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'បន្ថែម',
                  onPressed: _qty < _phone.stock
                      ? () => setState(() => _qty++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (await _addToCart() && context.mounted) {
                        Navigator.pop(context);
                        showMessage(
                          context,
                          trf('បានបន្ថែមទៅ Cart', 'Added to cart'),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: Text(trf('ដាក់ Cart', 'Add to cart')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (await _addToCart() && context.mounted) {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CheckoutScreen(),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.bolt_rounded),
                    label: Text(trf('ទិញឥឡូវ', 'Buy now')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
