import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/image_cache_service.dart';

/// Reusable Widget untuk menampilkan gambar jaringan dengan persistent disk cache,
/// memory cache, dan in-flight deduplication.
class AppCachedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  final int? cacheWidth;
  final int? cacheHeight;
  final WidgetBuilder? placeholder;
  final Widget Function(BuildContext context, Object error)? errorWidget;

  const AppCachedNetworkImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  State<AppCachedNetworkImage> createState() => _AppCachedNetworkImageState();
}

class _AppCachedNetworkImageState extends State<AppCachedNetworkImage> {
  Uint8List? _bytes;
  bool _isLoading = true;
  bool _hasError = false;
  String? _loadedUrl;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant AppCachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final url = widget.imageUrl.trim();
    if (url.isEmpty) {
      if (mounted) {
        setState(() {
          _bytes = null;
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    if (_loadedUrl == url && _bytes != null) {
      return;
    }

    if (!_isLoading && mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final bytes = await ImageCacheService.instance.getImageBytes(url);
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _isLoading = false;
          _hasError = bytes == null || bytes.isEmpty;
          _loadedUrl = url;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _bytes = null;
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = widget.placeholder != null
          ? widget.placeholder!(context)
          : Container(
              width: widget.width,
              height: widget.height,
              color: const Color(0xFFF1F5F9),
              alignment: Alignment.center,
              child: Icon(
                Icons.image_outlined,
                size: (widget.width != null && widget.width! > 24) ? (widget.width! * 0.4) : 16,
                color: const Color(0xFF94A3B8),
              ),
            );
    } else if (_hasError || _bytes == null) {
      content = widget.errorWidget != null
          ? widget.errorWidget!(context, 'Gagal memuat gambar')
          : const Center(
              child: Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey),
            );
    } else {
      content = Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        errorBuilder: (ctx, err, stack) => widget.errorWidget != null
            ? widget.errorWidget!(ctx, err)
            : const Center(
                child: Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey),
              ),
      );
    }

    if (widget.radius > 0) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: content,
      );
    }

    if (widget.width != null || widget.height != null) {
      content = SizedBox(
        width: widget.width,
        height: widget.height,
        child: content,
      );
    }

    return content;
  }
}
