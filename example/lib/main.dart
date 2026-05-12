import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mongo_realtime/mongo_realtime.dart';

void main() {
  MongoRealtime.connect('http://localhost:3000/ws', authData: 'ok');
  runApp(const MongoRealTimeExampleApp());
}

class MongoRealTimeExampleApp extends StatelessWidget {
  const MongoRealTimeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MongoRealTime Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E6D5D)),
        useMaterial3: true,
      ),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  final Random _random = Random();

  String u1Id = '69e8ee7021ed84fc8b04f1b6';

  Stream<List<RealtimeDocument<User>>> get _allUsersStream =>
      realtime
          .collection<User>('users', fromJson: User.fromJson)
          .sort('createdAt', descending: true)
          .stream;

  Stream<List<RealtimeDocument<User>>> get _adultUsersStream =>
      realtime
          .collection<User>('users', fromJson: User.fromJson)
          .where('age', isGreaterOrEqualTo: 18)
          .sort('createdAt', descending: true)
          .stream;

  Stream<RealtimeDocument<User>?> get _selectedUserStream =>
      realtime
          .collection<User>('users', fromJson: User.fromJson)
          .doc(u1Id)
          .stream;

  @override
  void initState() {
    super.initState();
    realtime.collection('users').watch.onChange((change) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Change detected: ${change.type} on document ${change.docId}',
            style: TextStyle(
              color: change.isDelete ? Colors.redAccent : Colors.greenAccent,
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MongoRealTime')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Global alias: realtime',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Connected endpoint: ${realtime.url}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: _insertRandomUser,
                  child: const Text('Insert User'),
                ),
                FilledButton.tonal(
                  onPressed: _birthdayForU1,
                  child: const Text('Birthday For u1'),
                ),
                OutlinedButton(
                  onPressed: _deleteLastUser,
                  child: const Text('Delete Latest User'),
                ),
                OutlinedButton(
                  onPressed: () {
                    realtime.reconnect();
                  },
                  child: const Text('Reconnect'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final res = await realtime.emit('calculate', [1, 52]);
                    print(res);
                  },
                  child: const Text('Send calculation event'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 660 ? 3 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.05,
                children: [
                  _StreamCard<List<RealtimeDocument<User>>>(
                    title: 'All Users',
                    stream: _allUsersStream,
                    builder: (context, snapshot) {
                      final users =
                          snapshot.data ?? const <RealtimeDocument<User>>[];
                      return _UserList(documents: users);
                    },
                  ),
                  _StreamCard<List<RealtimeDocument<User>>>(
                    title: 'Adults Only',
                    stream: _adultUsersStream,
                    builder: (context, snapshot) {
                      final users =
                          snapshot.data ?? const <RealtimeDocument<User>>[];
                      return _UserList(documents: users);
                    },
                  ),
                  _StreamCard<RealtimeDocument<User>?>(
                    title: 'Document Stream: u1',
                    stream: _selectedUserStream,
                    builder: (context, snapshot) {
                      final document = snapshot.data;
                      if (document == null) {
                        return const Center(
                          child: Text('Document not found or deleted.'),
                        );
                      }

                      final user =
                          document.value ?? User.fromJson(document.data);
                      return _UserDetails(user: user);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _insertRandomUser() {
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final id = 'u$createdAt';
    final age = 14 + _random.nextInt(18);

    return realtime.collection('users').insert({
      '_id': id,
      'name': 'User ${id.substring(id.length - 4)}',
      'age': age,
      'createdAt': createdAt,
      'tags': ['sample'],
    });
  }

  Future<void> _birthdayForU1() {
    return realtime
        .collection('users')
        .doc(u1Id)
        .update(
          $inc: {'age': 1},
          $addToSet: {'tags': 'birthday'},
          optimistic: true,
        );
  }

  Future<void> _deleteLastUser() async {
    final latest =
        await realtime
            .collection<User>('users', fromJson: User.fromJson)
            .sort('createdAt', descending: true)
            .limit(1)
            .find();

    if (latest.isEmpty) {
      return;
    }

    await realtime.collection('users').doc(latest.first.id).delete();
  }
}

class _StreamCard<T> extends StatelessWidget {
  const _StreamCard({
    required this.title,
    required this.stream,
    required this.builder,
  });

  final String title;
  final Stream<T> stream;
  final Widget Function(BuildContext context, AsyncSnapshot<T> snapshot)
  builder;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(child: StreamBuilder<T>(stream: stream, builder: builder)),
          ],
        ),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({required this.documents});

  final List<RealtimeDocument<User>> documents;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return const Center(child: Text('No matching users yet.'));
    }

    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total: ${documents.length}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),

        Expanded(
          child: ListView.separated(
            itemCount: documents.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final document = documents[index];
              final user = document.value ?? User.fromJson(document.data);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: document.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Document ID ${document.id} copied to clipboard',
                      ),
                    ),
                  );
                },
                title: Text(user.name),
                subtitle: Text('age ${user.age} • ${user.tags.join(', ')}'),
                trailing: Text(document.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserDetails extends StatelessWidget {
  const _UserDetails({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Age: ${user.age}'),
            const SizedBox(height: 8),
            Text(
              'Created: ${DateTime.fromMillisecondsSinceEpoch(user.createdAt)}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.tags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class User {
  User({
    required this.id,
    required this.name,
    required this.age,
    required this.createdAt,
    required this.tags,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] as String? ?? '',
      name: json['firstname'] as String? ?? 'Unknown',
      age: json['age'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(
            json['createdAt']?.toString() ?? '',
          )?.millisecondsSinceEpoch ??
          0,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }

  final String id;
  final String name;
  final int age;
  final int createdAt;
  final List<String> tags;
}
