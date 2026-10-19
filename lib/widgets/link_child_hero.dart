import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/family_models.dart';
import '../services/nfc_reader.dart';
import 'bracelet_link_panel.dart';
import 'qr_link_panel.dart';

/// Qual leitor o cartão está mostrando.
enum _Mode { qr, nfc }

/// Cartão de destaque da home para quem ainda não vinculou nenhuma criança: o QR Code é o
/// primeiro passo de todo responsável, então ele aparece grande em vez de escondido.
///
/// Ao tocar em "Escanear QR Code" o próprio cartão se transforma no leitor (pede a
/// permissão da câmera, mostra a câmera e confirma o vínculo), sem abrir outra tela.
class LinkChildHero extends StatefulWidget {
  /// Chamado assim que a criança é vinculada.
  final ValueChanged<Child>? onLinked;

  /// Substitui o painel do leitor (para testar sem câmera).
  final Widget Function(BuildContext context, VoidCallback close)? panelBuilder;

  /// Leitor de NFC usado pelo botão "Escanear com NFC" (para testar sem aparelho).
  final NfcReader? nfcReader;

  const LinkChildHero({this.onLinked, this.panelBuilder, this.nfcReader, super.key});

  @override
  State<LinkChildHero> createState() => _LinkChildHeroState();
}

class _LinkChildHeroState extends State<LinkChildHero> {
  bool _scanning = false;
  _Mode _mode = _Mode.qr;

  // O botão de NFC só aparece se o celular tem NFC.
  bool _nfcOffered = false;

  @override
  void initState() {
    super.initState();
    _checkNfc();
  }

  Future<void> _checkNfc() async {
    final support = await (widget.nfcReader ?? const PlatformNfcReader()).support();
    if (!mounted) return;
    setState(() => _nfcOffered = support != NfcSupport.unsupported);
  }

  void _open(_Mode mode) => setState(() {
        _mode = mode;
        _scanning = true;
      });

  void _switchTo(_Mode mode) => setState(() => _mode = mode);

  void _close() => setState(() => _scanning = false);

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
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _scanning ? _buildScanner(context) : _buildIntro(),
      ),
    );
  }

  Widget _buildScanner(BuildContext context) {
    if (_mode == _Mode.nfc) {
      return BraceletLinkPanel(
        framed: false,
        // Aberto direto pelo botão do cartão: não há câmera fechando, então já lê.
        autoStart: true,
        reader: widget.nfcReader,
        onLinked: widget.onLinked,
        onClose: _close,
        onUseQr: () => _switchTo(_Mode.qr),
      );
    }
    final builder = widget.panelBuilder;
    if (builder != null) return builder(context, _close);
    return QrLinkPanel(framed: false, onLinked: widget.onLinked, onClose: _close);
  }

  Widget _buildIntro() {
    return Column(
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
            onPressed: () => _open(_Mode.qr),
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
        if (_nfcOffered) ...[
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: Divider(color: PulynColors.textMuted)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'ou escaneie com NFC',
                  style: TextStyle(color: PulynColors.textSecondary, fontSize: 13),
                ),
              ),
              Expanded(child: Divider(color: PulynColors.textMuted)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _open(_Mode.nfc),
              icon: const Icon(Icons.nfc_rounded),
              label: const Text(
                'Escanear com NFC',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: PulynColors.primary,
                side: const BorderSide(color: PulynColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
