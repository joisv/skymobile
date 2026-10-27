import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service caching gambar dua tingkat (Memory Tier 1 + Persistent Disk Tier 2)
/// dengan fitur in-flight request deduplication, batasan ukuran, dan metrik jaringan.
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  static ImageCacheService get instance => _instance;

  ImageCacheService._internal();

  // Tier 1: In-Memory Cache (URL/Hash -> Raw Bytes)
  final Map<String, Uint8List> _memoryCache = {};
  final List<String> _memoryLruKeys = [];
  final int _maxMemoryEntries = 120; // Maksimal 120 gambar di RAM

  // In-flight deduplication: mencegah request jaringan ganda untuk URL yang sama secara bersamaan
  final Map<String, Future<Uint8List?>> _inFlightRequests = {};

  // Custom mock downloader untuk testing
  Future<Uint8List?> Function(String url, Map<String, String>? headers)? _mockDownloader;

  // Custom cache directory untuk testing
  Directory? _testDirectory;

  // Performance & Network Metrics
  int _totalRequests = 0;
  int _networkDownloads = 0;
  int _duplicateDownloadsAvoided = 0;
  int _memoryHits = 0;
  int _diskHits = 0;
  int _totalBytesDownloaded = 0;
  int _totalBytesServedFromCache = 0;

  // Getters for Metrics
  int get totalRequests => _totalRequests;
  int get networkDownloads => _networkDownloads;
  int get duplicateDownloadsAvoided => _duplicateDownloadsAvoided;
  int get memoryHits => _memoryHits;
  int get diskHits => _diskHits;
  int get totalBytesDownloaded => _totalBytesDownloaded;
  int get totalBytesServedFromCache => _totalBytesServedFromCache;

  void resetMetrics() {
    _totalRequests = 0;
    _networkDownloads = 0;
    _duplicateDownloadsAvoided = 0;
    _memoryHits = 0;
    _diskHits = 0;
    _totalBytesDownloaded = 0;
    _totalBytesServedFromCache = 0;
  }

  Map<String, dynamic> getMetrics() {
    return {
      'totalRequests': _totalRequests,
      'networkDownloads': _networkDownloads,
      'duplicateDownloadsAvoided': _duplicateDownloadsAvoided,
      'memoryHits': _memoryHits,
      'diskHits': _diskHits,
      'totalBytesDownloaded': _totalBytesDownloaded,
      'totalBytesServedFromCache': _totalBytesServedFromCache,
      'cachedMemoryCount': _memoryCache.length,
    };
  }

  @visibleForTesting
  void setMockDownloader(Future<Uint8List?> Function(String url, Map<String, String>? headers)? downloader) {
    _mockDownloader = downloader;
  }

  @visibleForTesting
  void setTestDirectory(Directory? dir) {
    _testDirectory = dir;
  }

  /// Menghasilkan cache key unik berbasis hash SHA-256 dari URL
  String generateKey(String url) {
    return sha256.convert(utf8.encode(url.trim())).toString();
  }

  /// Mengambil lokasi folder disk cache lokal
  bool get _isTestEnvironment {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  Future<Directory?> _getDiskCacheDir() async {
    if (_testDirectory != null) {
      if (!await _testDirectory!.exists()) {
        await _testDirectory!.create(recursive: true);
      }
      return _testDirectory;
    }

    if (_isTestEnvironment) {
      return null;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/skyrental_image_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      return cacheDir;
    } catch (_) {
      return null;
    }
  }

  /// Mendapatkan bytes gambar dari Memory -> Disk -> Network (dengan deduplication)
  Future<Uint8List?> getImageBytes(
    String url, {
    Map<String, String>? headers,
    bool forceRefresh = false,
  }) async {
    if (url.trim().isEmpty) return null;

    final trimmedUrl = url.trim();
    final key = generateKey(trimmedUrl);
    _totalRequests++;

    // 1. Cek Tier 1: Memory Cache (jika tidak dipaksa refresh)
    if (!forceRefresh && _memoryCache.containsKey(key)) {
      _memoryHits++;
      final bytes = _memoryCache[key]!;
      _totalBytesServedFromCache += bytes.length;
      _updateMemoryLru(key);
      return bytes;
    }

    // 2. Cek Tier 2: Persistent Disk Cache (jika tidak dipaksa refresh)
    if (!forceRefresh) {
      final diskBytes = await _readFromDisk(key);
      if (diskBytes != null && diskBytes.isNotEmpty) {
        _diskHits++;
        _totalBytesServedFromCache += diskBytes.length;
        _saveToMemory(key, diskBytes);
        return diskBytes;
      }
    }

    // 3. Cek in-flight request deduplication
    // Jika ada request jaringan yang sedang berjalan untuk URL yang sama, gabung ke future yang ada
    if (_inFlightRequests.containsKey(key)) {
      _duplicateDownloadsAvoided++;
      return await _inFlightRequests[key]!;
    }

    // 4. Unduh dari Network melalui in-flight coalescing
    final fetchCompleter = Completer<Uint8List?>();
    _inFlightRequests[key] = fetchCompleter.future;

    try {
      final bytes = await _downloadNetwork(trimmedUrl, headers: headers);
      if (bytes != null && bytes.isNotEmpty) {
        _saveToMemory(key, bytes);
        await _writeToDisk(key, bytes);
      }
      fetchCompleter.complete(bytes);
      return bytes;
    } catch (e) {
      fetchCompleter.complete(null);
      return null;
    } finally {
      _inFlightRequests.remove(key);
    }
  }

  Future<Uint8List?> _downloadNetwork(String url, {Map<String, String>? headers}) async {
    if (_mockDownloader != null) {
      _networkDownloads++;
      final bytes = await _mockDownloader!(url, headers);
      if (bytes != null) _totalBytesDownloaded += bytes.length;
      return bytes;
    }

    if (_isTestEnvironment) {
      return null;
    }

    try {
      _networkDownloads++;
      final uri = Uri.parse(url);
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final bytes = response.bodyBytes;
        _totalBytesDownloaded += bytes.length;
        return bytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _saveToMemory(String key, Uint8List bytes) {
    if (_memoryCache.length >= _maxMemoryEntries) {
      final oldest = _memoryLruKeys.removeAt(0);
      _memoryCache.remove(oldest);
    }
    _memoryCache[key] = bytes;
    _updateMemoryLru(key);
  }

  void _updateMemoryLru(String key) {
    _memoryLruKeys.remove(key);
    _memoryLruKeys.add(key);
  }

  Future<Uint8List?> _readFromDisk(String key) async {
    try {
      final dir = await _getDiskCacheDir();
      if (dir == null) return null;
      final file = File('${dir.path}/$key.bin');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeToDisk(String key, Uint8List bytes) async {
    try {
      final dir = await _getDiskCacheDir();
      if (dir == null) return;
      final file = File('${dir.path}/$key.bin');
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  /// Menghapus cache spesifik untuk suatu URL
  Future<void> evict(String url) async {
    final key = generateKey(url);
    _memoryCache.remove(key);
    _memoryLruKeys.remove(key);

    try {
      final dir = await _getDiskCacheDir();
      if (dir != null) {
        final file = File('${dir.path}/$key.bin');
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
  }

  /// Menghapus seluruh cache (RAM dan Disk)
  Future<void> clearAll() async {
    _memoryCache.clear();
    _memoryLruKeys.clear();
    _inFlightRequests.clear();
    resetMetrics();

    try {
      final dir = await _getDiskCacheDir();
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (_) {}
  }
}
