import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // 🔥 Immersive UI: Extends the image behind the top bar
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: widget.imageUrls.length > 1 
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(150),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                "${_currentIndex + 1} / ${widget.imageUrls.length}",
                style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : const SizedBox.shrink(),
        centerTitle: true,
        backgroundColor: Colors.transparent, // Transparent so the image shows through
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
          shadows: [Shadow(color: Colors.black45, blurRadius: 4)], // Ensures back button is visible on light images
        ),
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(widget.imageUrls[index]),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3, // Allows zooming in 3x
            // Hero tag matches the thumbnail for that buttery smooth "pop" transition
            heroAttributes: PhotoViewHeroAttributes(tag: widget.imageUrls[index]),
          );
        },
        itemCount: widget.imageUrls.length,
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF52B788)), // Matches your theme
        ),
        pageController: PageController(initialPage: widget.initialIndex),
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}