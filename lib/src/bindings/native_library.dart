import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'zenoh_bindings.dart';

/// Handles dynamic library resolution per platform.
class NativeLibrary {
  NativeLibrary._();

  static final NativeLibrary instance = NativeLibrary._();

  ZenohBindings? _cached;

  Future<ZenohBindings> ensureBindings() async {
    final cached = _cached;
    if (cached != null) {
      return cached;
    }

    final library = await _loadDynamicLibrary();
    final bindings = ZenohBindings(library);
    _cached = bindings;
    return bindings;
  }

  Future<DynamicLibrary> _loadDynamicLibrary() async {
    final name = _libraryFileName();
    final bundledPath = await _resolveBundledLibraryPath(name);
    if (bundledPath != null) {
      return DynamicLibrary.open(bundledPath.path);
    }

    // Fallback to process-wide lookup (useful for development and desktop).
    return DynamicLibrary.open(name);
  }

  Future<File?> _resolveBundledLibraryPath(String libraryName) async {
    // Collect likely directory locations for packaged native binaries and return the first one containing the library.
    final candidates = <Directory>[];
    final seenPaths = <String>{};
    final arch = _architectureSubdirectory();
    final platformDir = _platformDirectoryName();

    final executableDir = _resolveExecutableDirectory();
    if (executableDir != null) {
      if (Platform.isMacOS || Platform.isIOS) {
        candidates.add(
            Directory.fromUri(executableDir.uri.resolve('../Frameworks/')));
      }
      if (Platform.isWindows) {
        candidates.add(Directory.fromUri(executableDir.uri
            .resolve('data/flutter_assets/flutter_plugins/zenoh_dart/')));
      }
      if (platformDir != null && arch != null) {
        candidates.add(Directory.fromUri(
          executableDir.uri.resolve(
            'data/flutter_assets/native_assets/$platformDir/$arch/',
          ),
        ));
      }
      candidates.add(executableDir);
    }

    final packageRoot = await _packageRootDirectory();
    if (packageRoot != null) {
      candidates.addAll(_nativeAssetDirectories(packageRoot));
      if (platformDir != null && arch != null) {
        candidates.add(
          Directory(
              '${packageRoot.path}/build/native_assets/$platformDir/$arch'),
        );
      }
    }

    for (final dir in candidates) {
      final path = dir.path;
      if (!seenPaths.add(path)) {
        continue;
      }
      if (!dir.existsSync()) {
        continue;
      }

      final candidateFile = File('${dir.path}/$libraryName');
      if (candidateFile.existsSync()) {
        return candidateFile;
      }
    }

    return null;
  }

  Directory? _resolveExecutableDirectory() {
    try {
      final executable = File(Platform.resolvedExecutable);
      return executable.parent;
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _packageRootDirectory() async {
    try {
      final packageUri = await Isolate.resolvePackageUri(
          Uri.parse('package:zenoh_dart/zenoh_dart.dart'));
      if (packageUri == null || packageUri.scheme != 'file') {
        return null;
      }
      final libDir = File.fromUri(packageUri).parent;
      return libDir.parent;
    } catch (_) {
      return null;
    }
  }

  Iterable<Directory> _nativeAssetDirectories(Directory root) sync* {
    if (Platform.isIOS) {
      final frameworks = Directory('${root.path}/native/ios/Frameworks');
      if (frameworks.existsSync()) {
        yield frameworks;
      }
      return;
    }

    final arch = _architectureSubdirectory();
    if (arch == null) {
      return;
    }

    final platformDir = _platformDirectoryName();
    if (platformDir == null) {
      return;
    }

    final base = Directory('${root.path}/native/$platformDir/$arch');
    if (base.existsSync()) {
      yield base;
    }

    if (Platform.isWindows) {
      final msvc = Directory('${base.path}/msvc');
      if (msvc.existsSync()) {
        yield msvc;
      }
      final gnu = Directory('${base.path}/gnu');
      if (gnu.existsSync()) {
        yield gnu;
      }
    }
  }

  String? _platformDirectoryName() {
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isLinux) {
      return 'linux';
    }
    if (Platform.isMacOS) {
      return 'macos';
    }
    if (Platform.isWindows) {
      return 'windows';
    }
    return null;
  }

  String? _architectureSubdirectory() {
    final abi = Abi.current();

    if (Platform.isAndroid) {
      if (abi == Abi.androidArm) {
        return 'armeabi-v7a';
      }
      if (abi == Abi.androidArm64) {
        return 'arm64-v8a';
      }
      if (abi == Abi.androidX64) {
        return 'x86_64';
      }
      return null;
    }

    if (Platform.isLinux) {
      if (abi == Abi.linuxArm) {
        return 'armv7';
      }
      if (abi == Abi.linuxArm64) {
        return 'aarch64';
      }
      if (abi == Abi.linuxX64) {
        return 'x86_64';
      }
      return null;
    }

    if (Platform.isMacOS) {
      if (abi == Abi.macosArm64) {
        return 'aarch64';
      }
      if (abi == Abi.macosX64) {
        return 'x86_64';
      }
      return null;
    }

    if (Platform.isWindows) {
      if (abi == Abi.windowsX64) {
        return 'x64';
      }
      if (abi == Abi.windowsArm64) {
        return 'arm64';
      }
      return null;
    }

    return null;
  }

  String _libraryFileName() {
    if (Platform.isMacOS) {
      return 'libzenoh.dylib';
    }
    if (Platform.isIOS) {
      return 'libzenoh.dylib';
    }
    if (Platform.isWindows) {
      return 'zenoh.dll';
    }
    if (Platform.isAndroid || Platform.isLinux) {
      return 'libzenoh.so';
    }
    throw UnsupportedError(
        'Zenoh native bindings are not supported on this platform yet.');
  }
}
