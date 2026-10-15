import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/family_models.dart';
import '../services/api_service.dart';
import '../services/nfc_reader.dart';
import '../utils/logger.dart';
import 'qr_link_panel.dart' show childFromLinkedChild;

typedef LinkBraceletRequest = Future<Map<String, dynamic>> Function(String uid);

enum _Step { checking, unsupported, disabled, ready, reading, processing, linked, error }

/// Painel para vincular uma criança ENCOSTANDO A PULSEIRA NFC no celular — alternativa ao
/// [QrLinkPanel]. Funciona dentro da tela onde é colocado, sem diálogos.
///
/// No Android a leitura começa sozinha ao abrir; no iPhone o sistema abre a própria janela
/// de leitura. O vínculo já nasce aprovado: a recepção não precisa aprovar.
class BraceletLinkPanel extends StatefulWidget {
  /// Chamado assim que a criança é vinculada.
  final ValueChanged<Child>? onLinked;

  /// Chamado quando a pessoa fecha o painel.
  final VoidCallback? onClose;

  /// Volta para a leitura de QR Code (aparece como botão quando informado).
  final VoidCallback? onUseQr;

  /// `true` desenha o painel como um cartão; `false` deixa sem moldura.
  final bool framed;

  // Pontos de substituição, para testar sem NFC e sem rede.
  final NfcReader? reader;
  final LinkBraceletRequest? linkChild;

  const BraceletLinkPanel({
    this.onLinked,
    this.onClose,
    this.onUseQr,
    this.framed = true,
    this.reader,
    this.linkChild,
    super.key,
  });

  @override
  State<BraceletLinkPanel> createState() => _BraceletLinkPanelState();
}

class _BraceletLinkPanelState extends State<BraceletLinkPanel> {
  _Step _step = _Step.checking;
  Child? _linkedChild;
  String _errorMessage = '';

  NfcReader get _reader => widget.reader ?? const PlatformNfcReader();

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    // Não deixa o leitor do sistema aberto depois de sair da tela.
    _reader.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (!mounted) return;
    setState(() => _step = _Step.checking);

    final support = await _reader.support();
    if (!mounted) return;

    switch (support) {
      case NfcSupport.unsupported:
        setState(() => _step = _Step.unsupported);
      case NfcSupport.disabled:
        setState(() => _step = _Step.disabled);
      case NfcSupport.enabled:
        setState(() => _step = _Step.ready);
        _startReading();
    }
  }

  Future<void> _startReading() async {
    if (!mounted || _step == _Step.reading || _step == _Step.processing) return;
    log.i('[BRACELET] 🔍 Iniciando leitura de pulseira...');
    setState(() => _step = _Step.reading);

    String uid;
    try {
      log.i('[BRACELET] ⏳ Aguardando leitura do NFC...');
      uid = await _reader.readBraceletUid();
      log.i('[BRACELET] ✅ UID lido: $uid');
    } on NfcReadException catch (e) {
      log.w('[BRACELET] ⚠️ NFC Exception: ${e.mensagem} (cancelled: ${e.cancelled})');
      if (!mounted) return;
      // A pessoa fechou a janela de leitura: volta ao botão, sem mostrar erro.
      setState(() {
        if (e.cancelled) {
          log.i('[BRACELET] 📴 Leitura cancelada pelo usuário');
          _step = _Step.ready;
        } else {
          log.e('[BRACELET] ❌ Erro NFC: ${e.mensagem}');
          _errorMessage = e.mensagem;
          _step = _Step.error;
        }
      });
      return;
    } catch (e) {
      log.e('[BRACELET] ❌ Erro inesperado ao ler: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e'.toString();
        _step = _Step.error;
      });
      return;
    }
    if (!mounted) return;

    log.i('[BRACELET] 🔗 Processando vinculação com UID: $uid');
    setState(() => _step = _Step.processing);
    try {
      log.i('[BRACELET] 📡 Chamando API...');
      final result = await (widget.linkChild ?? _defaultLinkChild)(uid);
      log.i('[BRACELET] 📦 Resposta da API: $result');
      final data = result['linkedChild'];
      if (result['success'] != true || data is! Map) {
        throw Exception('${result['mensagem'] ?? result['error'] ?? 'Dados da criança não encontrados'}');
      }
      final child = childFromLinkedChild(Map<String, dynamic>.from(data));
      if (!mounted) return;
      log.i('[BRACELET] ✅ Criança vinculada: ${child.nome}');
      setState(() {
        _linkedChild = child;
        _step = _Step.linked;
      });
      widget.onLinked?.call(child);
    } catch (e) {
      log.e('[BRACELET] ❌ Erro ao vincular: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e'.replaceFirst('Exception: ', '');
        _step = _Step.error;
      });
    }
  }

  static Future<Map<String, dynamic>> _defaultLinkChild(String uid) async {
    final api = ApiService();
    await api.init();
    return api.linkChildWithBracelet(uid);
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 14),
        _buildBody(),
      ],
    );

    if (!widget.framed) return content;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PulynColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PulynColors.primary.withValues(alpha: 0.4)),
      ),
      child: content,
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.nfc_rounded, color: PulynColors.primary),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Vincular com a pulseira',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        if (widget.onClose != null)
          IconButton(
            tooltip: 'Fechar',
            icon: const Icon(Icons.close_rounded),
            color: PulynColors.textMuted,
            visualDensity: VisualDensity.compact,
            onPressed: widget.onClose,
          ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _Step.checking:
        return _statusBox(const CircularProgressIndicator(), 'Verificando o NFC...');
      case _Step.unsupported:
        return _buildMessage(
          icon: Icons.phonelink_erase_rounded,
          color: PulynColors.warning,
          title: 'Este celular não lê pulseiras',
          texto: 'Seu aparelho não tem NFC. Use o QR Code que a recepção entregou.',
          showQrButton: true,
        );
      case _Step.disabled:
        return _buildMessage(
          icon: Icons.nfc_rounded,
          color: PulynColors.warning,
          title: 'O NFC está desligado',
          texto: 'Ative o NFC nas configurações do celular e toque em "Tentar de novo".',
          retryLabel: 'Tentar de novo',
          onRetry: _prepare,
          showQrButton: true,
        );
      case _Step.ready:
        return _buildMessage(
          icon: Icons.nfc_rounded,
          color: PulynColors.primary,
          title: 'Encoste a pulseira',
          texto: 'Toque em "Ler pulseira" e encoste a pulseira do seu filho atrás do celular.',
          retryLabel: 'Ler pulseira',
          onRetry: _startReading,
          showQrButton: true,
        );
      case _Step.reading:
        return _statusBox(
          const Icon(Icons.nfc_rounded, size: 56, color: PulynColors.primary),
          'Encoste a pulseira atrás do celular...',
        );
      case _Step.processing:
        return _statusBox(const CircularProgressIndicator(), 'Vinculando...');
      case _Step.linked:
        return _buildLinked();
      case _Step.error:
        return _buildMessage(
          icon: Icons.error_outline_rounded,
          color: PulynColors.danger,
          title: _errorMessage.isEmpty ? 'Não foi possível vincular a criança.' : _errorMessage,
          retryLabel: 'Tentar de novo',
          onRetry: _startReading,
          showQrButton: true,
        );
    }
  }

  Widget _statusBox(Widget indicator, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(height: 16),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: PulynColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required Color color,
    required String title,
    String? texto,
    String? retryLabel,
    VoidCallback? onRetry,
    bool showQrButton = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 44, color: color),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, height: 1.3),
        ),
        if (texto != null) ...[
          const SizedBox(height: 6),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: PulynColors.textSecondary, height: 1.4),
          ),
        ],
        const SizedBox(height: 16),
        if (retryLabel != null && onRetry != null)
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.nfc_rounded),
            label: Text(retryLabel),
          ),
        if (showQrButton && widget.onUseQr != null)
          TextButton.icon(
            onPressed: widget.onUseQr,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Usar o QR Code'),
          ),
        if (widget.onClose != null)
          TextButton(onPressed: widget.onClose, child: const Text('Cancelar')),
      ],
    );
  }

  Widget _buildLinked() {
    final child = _linkedChild!;
    final nome = child.apelido.isNotEmpty ? child.apelido : child.nome;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PulynColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 36, color: PulynColors.success),
        ),
        const SizedBox(height: 12),
        const Text(
          'Criança vinculada!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          [
            nome,
            if (child.idade > 0) '${child.idade} anos',
            if (child.teamName.isNotEmpty) child.teamName,
          ].join(' · '),
          textAlign: TextAlign.center,
          style: const TextStyle(color: PulynColors.textSecondary),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _startReading,
          icon: const Icon(Icons.nfc_rounded),
          label: const Text('Vincular outra criança'),
        ),
        if (widget.onClose != null)
          TextButton(onPressed: widget.onClose, child: const Text('Concluir')),
      ],
    );
  }
}
