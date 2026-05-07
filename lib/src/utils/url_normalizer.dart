part of '../../mongo_realtime.dart';

class RealtimeNormalizedUrl {
  const RealtimeNormalizedUrl({required this.url, this.warning});

  final String url;
  final String? warning;
}

RealtimeNormalizedUrl normalizeWebSocketUrl(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return const RealtimeNormalizedUrl(
      url: 'ws://localhost:3000',
      warning: 'Received an empty URL and defaulted to ws://localhost:3000.',
    );
  }

  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*://').hasMatch(trimmed);
  final candidate = hasScheme ? trimmed : 'ws://$trimmed';
  final uri = Uri.tryParse(candidate);

  if (uri == null) {
    return RealtimeNormalizedUrl(
      url: 'ws://${trimmed.replaceAll(' ', '')}',
      warning:
          'Could not fully parse "$input" and normalized it to a ws:// URL.',
    );
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'ws' || scheme == 'wss') {
    return RealtimeNormalizedUrl(url: uri.toString());
  }

  if (scheme == 'http' || scheme == 'https') {
    final replacement = uri.replace(scheme: scheme == 'https' ? 'wss' : 'ws');
    return RealtimeNormalizedUrl(
      url: replacement.toString(),
      warning: 'Normalized "$input" from $scheme to ${replacement.scheme}.',
    );
  }

  final normalized = uri.replace(scheme: 'ws');
  return RealtimeNormalizedUrl(
    url: normalized.toString(),
    warning:
        'MongoRealtime normalized the unsupported "$scheme" scheme in "$input" to ws.',
  );
}
