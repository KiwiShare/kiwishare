import 'dart:async';

import 'package:flutter/material.dart';

/// A network image tuned for listing cards.
///
/// Camera photos are commonly much larger than their on-screen card. Decoding
/// them at the rendered size avoids unnecessary memory pressure, while a small
/// bounded retry handles the short window where a newly uploaded R2 object is
/// not yet available through the public cache.
class ResilientNetworkImage extends StatefulWidget {
  const ResilientNetworkImage({
    super.key,
    required this.url,
    required this.logicalCacheWidth,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.frameBuilder,
    this.loadingBuilder,
    this.semanticLabel,
    this.maximumRetries = 2,
  });

  final String url;
  final double logicalCacheWidth;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageFrameBuilder? frameBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final String? semanticLabel;
  final int maximumRetries;

  @override
  State<ResilientNetworkImage> createState() => _ResilientNetworkImageState();
}

class _ResilientNetworkImageState extends State<ResilientNetworkImage> {
  int _attempt = 0;
  bool _retryScheduled = false;
  Timer? _retryTimer;

  @override
  void didUpdateWidget(covariant ResilientNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _retryTimer?.cancel();
      _attempt = 0;
      _retryScheduled = false;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  String get _requestUrl {
    if (_attempt == 0) return widget.url;
    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme) return widget.url;
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'kiwishare_retry': _attempt.toString(),
          },
        )
        .toString();
  }

  void _scheduleRetry() {
    if (_retryScheduled || _attempt >= widget.maximumRetries) return;
    _retryScheduled = true;
    final failedUrl = widget.url;
    _retryTimer = Timer(Duration(milliseconds: 400 * (_attempt + 1)), () {
      if (!mounted || failedUrl != widget.url) return;
      setState(() {
        _attempt += 1;
        _retryScheduled = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (widget.logicalCacheWidth * devicePixelRatio)
        .round()
        .clamp(1, 2048);

    return Image.network(
      _requestUrl,
      key: ValueKey('${widget.url}#$_attempt'),
      fit: widget.fit,
      cacheWidth: cacheWidth,
      semanticLabel: widget.semanticLabel,
      frameBuilder: widget.frameBuilder,
      loadingBuilder: widget.loadingBuilder,
      errorBuilder: (context, error, stackTrace) {
        _scheduleRetry();
        return widget.errorBuilder?.call(context, error, stackTrace) ??
            const Center(child: Icon(Icons.image_not_supported_outlined));
      },
    );
  }
}
