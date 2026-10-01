import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../config/theme.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final int? userId;
  final String name;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;

  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.userId,
    this.radius = 16,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1);
    final effectiveTextColor = textColor ?? AppTheme.primaryColor;
    final effectiveFontSize = fontSize ?? (radius * 0.85);

    final cleanName = name.trim();
    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : '?';

    final fallbackWidget = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: effectiveBg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: effectiveFontSize,
          color: effectiveTextColor,
        ),
      ),
    );

    // Determinar la mejor URL de la imagen
    String? resolvedUrl;
    final cleanPhoto = photoUrl?.trim();
    if (cleanPhoto != null && cleanPhoto.isNotEmpty) {
      if (cleanPhoto.startsWith('http')) {
        resolvedUrl = cleanPhoto;
      } else if (cleanPhoto.startsWith('/')) {
        resolvedUrl = '${ApiConfig.baseUrl.replaceAll('/api', '')}$cleanPhoto';
      }
    } else if (userId != null && userId! > 0) {
      resolvedUrl = '${ApiConfig.baseUrl}/auth/avatar/$userId';
    }

    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return fallbackWidget;
    }

    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: effectiveBg,
          shape: BoxShape.circle,
        ),
        child: Image.network(
          resolvedUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Si falló la URL directa y tenemos userId, usar el proxy local con CORS
            if (userId != null && userId! > 0 && !resolvedUrl!.contains('/auth/avatar/')) {
              return Image.network(
                '${ApiConfig.baseUrl}/auth/avatar/$userId',
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallbackWidget,
              );
            }
            return fallbackWidget;
          },
        ),
      ),
    );
  }
}
