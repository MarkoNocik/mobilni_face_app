import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/filter_model.dart';

class FilterCarousel extends StatefulWidget {
  const FilterCarousel({super.key});

  @override
  State<FilterCarousel> createState() => _FilterCarouselState();
}

class _FilterCarouselState extends State<FilterCarousel> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  static const _photoEntries = [
    (PhotoFilterType.warm,    'Warm',    Color(0xFFFF7043), Icons.wb_sunny_outlined),
    (PhotoFilterType.yellow,  'Yellow',  Color(0xFFFFD600), Icons.brightness_5),
    (PhotoFilterType.vintage, 'Vintage', Color(0xFFBCAAA4), Icons.camera_outlined),
    (PhotoFilterType.bright,  'Bright',  Color(0xFF90CAF9), Icons.light_mode_outlined),
    (PhotoFilterType.vivid,   'Vivid',   Color(0xFFAB47BC), Icons.palette_outlined),
    (PhotoFilterType.bw,      'B&W',     Color(0xFF616161), Icons.invert_colors),
    (PhotoFilterType.fade,    'Fade',    Color(0xFFB0BEC5), Icons.blur_on),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<FilterModel>(
      builder: (context, filterModel, _) {
        final faceFilters = FilterModel.filters;
        // total items: face filters + divider + photo filters
        final totalItems = faceFilters.length + 1 + _photoEntries.length;

        return Container(
          height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: totalItems,
            itemBuilder: (context, index) {
              // Divider between face and photo sections
              if (index == faceFilters.length) {
                return Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  color: Colors.white24,
                );
              }

              if (index < faceFilters.length) {
                final filter = faceFilters[index];
                final isSelected = filterModel.selectedFilter == filter.type;
                return _Tile(
                  icon: filter.icon,
                  name: filter.name,
                  color: filter.color,
                  isSelected: isSelected,
                  onTap: () => filterModel.setFilter(filter.type),
                );
              }

              // Photo filter item
              final pi = index - faceFilters.length - 1;
              final (type, name, color, icon) = _photoEntries[pi];
              final isSelected = filterModel.photoFilter == type;
              return _Tile(
                icon: icon,
                name: name,
                color: color,
                isSelected: isSelected,
                onTap: () => filterModel.setPhotoFilter(
                  isSelected ? PhotoFilterType.none : type,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String name;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.name,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: Colors.white, width: 2.5)
              : Border.all(color: Colors.white24, width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
