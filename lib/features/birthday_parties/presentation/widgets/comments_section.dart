import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_party.dart';

/// "Izohlar": the party's notes (oldest first) and an input that adds one.
/// [onAdd] resolves true when the comment was saved (the input then clears).
class CommentsSection extends StatefulWidget {
  const CommentsSection({
    super.key,
    required this.comments,
    required this.onAdd,
    this.enabled = true,
  });

  final List<BirthdayPartyComment> comments;
  final Future<bool> Function(String text) onAdd;
  final bool enabled;

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || !widget.enabled) return;
    setState(() => _sending = true);
    final saved = await widget.onAdd(text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (saved) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final df = DateFormat('dd.MM HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.bdComments.toUpperCase(), style: p.kicker),
        const SizedBox(height: 8),
        if (widget.comments.isEmpty)
          Text(l10n.bdNoComments, style: p.bodyMuted)
        else
          for (final c in widget.comments)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.text, style: p.body),
                    const SizedBox(height: 2),
                    Text(
                      '${c.author} · ${df.format(c.createdAt.toLocal())}',
                      style: p.bodyMuted.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('bd-comment-field'),
                controller: _controller,
                enabled: widget.enabled,
                maxLength: 500,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                decoration: InputDecoration(
                  hintText: l10n.bdCommentHint,
                  isDense: true,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const ValueKey('bd-comment-send'),
              onPressed: widget.enabled && !_sending ? _send : null,
              icon: const Icon(Icons.send, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}
