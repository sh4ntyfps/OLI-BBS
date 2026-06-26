import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Un widget de tarjeta personalizado diseñado para SeñaLink AI,
/// optimizado para accesibilidad (Semantics) y legibilidad.
class SenaLinkCard extends StatelessWidget {
  final String title;
  final String description;
  final dynamic icon; // Acepta IconData o una ruta String para SVG
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? textColor;

  const SenaLinkCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // CORRECCIÓN: Usamos el color de tarjeta del tema si no se especifica uno,
    // permitiendo que se vea bien tanto en modo claro como oscuro.
    final bgColor = backgroundColor ?? (isDark ? theme.cardTheme.color : theme.colorScheme.primary);
    
    // El color del contenido (iconos/texto) se adapta al fondo
    final contentColor = textColor ?? (backgroundColor == null && !isDark ? Colors.white : theme.textTheme.bodyLarge?.color);

    return Semantics(
      button: true,
      label: 'Opción: $title. $description',
      hint: 'Presiona para entrar',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(28),
          border: isDark ? Border.all(color: theme.dividerColor.withAlpha(20), width: 1) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 80 : 20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  _buildIcon(contentColor ?? Colors.white),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: contentColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: contentColor?.withAlpha(200),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: contentColor?.withAlpha(150),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    if (icon is IconData) {
      return Icon(icon as IconData, size: 36, color: color);
    } else if (icon is String) {
      return SvgPicture.asset(
        icon,
        width: 36,
        height: 36,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        placeholderBuilder: (context) => const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return const SizedBox(width: 36);
  }
}
