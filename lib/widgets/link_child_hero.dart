import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Cartão de destaque da home para quem ainda não vinculou nenhuma criança: o QR Code
/// é o primeiro passo de todo responsável, então ele aparece grande em vez de escondido.
class LinkChildHero extends StatelessWidget {
  final VoidCallback onScan;

  const LinkChildHero({required this.onScan, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PulynColors.primary.withValues(alpha: 0.30),
            PulynColors.darkCard,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PulynColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
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
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, size: 36, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Vincule seu filho',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Peça o QR Code na recepção do buffet e escaneie para acompanhar a festa em tempo real.',
            textAlign: TextAlign.center,
            style: TextStyle(color: PulynColors.textSecondary, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text(
                'Escanear QR Code',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
