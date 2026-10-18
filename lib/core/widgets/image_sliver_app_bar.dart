import 'package:flutter/material.dart';

/// SliverAppBar แสดงรูปภาพแบบ carousel ที่ยืดหด (collapse) ได้ตอนเลื่อนจอ
/// ใช้ร่วมกันทุกหน้ารายละเอียดที่มีรูปภาพเป็นพระเอก (หอพัก/ห้องพัก ฯลฯ)
/// มีจุดไล่สี scrim ด้านล่างให้ปุ่มย้อนกลับ/ตัวนับหน้ายังอ่านง่ายแม้รูปพื้นหลังสว่าง
class ImageSliverAppBar extends StatefulWidget {
  final List<String> images;
  final IconData placeholderIcon;

  const ImageSliverAppBar({
    super.key,
    required this.images,
    this.placeholderIcon = Icons.image_outlined,
  });

  @override
  State<ImageSliverAppBar> createState() => _ImageSliverAppBarState();
}

class _ImageSliverAppBarState extends State<ImageSliverAppBar> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12, top: 8),
        child: _CircleIconButton(
          icon: Icons.arrow_back,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: _buildImageCarousel(),
      ),
    );
  }

  Widget _buildImageCarousel() {
    if (widget.images.isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        child: Center(
          child: Icon(widget.placeholderIcon, size: 72, color: Colors.grey),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.images.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            return Image.network(
              widget.images[index],
              fit: BoxFit.cover,
              // 🚀 จำกัดขนาด decode ไม่ให้เกินความละเอียดที่จอแสดงจริงต้องการ
              cacheWidth: 1080,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 56, color: Colors.grey),
                ),
              ),
            );
          },
        ),

        // 🚀 ไล่สีมืดด้านล่างเบาๆ ให้ dot indicator อ่านง่ายบนรูปทุกแบบ
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 72,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (widget.images.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: _PageIndicatorDots(
              count: widget.images.length,
              currentIndex: _currentIndex,
            ),
          ),
      ],
    );
  }
}

class _PageIndicatorDots extends StatelessWidget {
  final int count;
  final int currentIndex;

  const _PageIndicatorDots({required this.count, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isActive ? 1 : 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
