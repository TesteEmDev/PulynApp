import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

/// Item da [ModernBottomNav].
class ModernNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const ModernNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Ação em destaque no meio da barra (um botão redondo que faz algo, em vez de trocar de
/// aba). Usada para o QR Code de vincular criança enquanto ainda não há nenhuma vinculada.
class ModernNavAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ModernNavAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// Barra de navegação inferior flutuante: cantos arredondados, sombra suave e
/// uma "pílula" colorida que mostra o nome só do item selecionado.
class ModernBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ModernNavItem> items;

  /// Botão de ação opcional. Fica na posição [actionSlot] da barra e não conta como aba:
  /// [currentIndex] e [onTap] continuam se referindo só aos [items].
  final ModernNavAction? action;

  /// Em qual posição da barra o botão de ação entra (0 = antes do primeiro item).
  final int actionSlot;

  const ModernBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.action,
    this.actionSlot = 1,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final actionButton = action;
    final slots = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (actionButton != null && i == actionSlot) {
        slots.add(Expanded(child: _ActionButton(action: actionButton)));
      }
      slots.add(
        Expanded(
          child: _NavButton(
            item: items[i],
            selected: i == currentIndex,
            onTap: () {
              if (i == currentIndex) return;
              HapticFeedback.selectionClick();
              onTap(i);
            },
          ),
        ),
      );
    }
    if (actionButton != null && actionSlot >= items.length) {
      slots.add(Expanded(child: _ActionButton(action: actionButton)));
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: PulynColors.darkCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: PulynColors.darkBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(children: slots),
        ),
      ),
    );
  }
}

/// Botão redondo de ação (QR Code).
class _ActionButton extends StatelessWidget {
  final ModernNavAction action;

  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.mediumImpact();
          action.onTap();
        },
        child: Center(
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [PulynColors.primary, PulynColors.primaryLight],
              ),
              boxShadow: [
                BoxShadow(
                  color: PulynColors.primary.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(action.icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final ModernNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  static const _duration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      // O Text do item selecionado repetiria o rótulo: o leitor de tela lia duas vezes.
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: _duration,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? PulynColors.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            // FittedBox: em telas estreitas o conjunto encolhe em vez de estourar.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: _duration,
                    child: Icon(
                      selected ? item.activeIcon : item.icon,
                      key: ValueKey(selected),
                      size: 24,
                      color: selected
                          ? PulynColors.primary
                          : PulynColors.textMuted,
                    ),
                  ),
                  AnimatedSize(
                    duration: _duration,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerLeft,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: PulynColors.primary,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
