import 'package:flutter/material.dart';
import '../../widgets/image_file_view.dart';

class ImagePreviewPage extends StatefulWidget {
  final List<dynamic> images;
  final int initialIndex;

  const ImagePreviewPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.images.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: hasMultiple
            ? Text(
                '${_currentIndex + 1} / ${widget.images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : null,
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.images.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            return Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: buildImageFileWidget(widget.images[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}
