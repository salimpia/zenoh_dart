import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Downloads Zenoh native binaries listed in [tool/zenoh_binaries.json].
Future<void> main(List<String> arguments) async {
  final configFile = File('tool/zenoh_binaries.json');
  if (!configFile.existsSync()) {
    stderr.writeln('Configuration file tool/zenoh_binaries.json not found.');
    exitCode = 1;
    return;
  }

  final entries = jsonDecode(await configFile.readAsString()) as List<dynamic>;
  if (entries.isEmpty) {
    stdout.writeln('No binaries to download.');
    return;
  }

  for (final raw in entries) {
    final map = Map<String, dynamic>.from(raw as Map);
    final platform = map['platform'] as String? ?? 'unknown';
    final url = map['url'] as String? ?? '';
    final outputPath = map['output'] as String?;
    final sha256 = (map['sha256'] as String?)?.trim();

    if (outputPath == null) {
      stderr.writeln('Skipping $platform: missing output path.');
      continue;
    }

    if (url.isEmpty || url.contains('TODO')) {
      stdout.writeln('Skipping $platform: URL not configured yet.');
      continue;
    }

    stdout.writeln('Downloading $platform from $url ...');
    try {
      final bytes = await _downloadBytes(url);
      await _writeFile(outputPath, bytes);

      if (sha256 != null && sha256.isNotEmpty) {
        final digest = sha256Convert(bytes);
        if (digest != sha256) {
          throw StateError('Checksum mismatch: expected $sha256 but got $digest');
        }
      }

      stdout.writeln('Saved to $outputPath');
    } catch (error) {
      stderr.writeln('Failed to fetch $platform: $error');
      exitCode = 1;
    }
  }
}

Future<List<int>> _downloadBytes(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('Unexpected status ${response.statusCode}', uri: Uri.parse(url));
    }
    final bytes = await response.fold<List<int>>(<int>[], (buffer, chunk) {
      buffer.addAll(chunk);
      return buffer;
    });
    return bytes;
  } finally {
    client.close();
  }
}

Future<void> _writeFile(String outputPath, List<int> bytes) async {
  final file = File(outputPath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
}

String sha256Convert(List<int> bytes) => sha256.convert(bytes).toString();
