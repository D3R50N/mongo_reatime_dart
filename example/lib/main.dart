import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mongo_realtime/mongo_realtime.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = ExampleController();

  MongoRealtime.init(
    'https://frisz-api-dev.onrender.com/',
    autoConnect: true,
    token: '1234',
    showLogs: true,
    onConnect:
        (_) => controller.setConnection(
          status: ConnectionStatus.connected,
          detail: 'Socket connected to realtime server',
        ),
    onConnectError:
        (error) => controller.setConnection(
          status: ConnectionStatus.error,
          detail: '$error',
        ),
    onError:
        (error) => controller.setConnection(
          status: ConnectionStatus.error,
          detail: '$error',
        ),
    onDisconnect:
        (reason) => controller.setConnection(
          status: ConnectionStatus.disconnected,
          detail: '$reason',
        ),
  );

  controller.bindRealtime(kRealtime);

  runApp(ExampleApp(controller: controller));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, required this.controller});

  final ExampleController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mongo Realtime Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7F5),
        useMaterial3: true,
      ),
      home: ExampleDashboard(controller: controller),
    );
  }
}

enum ConnectionStatus { connecting, connected, disconnected, error }

class ExampleController {
  final ValueNotifier<ConnectionStatus> status = ValueNotifier(
    ConnectionStatus.connecting,
  );
  final ValueNotifier<String> statusDetail = ValueNotifier(
    'Connecting to realtime server...',
  );
  final ValueNotifier<List<ActivityItem>> activity = ValueNotifier([]);
  final ValueNotifier<int> deletedPosts = ValueNotifier(0);

  final List<RealtimeListener> _listeners = [];
  StreamSubscription<RealtimeChange>? _deleteSubscription;

  void setConnection({
    required ConnectionStatus status,
    required String detail,
  }) {
    this.status.value = status;
    statusDetail.value = detail;
  }

  void bindRealtime(MongoRealtime realtime) {
    _listeners.add(
      realtime
          .col('posts')
          .onChange(
            types: const [
              RealtimeChangeType.insert,
              RealtimeChangeType.update,
              RealtimeChangeType.replace,
            ],
            callback: (change) {
              final title = PostViewData.fromMap(change.doc ?? {}).title;
              addActivity(
                ActivityItem(
                  label: change.type.name,
                  message:
                      title == null || title.isEmpty
                          ? 'Post ${change.documentId} updated'
                          : '$title updated',
                  color: _colorForChange(change.type),
                ),
              );
            },
          ),
    );

    final deleteListener = realtime
        .db(['posts'])
        .onChange(types: [RealtimeChangeType.delete]);
    _listeners.add(deleteListener);
    _deleteSubscription = deleteListener.stream.listen((change) {
      deletedPosts.value = deletedPosts.value + 1;
      addActivity(
        ActivityItem(
          label: 'delete',
          message: 'Post ${change.documentId} removed from collection',
          color: const Color(0xFFB42318),
        ),
      );
    });
  }

  void addActivity(ActivityItem item) {
    activity.value = [item, ...activity.value].take(8).toList();
  }

  Color _colorForChange(RealtimeChangeType type) {
    switch (type) {
      case RealtimeChangeType.insert:
        return const Color(0xFF0F9D58);
      case RealtimeChangeType.update:
        return const Color(0xFF2563EB);
      case RealtimeChangeType.delete:
        return const Color(0xFFB42318);
      case RealtimeChangeType.replace:
        return const Color(0xFF7C3AED);
      case RealtimeChangeType.invalidate:
        return const Color(0xFF9A3412);
      case RealtimeChangeType.drop:
        return const Color(0xFF5B21B6);
    }
  }

  void dispose() {
    for (final listener in _listeners) {
      listener.cancel();
    }
    _deleteSubscription?.cancel();
    status.dispose();
    statusDetail.dispose();
    activity.dispose();
    deletedPosts.dispose();
  }
}

class ExampleDashboard extends StatefulWidget {
  const ExampleDashboard({super.key, required this.controller});

  final ExampleController controller;

  @override
  State<ExampleDashboard> createState() => _ExampleDashboardState();
}

class _ExampleDashboardState extends State<ExampleDashboard> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Posts Monitor'),
        centerTitle: false,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: kRealtime.stream('posts', reverse: true, limit: 300),
        builder: (context, snapshot) {
          final posts =
              (snapshot.data ?? const <Map<String, dynamic>>[])
                  .map(PostViewData.fromMap)
                  .toList()
                ..sort((a, b) => b.sortDate.compareTo(a.sortDate));

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final content = [
                  _OverviewSection(
                    controller: widget.controller,
                    totalPosts: posts.length,
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.hasError)
                    _ErrorBanner(error: '${snapshot.error}')
                  else if (!snapshot.hasData)
                    const _LoadingBanner(),
                  if (snapshot.hasData) const SizedBox(height: 16),
                  wide
                      ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _PostsPanel(posts: posts)),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _ActivityPanel(
                              controller: widget.controller,
                            ),
                          ),
                        ],
                      )
                      : Column(
                        children: [
                          _PostsPanel(posts: posts),
                          const SizedBox(height: 16),
                          _ActivityPanel(controller: widget.controller),
                        ],
                      ),
                ];

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: content,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.controller, required this.totalPosts});

  final ExampleController controller;
  final int totalPosts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Concrete demo project',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'This example shows a live content board powered by MongoDB realtime events.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ValueListenableBuilder(
              valueListenable: controller.status,
              builder: (context, status, _) {
                return _StatCard(
                  title: 'Connection',
                  value: _statusLabel(status),
                  accent: _statusColor(status),
                );
              },
            ),
            _StatCard(
              title: 'Visible posts',
              value: '$totalPosts',
              accent: const Color(0xFF0F766E),
            ),
            ValueListenableBuilder(
              valueListenable: controller.deletedPosts,
              builder: (context, deletedPosts, _) {
                return _StatCard(
                  title: 'Delete events',
                  value: '$deletedPosts',
                  accent: const Color(0xFFB42318),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder(
          valueListenable: controller.statusDetail,
          builder: (context, detail, _) {
            return Text(
              detail,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            );
          },
        ),
      ],
    );
  }

  static String _statusLabel(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connecting:
        return 'Connecting';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.error:
        return 'Error';
    }
  }

  static Color _statusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connecting:
        return const Color(0xFFB45309);
      case ConnectionStatus.connected:
        return const Color(0xFF15803D);
      case ConnectionStatus.disconnected:
        return const Color(0xFF475467);
      case ConnectionStatus.error:
        return const Color(0xFFB42318);
    }
  }
}

class _PostsPanel extends StatelessWidget {
  const _PostsPanel({required this.posts});

  final List<PostViewData> posts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live posts', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (posts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No posts received yet.'),
            )
          else
            ...posts.map((post) => _PostTile(post: post)),
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});

  final PostViewData post;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uid = Uuid.long();
        final res = await kRealtime
            .col('posts')
            .doc(post.id)
            .update($set: {'description': uid});
        print(res);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title ?? 'Untitled post',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(label: post.author ?? 'Unknown author'),
                _MetaChip(label: post.collectionLabel),
                _MetaChip(label: post.displayDate),
              ],
            ),
            if (post.summary != null) ...[
              const SizedBox(height: 10),
              Text(
                post.summary!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    post.tags.take(4).map((tag) => _TagChip(tag: tag)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.controller});

  final ExampleController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ValueListenableBuilder(
        valueListenable: controller.activity,
        builder: (context, items, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Waiting for realtime events...'),
                )
              else
                ...items.map((item) => _ActivityTile(item: item)),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: item.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(item.message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.accent,
  });

  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD0D5DD)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '#$tag',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: const Color(0xFF027A48)),
      ),
    );
  }
}

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Loading posts from the realtime stream...')),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Realtime stream error: $error',
        style: const TextStyle(color: Color(0xFFB42318)),
      ),
    );
  }
}

class ActivityItem {
  const ActivityItem({
    required this.label,
    required this.message,
    required this.color,
  });

  final String label;
  final String message;
  final Color color;
}

class PostViewData {
  const PostViewData({
    required this.id,
    required this.collectionLabel,
    required this.raw,
    this.title,
    this.summary,
    this.author,
    this.publishedAt,
    this.tags = const [],
  });

  final String id;
  final String collectionLabel;
  final Map<String, dynamic> raw;
  final String? title;
  final String? summary;
  final String? author;
  final DateTime? publishedAt;
  final List<String> tags;

  DateTime get sortDate =>
      publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  String get displayDate {
    final date = publishedAt;
    if (date == null) return 'No publish date';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  factory PostViewData.fromMap(Map<String, dynamic> map) {
    final title = _pickString(map, const [
      'title',
      'name',
      'label',
      'headline',
    ]);
    final summary = _pickString(map, const [
      'content',
      'description',
      'excerpt',
      'body',
      'text',
    ]);
    final author = _pickString(map, const [
      'authorName',
      'author',
      'username',
      'createdBy',
      'firstname',
      'lastname',
    ]);

    return PostViewData(
      id: '${map['_id'] ?? 'unknown'}',
      collectionLabel: _pickString(map, const ['type', 'category']) ?? 'posts',
      raw: map,
      title: title,
      summary: summary ?? _jsonPreview(map),
      author: author,
      publishedAt: _pickDate(map, const [
        'datePublished',
        'publishedAt',
        'createdAt',
        'updatedAt',
        'date',
      ]),
      tags: _pickTags(map),
    );
  }

  static String? _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    for (final entry in map.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        final nested = _pickString(value, keys);
        if (nested != null) return nested;
      }
    }

    return null;
  }

  static DateTime? _pickDate(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final parsed = _toDate(map[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
      }
      if (value > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000).toLocal();
      }
    }
    if (value is Map<String, dynamic>) {
      final dateValue = value[r'$date'];
      return _toDate(dateValue);
    }
    return null;
  }

  static List<String> _pickTags(Map<String, dynamic> map) {
    final dynamic tags = map['tags'] ?? map['keywords'] ?? map['categories'];
    if (tags is List) {
      return tags.map((tag) => '$tag').where((tag) => tag.isNotEmpty).toList();
    }
    return const [];
  }

  static String _jsonPreview(Map<String, dynamic> map) {
    try {
      return const JsonEncoder.withIndent('  ').convert(map);
    } catch (_) {
      return map.toString();
    }
  }
}
