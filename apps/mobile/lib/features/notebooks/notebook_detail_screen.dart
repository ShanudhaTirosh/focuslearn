import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import 'notebook_models.dart';
import 'notebook_repository.dart';

/// Detailed view of a Notebook: Sources, Grounded Chat, and AI Study Tools.
class NotebookDetailScreen extends ConsumerStatefulWidget {
  const NotebookDetailScreen({super.key, required this.notebook});

  final Notebook notebook;

  @override
  ConsumerState<NotebookDetailScreen> createState() => _NotebookDetailScreenState();
}

class _NotebookDetailScreenState extends ConsumerState<NotebookDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<NotebookSource> _sources = <NotebookSource>[];
  List<NotebookChatMessage> _messages = <NotebookChatMessage>[];
  List<StudyArtifact> _artifacts = <StudyArtifact>[];

  bool _isLoading = false;
  bool _isSendingChat = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final repo = ref.read(notebookRepositoryProvider);

    final sources = await repo.fetchSources(widget.notebook.id);
    final chats = await repo.fetchChats(widget.notebook.id);
    final artifacts = await repo.fetchArtifacts(widget.notebook.id);

    if (mounted) {
      setState(() {
        _sources = sources;
        _messages = chats;
        _artifacts = artifacts;
        _isLoading = false;
      });
    }
  }

  void _showAddSourceDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Source Document / Notes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppTextField(
                  controller: titleController,
                  label: 'Source Title (e.g. Newton Laws Summary)',
                ),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: contentController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Paste Study Notes / Textbook Text',
                    hintText: 'Paste paragraphs, syllabus points or lecture text here...',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final content = contentController.text.trim();
                if (title.isNotEmpty && content.isNotEmpty) {
                  Navigator.of(ctx).pop();
                  setState(() => _isLoading = true);
                  await ref.read(notebookRepositoryProvider).addTextSource(
                    notebookId: widget.notebook.id,
                    title: title,
                    content: content,
                  );
                  await _loadAll();
                }
              },
              child: const Text('Index & Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendChat() async {
    final q = _chatController.text.trim();
    if (q.isEmpty || _isSendingChat) return;

    _chatController.clear();
    setState(() {
      _isSendingChat = true;
      _messages.add(
        NotebookChatMessage(
          id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
          notebookId: widget.notebook.id,
          role: 'user',
          content: q,
          createdAt: DateTime.now(),
        ),
      );
    });

    _scrollToBottom();

    final repo = ref.read(notebookRepositoryProvider);
    final botMsg = await repo.askGroundedQuestion(
      notebookId: widget.notebook.id,
      question: q,
    );

    if (mounted) {
      setState(() {
        _isSendingChat = false;
        if (botMsg != null) {
          _messages.add(botMsg);
        }
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _generateArtifact(String type) async {
    setState(() => _isLoading = true);
    final repo = ref.read(notebookRepositoryProvider);
    final art = await repo.generateArtifact(
      notebookId: widget.notebook.id,
      artifactType: type,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (art != null) {
          _artifacts.insert(0, art);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.notebook.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: 'Sources', icon: Icon(Icons.source_outlined)),
            Tab(text: 'Grounded Chat', icon: Icon(Icons.chat_outlined)),
            Tab(text: 'Study Tools', icon: Icon(Icons.school_outlined)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: <Widget>[
            _buildSourcesTab(theme, colors),
            _buildChatTab(theme, colors),
            _buildToolsTab(theme, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcesTab(ThemeData theme, AppColors colors) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('${_sources.length} Indexed Sources', style: theme.textTheme.titleMedium),
              FilledButton.icon(
                onPressed: _showAddSourceDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Source'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _sources.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.description_outlined, size: 48, color: colors.textMuted),
                      const SizedBox(height: Spacing.sm),
                      Text('No sources added yet.', style: TextStyle(color: colors.textMuted)),
                      const SizedBox(height: Spacing.md),
                      FilledButton.tonal(
                        onPressed: _showAddSourceDialog,
                        child: const Text('Paste Notes or Text to Start'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(Spacing.md),
                  itemCount: _sources.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
                  itemBuilder: (context, index) {
                    final s = _sources[index];
                    return AppCard(
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.article_outlined, color: colors.primary),
                          const SizedBox(width: Spacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(s.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                                Text(
                                  '${s.sourceType.toUpperCase()} • ${s.charCount} chars',
                                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(s.status, style: const TextStyle(fontSize: 10)),
                            backgroundColor: s.status == 'ready'
                                ? Colors.green.withValues(alpha: 0.15)
                                : colors.surfaceVariant,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChatTab(ThemeData theme, AppColors colors) {
    return Column(
      children: <Widget>[
        // Grounding Notice Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
          color: colors.primary.withValues(alpha: 0.08),
          child: Row(
            children: <Widget>[
              Icon(Icons.verified_user_outlined, size: 16, color: colors.primary),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Text(
                  'Grounded strictly in your uploaded sources. Cites exact pages & excerpts.',
                  style: TextStyle(fontSize: 11, color: colors.primary),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.forum_outlined, size: 48, color: colors.textMuted),
                      const SizedBox(height: Spacing.sm),
                      Text('Ask any question grounded in your notebook sources.', style: TextStyle(color: colors.textMuted)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(Spacing.md),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg.role == 'user';

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(Spacing.md),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                        decoration: BoxDecoration(
                          color: isUser ? colors.primary : colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(Radii.lg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              msg.content,
                              style: TextStyle(color: isUser ? colors.onPrimary : colors.text),
                            ),
                            if (msg.citations.isNotEmpty) ...<Widget>[
                              const SizedBox(height: Spacing.sm),
                              const Divider(height: 1),
                              const SizedBox(height: 4),
                              Text('Sources Cited:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.textMuted)),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: msg.citations.map((c) {
                                  return ActionChip(
                                    label: Text('${c.sourceTitle} (p. ${c.pageNumber})', style: const TextStyle(fontSize: 10)),
                                    onPressed: () {
                                      showDialog<void>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('${c.sourceTitle} - Page ${c.pageNumber}'),
                                          content: Text(c.snippet),
                                          actions: <Widget>[
                                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_isSendingChat) const LinearProgressIndicator(),
        Container(
          padding: const EdgeInsets.all(Spacing.sm),
          decoration: BoxDecoration(
            color: colors.surface,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Ask your sources a question...',
                  ),
                  onSubmitted: (_) => _sendChat(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                color: colors.primary,
                onPressed: _sendChat,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolsTab(ThemeData theme, AppColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('AI Generation from Sources', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _isLoading ? null : () => _generateArtifact('guide'),
                icon: const Icon(Icons.summarize_outlined),
                label: const Text('Study Guide'),
              ),
              FilledButton.tonalIcon(
                onPressed: _isLoading ? null : () => _generateArtifact('flashcards'),
                icon: const Icon(Icons.style_outlined),
                label: const Text('Flashcards'),
              ),
              FilledButton.tonalIcon(
                onPressed: _isLoading ? null : () => _generateArtifact('quiz'),
                icon: const Icon(Icons.quiz_outlined),
                label: const Text('Practice Quiz'),
              ),
              FilledButton.tonalIcon(
                onPressed: _isLoading ? null : () => _generateArtifact('audio_overview'),
                icon: const Icon(Icons.podcasts_outlined),
                label: const Text('Audio Overview Script'),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Text('Generated Study Artifacts', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          if (_artifacts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Text('No artifacts generated yet. Tap a button above!', style: TextStyle(color: colors.textMuted)),
              ),
            )
          else
            for (final art in _artifacts)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(art.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          Chip(label: Text(art.artifactType.toUpperCase(), style: const TextStyle(fontSize: 10))),
                        ],
                      ),
                      const Divider(),
                      if (art.data is List)
                        Text('${(art.data as List).length} Items generated ready for review.')
                      else if (art.data is Map && (art.data as Map).containsKey('text'))
                        Text((art.data as Map)['text'].toString(), maxLines: 5, overflow: TextOverflow.ellipsis)
                      else
                        Text(art.data.toString(), maxLines: 5, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
