import 'package:flutter/material.dart';

/// Generic icons only: no third-party logos are bundled (trademarks). The
/// tile colour and first letter identify the site.
const _iconForKey = <String, IconData>{
  'youtube': Icons.smart_display_outlined,
  'twitch': Icons.live_tv_outlined,
  'tiktok': Icons.music_note_outlined,
  'rumble': Icons.play_circle_outline,
  'facebook': Icons.groups_outlined,
  'instagram': Icons.photo_camera_outlined,
  'x': Icons.alternate_email,
  'reddit': Icons.forum_outlined,
  'vimeo': Icons.movie_outlined,
  'dailymotion': Icons.ondemand_video_outlined,
  'news': Icons.newspaper_outlined,
};

Color? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

class ShortcutIcon extends StatelessWidget {
  const ShortcutIcon({
    super.key,
    required this.title,
    this.iconKey,
    this.color,
    this.size = 56,
  });

  final String title;
  final String? iconKey;
  final String? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = parseHexColor(color) ?? scheme.primaryContainer;
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final icon = _iconForKey[iconKey];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: fg, size: size * 0.48)
          : Text(
              title.isEmpty ? '?' : title.characters.first.toUpperCase(),
              style: TextStyle(
                  color: fg, fontSize: size * 0.4, fontWeight: FontWeight.w600),
            ),
    );
  }
}
