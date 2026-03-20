import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/filter_model.dart';

class PhotoFilterBar extends StatelessWidget {
  const PhotoFilterBar({super.key});

  static const _filters = [
    (PhotoFilterType.none,    'None',    Color(0xFF9E9E9E)),
    (PhotoFilterType.warm,    'Warm',    Color(0xFFFF7043)),
    (PhotoFilterType.yellow,  'Yellow',  Color(0xFFFFD600)),
    (PhotoFilterType.vintage, 'Vintage', Color(0xFFBCAAA4)),
    (PhotoFilterType.bright,  'Bright',  Color(0xFFE3F2FD)),
    (PhotoFilterType.vivid,   'Vivid',   Color(0xFFAB47BC)),
    (PhotoFilterType.bw,      'B&W',     Color(0xFF616161)),
    (PhotoFilterType.fade,    'Fade',    Color(0xFFB0BEC5)),
  ];

  @override
  Widget build(BuildContext context) {
    final model = context.watch<FilterModel>();
    final selected = model.photoFilter;

    return Container(
      height: 80,
      color: Colors.black87,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (type, name, color) = _filters[i];
          final isSelected = selected == type;
          return GestureDetector(
            onTap: () => context.read<FilterModel>().setPhotoFilter(type),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : Border.all(color: Colors.white24, width: 1),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
