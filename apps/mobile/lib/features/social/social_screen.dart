import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';
import 'social_models.dart';

/// Social hub for study groups and peer accountability.
class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  int _tabIndex = 0; // 0 = Groups, 1 = Friends

  final List<StudyGroup> _groups = <StudyGroup>[
    const StudyGroup(
      id: 'group-1',
      name: 'Combined Maths 2026',
      description: 'Daily revision and past paper discussion.',
      role: 'member',
    ),
    const StudyGroup(
      id: 'group-2',
      name: 'Physics Mechanics Study Circle',
      description: 'Structured evening problem solving.',
      role: 'member',
    ),
  ];

  final List<Friend> _friends = <Friend>[
    const Friend(id: 'friend-1', displayName: 'Kasun Perera', stream: 'mathematics'),
    const Friend(id: 'friend-2', displayName: 'Dilini Fernando', stream: 'science'),
  ];

  void _showJoinGroupDialog() {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.socialJoinGroup),
          content: AppTextField(
            controller: controller,
            label: '6-digit Invite Code', // l10n-ok
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final code = controller.text.trim();
                if (code.isNotEmpty) {
                  setState(() {
                    _groups.add(
                      StudyGroup(
                        id: 'group-${_groups.length + 1}',
                        name: 'Study Room $code',
                        description: 'Peer group joined via invite code.',
                      ),
                    );
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: Text(l10n.continueLabel),
            ),
          ],
        );
      },
    );
  }

  void _openChat(StudyGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _GroupChatScreen(group: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.socialTitle),
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showJoinGroupDialog,
              icon: const Icon(Icons.group_add_outlined),
              label: Text(l10n.socialJoinGroup),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: SegmentedButton<int>(
                segments: <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 0, label: Text(l10n.socialGroups)),
                  ButtonSegment<int>(value: 1, label: Text(l10n.socialFriends)),
                ],
                selected: <int>{_tabIndex},
                onSelectionChanged: (set) => setState(() => _tabIndex = set.first),
              ),
            ),
            Expanded(
              child: _tabIndex == 0
                  ? ListView.separated(
                      padding: const EdgeInsets.all(Spacing.md),
                      itemCount: _groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
                      itemBuilder: (context, index) {
                        final g = _groups[index];
                        return InkWell(
                          onTap: () => _openChat(g),
                          borderRadius: BorderRadius.circular(Radii.lg),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Expanded(child: Text(g.name, style: theme.textTheme.titleMedium)),
                                    Icon(Icons.chat_bubble_outline, size: Sizes.iconSm, color: colors.primary),
                                  ],
                                ),
                                if (g.description != null) ...<Widget>[
                                  const SizedBox(height: Spacing.xs),
                                  Text(
                                    g.description!,
                                    style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(Spacing.md),
                      itemCount: _friends.length,
                      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
                      itemBuilder: (context, index) {
                        final f = _friends[index];
                        return AppCard(
                          child: Row(
                            children: <Widget>[
                              CircleAvatar(
                                backgroundColor: colors.surfaceVariant,
                                child: Text(
                                  f.displayName[0],
                                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: Spacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(f.displayName, style: theme.textTheme.titleSmall),
                                    Text(
                                      f.stream.toUpperCase(),
                                      style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupChatScreen extends StatefulWidget {
  const _GroupChatScreen({required this.group});

  final StudyGroup group;

  @override
  State<_GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<_GroupChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      id: 'm1',
      senderId: 'other-1',
      senderName: 'Kasun',
      body: 'Welcome to the revision study circle! Today we are working on Paper 2.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(
        ChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          senderId: 'me',
          senderName: 'You',
          body: text,
          createdAt: DateTime.now(),
        ),
      );
      _msgController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(Spacing.md),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMe = msg.senderId == 'me';
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: isMe ? colors.primary : colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (!isMe)
                            Text(
                              msg.senderName,
                              style: theme.textTheme.labelSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.bold),
                            ),
                          Text(
                            msg.body,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isMe ? colors.onPrimary : colors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: l10n.socialSendMessage,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  IconButton(
                    icon: Icon(Icons.send, color: colors.primary),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
