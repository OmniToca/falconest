import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Síťový obrázek s disk/memory cache a dekódováním na velikost widgetu (P2 výkon).
///
/// PROČ: Holé [Image.network] při scrollu Kanbanu / galerie drží plné bitmapy v RAM
/// a znovu stahuje stejné URL. [CachedNetworkImage] + `memCacheWidth/Height` snižuje
/// jank a egress po opakovaném otevření admin obrazovek.
class FalconestNetworkImage extends StatelessWidget {
  const FalconestNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorBuilder,
    this.placeholder,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext context, String url, Object error)?
      errorBuilder;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW =
        width != null && width!.isFinite ? (width! * dpr).round() : null;
    final memH =
        height != null && height!.isFinite ? (height! * dpr).round() : null;

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memW,
      memCacheHeight: memH,
      placeholder: placeholder != null
          ? (context, url) => placeholder!
          : (context, url) => SizedBox(
                width: width,
                height: height,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
      errorWidget: (context, url, error) {
        if (errorBuilder != null) {
          return errorBuilder!(context, url, error);
        }
        return SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.broken_image_outlined),
        );
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
