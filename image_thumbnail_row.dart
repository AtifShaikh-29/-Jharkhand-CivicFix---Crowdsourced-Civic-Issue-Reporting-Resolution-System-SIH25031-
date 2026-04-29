import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'full_screen_image_viewer.dart';

class ImageThumbnailRow extends StatelessWidget {
  final List<String> imageUrls;
  final double size;

  const ImageThumbnailRow({
    super.key,
    required this.imageUrls,
    this.size = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: imageUrls.asMap().entries.map((entry) {
        final int index = entry.key;
        final String url = entry.value;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenImageViewer(
                imageUrls: imageUrls,
                initialIndex: index,
              ),
            ),
          ),
          child: Hero(
            tag: url, // Matches the FullScreenImageViewer for the smooth transition
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300), // Subtle border for light images
                color: const Color(0xFFF1F3F4), // Light grey background while loading
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7), // Slightly less than container to fit inside border
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, 
                        color: Color(0xFF52B788), // Jharkhand Green
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image_rounded, 
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}