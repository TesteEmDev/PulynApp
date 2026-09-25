import 'package:flutter/material.dart';
import '../config/theme.dart';

/// 🎨 COMPONENTES REUTILIZÁVEIS - Pulyn Design System

// ============================================================================
// 0️⃣ LAZY IMAGE COMPONENT - Otimização de Performance
// ============================================================================

/// Imagem com lazy loading e cache
class LazyImage extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const LazyImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: (width * MediaQuery.of(context).devicePixelRatio).toInt(),
        cacheHeight: (height * MediaQuery.of(context).devicePixelRatio).toInt(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            color: PulynColors.darkSurface,
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: PulynColors.darkSurface,
            child: const Center(
              child: Icon(Icons.broken_image, color: PulynColors.textMuted),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 1️⃣ CARDS & CONTAINERS
// ============================================================================

/// Card padrão com gradient e sombra elegante
class PulynCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final bool isHighlight;
  final double elevation;

  const PulynCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.isHighlight = false,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isHighlight
                ? [
                    PulynColors.darkSurface,
                    PulynColors.darkSurface.withValues(alpha: 0.7),
                  ]
                : [
                    PulynColors.darkCard,
                    PulynColors.darkCard.withValues(alpha: 0.85),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor ?? (isHighlight ? PulynColors.primary : PulynColors.darkBorder),
            width: isHighlight ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isHighlight ? PulynColors.primary : Colors.black).withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Card com avatar circular (para crianças/usuários)
class AvatarCard extends StatelessWidget {
  final String initials;
  final String name;
  final String subtitle;
  final Color avatarColor;
  final int? badge;
  final VoidCallback? onTap;

  const AvatarCard({
    super.key,
    required this.initials,
    required this.name,
    required this.subtitle,
    required this.avatarColor,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PulynCard(
      onTap: onTap,
      child: Row(
        children: [
          // Avatar com gradient
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [avatarColor, avatarColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: avatarColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Badge com contagem
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: PulynColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: PulynColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: PulynColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: PulynColors.textMuted),
        ],
      ),
    );
  }
}

// ============================================================================
// 2️⃣ BUTTONS
// ============================================================================

/// Botão primário com loading state
class PulynButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isSecondary;
  final IconData? icon;
  final Color? backgroundColor;

  const PulynButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isSecondary ? PulynColors.primary : Colors.white,
                ),
              ),
            )
          : Icon(icon ?? Icons.check),
      label: Text(isLoading ? 'Carregando...' : label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ??
            (isSecondary ? Colors.transparent : PulynColors.primary),
        foregroundColor: isSecondary ? PulynColors.primary : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSecondary
              ? const BorderSide(color: PulynColors.primary, width: 2)
              : BorderSide.none,
        ),
        elevation: isSecondary ? 0 : 4,
      ),
    );
  }
}

/// Botão ícone compacto
class PulynIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;

  const PulynIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? PulynColors.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (backgroundColor ?? PulynColors.primary).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            icon,
            color: iconColor ?? Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 3️⃣ INPUTS & FORMS
// ============================================================================

/// Input field customizado
class PulynTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final int maxLines;

  const PulynTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.validator,
    this.maxLines = 1,
  });

  @override
  State<PulynTextField> createState() => _PulynTextFieldState();
}

class _PulynTextFieldState extends State<PulynTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: PulynColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: _obscureText,
          maxLines: _obscureText ? 1 : widget.maxLines,
          validator: widget.validator,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: PulynColors.textMuted),
            prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  )
                : null,
            filled: true,
            fillColor: PulynColors.darkSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PulynColors.darkBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PulynColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: PulynColors.danger, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: const TextStyle(color: PulynColors.textPrimary),
        ),
      ],
    );
  }
}

// ============================================================================
// 4️⃣ BADGES & STATUS INDICATORS
// ============================================================================

/// Badge para scores/pontos
class ScoreBadge extends StatelessWidget {
  final int score;
  final String? label;
  final Color? backgroundColor;
  final bool isLarge;

  const ScoreBadge({
    super.key,
    required this.score,
    this.label,
    this.backgroundColor,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 16 : 12,
        vertical: isLarge ? 10 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (backgroundColor ?? PulynColors.accent).withValues(alpha: 0.3),
            (backgroundColor ?? PulynColors.accent).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (backgroundColor ?? PulynColors.accent).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            style: TextStyle(
              fontSize: isLarge ? 20 : 16,
              fontWeight: FontWeight.bold,
              color: backgroundColor ?? PulynColors.accent,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 2),
            Text(
              label!,
              style: const TextStyle(
                fontSize: 11,
                color: PulynColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Status indicator com cor
class StatusIndicator extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusIndicator({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5️⃣ STATES (Empty, Loading, Error)
// ============================================================================

/// Estado vazio
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: PulynColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: PulynColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(color: PulynColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado de erro
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return PulynCard(
      borderColor: PulynColors.danger,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: PulynColors.danger, size: 48),
          const SizedBox(height: 12),
          Text(
            'Algo deu errado',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: PulynColors.danger,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: PulynColors.textMuted),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PulynButton(
                label: 'Tentar Novamente',
                onPressed: onRetry!,
                icon: Icons.refresh,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Loading skeleton
class SkeletonLoader extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: PulynColors.darkSurface,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// ============================================================================
// 6️⃣ SECTION HEADERS
// ============================================================================

/// Header de seção com ação opcional
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: PulynColors.textPrimary,
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon ?? Icons.arrow_forward, size: 18),
            label: Text(actionLabel!),
            style: TextButton.styleFrom(
              foregroundColor: PulynColors.primary,
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// 7️⃣ SPECIALIZED COMPONENTS - Ranking & Notifications
// ============================================================================

/// Ranking card para posição com medal
class RankingCard extends StatelessWidget {
  final int position;
  final String name;
  final int score;
  final Color teamColor;
  final String medal;
  final bool isTop;
  final VoidCallback? onTap;

  const RankingCard({
    super.key,
    required this.position,
    required this.name,
    required this.score,
    required this.teamColor,
    required this.medal,
    required this.isTop,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: PulynCard(
        isHighlight: isTop,
        borderColor: isTop ? PulynColors.primary : null,
        child: Row(
          children: [
            // Medal Avatar
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [teamColor, teamColor.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(27),
                boxShadow: [
                  BoxShadow(
                    color: teamColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                  )
                ],
              ),
              child: Center(
                child: Text(
                  medal,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: PulynColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Posição #$position',
                    style: const TextStyle(
                      fontSize: 12,
                      color: PulynColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            ScoreBadge(score: score, isLarge: true),
          ],
        ),
      ),
    );
  }
}

/// Notification card com ações
class NotificationCard extends StatelessWidget {
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsRead;
  final VoidCallback? onDelete;

  const NotificationCard({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    this.onTap,
    this.onMarkAsRead,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isRead ? null : onTap,
      child: PulynCard(
        isHighlight: !isRead,
        borderColor: isRead ? null : PulynColors.primary,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getNotificationColor(type).withValues(alpha: 0.3),
                    _getNotificationColor(type).withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  _getNotificationIcon(type),
                  color: _getNotificationColor(type),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: PulynColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: PulynColors.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isRead) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PulynColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Novo',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: PulynColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Actions menu
            PopupMenuButton(
              itemBuilder: (context) => [
                if (!isRead && onMarkAsRead != null)
                  PopupMenuItem(
                    onTap: onMarkAsRead,
                    child: const Row(
                      children: [
                        Icon(Icons.check, size: 18),
                        SizedBox(width: 12),
                        Text('Marcar como lida'),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    onTap: onDelete,
                    child: const Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 12),
                        Text(
                          'Deletar',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
              ],
              child: const Icon(
                Icons.more_vert,
                color: PulynColors.textMuted,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'score':
        return Icons.star;
      case 'achievement':
        return Icons.emoji_events;
      case 'ranking':
        return Icons.leaderboard;
      case 'event':
        return Icons.event_note;
      case 'team':
        return Icons.group;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'score':
        return PulynColors.primary;
      case 'achievement':
        return const Color(0xFFFFD700); // Gold
      case 'ranking':
        return const Color(0xFF4285F4); // Blue
      case 'event':
        return const Color(0xFF34A853); // Green
      case 'team':
        return const Color(0xFFEA4335); // Red
      default:
        return PulynColors.textMuted;
    }
  }
}

/// Stat card para exibição de estatísticas
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PulynCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: PulynColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: PulynColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
