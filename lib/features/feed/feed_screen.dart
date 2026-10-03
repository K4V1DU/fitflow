import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../entities/post.dart';
import '../../services/feed_repository.dart';
import '../../widgets/common.dart';

/// Social feed: everyone's posts, newest first. Users can post text with an
/// optional photo, like posts and delete their own.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.uid, required this.authorName});

  final String uid;
  final String authorName;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _repo = FeedRepository();
  late final Stream<List<Post>> _posts = _repo.watchPosts();

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _compose() async {
    final posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ComposeSheet(
        repo: _repo,
        uid: widget.uid,
        authorName: widget.authorName,
      ),
    );
    if (posted == true) _toast('Posted!');
  }

  void _like(Post p) {
    _repo
        .toggleLike(p.id, widget.uid, like: !p.isLikedBy(widget.uid))
        .catchError((Object e) {
          debugPrint('Like failed: $e');
          _toast('Could not update like');
        });
  }

  Future<void> _delete(Post p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kPink),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deletePost(p);
    } catch (e) {
      debugPrint('Delete failed: $e');
      _toast('Could not delete the post');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: StreamBuilder<List<Post>>(
        stream: _posts,
        builder: (context, snap) {
          final posts = snap.data ?? const <Post>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                'Feed',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'See what the community is up to',
                style: textTheme.bodyMedium?.copyWith(
                  color: textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),
              _ComposerCard(name: widget.authorName, onTap: _compose),
              const SizedBox(height: 16),
              if (snap.hasError)
                Surface(
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 32),
                      const SizedBox(height: 8),
                      const Text('Could not load the feed'),
                      const SizedBox(height: 6),
                      SelectableText(
                        '${snap.error}',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              else if (!snap.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (posts.isEmpty)
                Surface(
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: kBrand.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.dynamic_feed_rounded,
                          color: kBrand,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No posts yet',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Be the first to share a workout, a meal or progress.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              else
                for (final p in posts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _PostCard(
                      post: p,
                      isMine: p.uid == widget.uid,
                      liked: p.isLikedBy(widget.uid),
                      onLike: () => _like(p),
                      onDelete: () => _delete(p),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── Composer card ─────────────────────────

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Surface(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Avatar(name),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: onSurface.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  'Share your progress...',
                  style: TextStyle(color: onSurface.withOpacity(0.55)),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add photo',
            onPressed: onTap,
            icon: const Icon(Icons.photo_library_rounded, color: kAccent),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Post card ─────────────────────────

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isMine,
    required this.liked,
    required this.onLike,
    required this.onDelete,
  });

  final Post post;
  final bool isMine;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final url = post.imageUrl;

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(post.authorName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(timeAgo(post.createdAt), style: textTheme.bodySmall),
                  ],
                ),
              ),
              if (isMine)
                PopupMenuButton<String>(
                  tooltip: 'Post options',
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18),
                          SizedBox(width: 10),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (post.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(post.text, style: textTheme.bodyMedium?.copyWith(height: 1.4)),
          ],
          if (url != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: Image.network(
                  url,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 120,
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onLike,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: liked ? kPink : Colors.grey,
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${post.likeCount}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Compose sheet ─────────────────────────

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({
    required this.repo,
    required this.uid,
    required this.authorName,
  });

  final FeedRepository repo;
  final String uid;
  final String authorName;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _text = TextEditingController();
  Uint8List? _image;
  bool _posting = false;
  String? _error;

  bool get _canPost =>
      !_posting && (_text.text.trim().isNotEmpty || _image != null);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1440,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _image = bytes;
        _error = null;
      });
    } catch (e) {
      debugPrint('Pick failed: $e');
      if (mounted) setState(() => _error = 'Could not open your photos');
    }
  }

  Future<void> _submit() async {
    if (!_canPost) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await widget.repo
          .createPost(
            uid: widget.uid,
            authorName: widget.authorName,
            text: _text.text.trim(),
            imageBytes: _image,
          )
          .timeout(const Duration(seconds: 45));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Post failed: $e');
      if (!mounted) return;
      setState(() {
        _posting = false;
        _error = 'Could not post: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(widget.authorName),
                const SizedBox(width: 12),
                Text(
                  widget.authorName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              enabled: !_posting,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Share your workout, a meal or your progress...',
                border: InputBorder.none,
              ),
            ),
            if (_image != null) ...[
              const SizedBox(height: 8),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: Image.memory(
                        _image!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        color: Colors.white,
                        onPressed: _posting
                            ? null
                            : () => setState(() => _image = null),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: kPink),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _posting ? null : _pick,
                  icon: const Icon(Icons.photo_library_rounded, size: 20),
                  label: Text(_image == null ? 'Photo' : 'Change photo'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _canPost ? _submit : null,
                  style: FilledButton.styleFrom(backgroundColor: kBrand),
                  icon: _posting
                      ? const Spinner(color: Colors.black)
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_posting ? 'Posting...' : 'Post'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
