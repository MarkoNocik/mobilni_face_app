import 'package:flutter/material.dart';

enum PhotoFilterType { none, warm, yellow, vintage, bright, vivid, bw, fade }

enum FilterType {
  none,
  dog,
  cat,
  crown,
  bunny,
  flowerCrown,
  alien,
  sparkle,
  rainbow,
  fire,
  devil,
}

class FaceFilter {
  final FilterType type;
  final String name;
  final IconData icon;
  final Color color;

  const FaceFilter({
    required this.type,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class FilterModel extends ChangeNotifier {
  FilterType _selectedFilter = FilterType.none;
  PhotoFilterType _photoFilter = PhotoFilterType.none;

  FilterType get selectedFilter => _selectedFilter;
  PhotoFilterType get photoFilter => _photoFilter;

  void setFilter(FilterType filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void setPhotoFilter(PhotoFilterType filter) {
    _photoFilter = filter;
    notifyListeners();
  }

  static ColorFilter? colorFilterFor(PhotoFilterType type) {
    switch (type) {
      case PhotoFilterType.none:
        return null;
      case PhotoFilterType.warm:
        return const ColorFilter.matrix([
          1.2, 0,    0,    0, 10,
          0,   1.0,  0,    0,  5,
          0,   0,    0.85, 0, -10,
          0,   0,    0,    1,  0,
        ]);
      case PhotoFilterType.yellow:
        return const ColorFilter.matrix([
          1.2, 0,   0,   0, 15,
          0,   1.1, 0,   0, 10,
          0,   0,   0.6, 0, -20,
          0,   0,   0,   1,  0,
        ]);
      case PhotoFilterType.vintage:
        return const ColorFilter.matrix([
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0,     0,     0,     1, 0,
        ]);
      case PhotoFilterType.bright:
        return const ColorFilter.matrix([
          1.2, 0,   0,   0, 20,
          0,   1.2, 0,   0, 20,
          0,   0,   1.2, 0, 20,
          0,   0,   0,   1,  0,
        ]);
      case PhotoFilterType.vivid:
        return const ColorFilter.matrix([
          1.438, -0.122, -0.016, 0, -0.03,
          -0.062, 1.378, -0.016, 0,  0.05,
          -0.062, -0.122, 1.483, 0, -0.02,
          0,      0,      0,     1,  0,
        ]);
      case PhotoFilterType.bw:
        return const ColorFilter.matrix([
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0,     0,     0,     1, 0,
        ]);
      case PhotoFilterType.fade:
        return const ColorFilter.matrix([
          0.8, 0,   0,   0, 40,
          0,   0.8, 0,   0, 40,
          0,   0,   0.8, 0, 40,
          0,   0,   0,   1,  0,
        ]);
    }
  }

  static const List<FaceFilter> filters = [
    FaceFilter(type: FilterType.none,        name: 'None',    icon: Icons.face_outlined,         color: Colors.grey),
    FaceFilter(type: FilterType.dog,         name: 'Dog',     icon: Icons.pets,                  color: Color(0xFF8B6914)),
    FaceFilter(type: FilterType.cat,         name: 'Cat',     icon: Icons.cruelty_free,          color: Color(0xFFFF6B00)),
    FaceFilter(type: FilterType.crown,       name: 'Royal',   icon: Icons.star,                  color: Color(0xFFFFD700)),
    FaceFilter(type: FilterType.bunny,       name: 'Bunny',   icon: Icons.spa,                   color: Color(0xFFFF69B4)),
    FaceFilter(type: FilterType.flowerCrown, name: 'Flowers', icon: Icons.local_florist,         color: Color(0xFF4CAF50)),
    FaceFilter(type: FilterType.alien,       name: 'Alien',   icon: Icons.radar,                 color: Color(0xFF76FF03)),
    FaceFilter(type: FilterType.sparkle,     name: 'Sparkle', icon: Icons.auto_awesome,          color: Color(0xFFFFD700)),
    FaceFilter(type: FilterType.rainbow,     name: 'Rainbow', icon: Icons.colorize,              color: Color(0xFFFF4444)),
    FaceFilter(type: FilterType.fire,        name: 'Fire',    icon: Icons.local_fire_department, color: Color(0xFFFF4500)),
    FaceFilter(type: FilterType.devil,       name: 'Devil',   icon: Icons.electric_bolt,         color: Color(0xFFCC0000)),
  ];
}
