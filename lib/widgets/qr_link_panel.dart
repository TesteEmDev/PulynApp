import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/theme.dart';
import '../models/family_models.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

typedef PermissionCheck = Future<PermissionStatus> Function();
typedef LinkChildRequest = Future<Map<String, dynamic>> Function(String qrCode);
typedef CameraViewBuilder = Widget Function(BuildContext context, ValueChanged<String> onCode);

/// Converte a resposta do backend (`linkedChild`) no modelo [Child].
Child childFromLinkedChild(Map<String, dynamic> data) {
  return Child(
    id: '${data['id'] ?? ''}',
    name: '${data['name'] ?? ''}',
    nickname: '${data['nickname'] ?? ''}',
    age: data['age'] is num ? (data['age'] as num).toInt() : 0,
    teamName: '${data['evento'] ?? 'Sem time'}',
    profileImage: null,
    currentScore: 0,
    totalScore: 0,
    teamId: '',
    teamColor: '#cccccc',
    rank: 0,
    achievements: const [],
  );
}

enum _Step { checking, denied, scanning, processing, linked, error }

/// Painel para vincular uma criança lendo o QR Code, que funciona DENTRO da tela onde é
/// colocado (cartão da home, janela de baixo...). Ao aparecer ele já pede a permissão da
/// câmera; com a permissão, mostra a câmera; ao ler, valida e confirma — tudo no mesmo
/// lugar, sem levar para outra tela e sem diálogos.
class QrLinkPanel extends StatefulWidget {
  /// Chamado assim que a criança é vinculada (a tela de fora pode atualizar a lista).
  final ValueChanged<Child>? onLinked;

  /// Chamado quando a pessoa fecha o painel (X, Cancelar ou Concluir).
  final VoidCallback? onClose;

  /// `true` desenha o painel como um cartão (uso dentro da home); `false` deixa sem moldura
  /// (uso dentro de uma janela que já tem fundo).
  final bool framed;

  // Pontos de substituição, para testar sem câmera, sem permissão real e sem rede.
  final PermissionCheck? permissionStatus;
  final PermissionCheck? requestPermission;
  final Future<bool> Function()? openSettings;
  final LinkChildRequest? linkChild;
  final CameraViewBuilder? cameraBuilder;

  const QrLinkPanel({
    this.onLinked,
    this.onClose,
    this.framed = true,
    this.permissionStatus,
    this.requestPermission,
    this.openSettings,
    this.linkChild,
    this.cameraBuilder,
    super.key,
  });

  @override
  State<QrLinkPanel> createState() => _QrLinkPanelState();
}

class _QrLinkPanelState extends State<QrLinkPanel> {
  _Step _step = _Step.checking;
  bool _canAskAgain = true;
  bool _handling = false;
  Child? _linkedChild;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // A pessoa acabou de tocar em "Escanear": já pede a câmera, sem outro botão no meio.
    _startCamera();
  }

  /// Confere/pede a permissão e, com ela, liga a câmera.
  Future<void> _startCamera() async {
    if (!mounted) return;
    setState(() {
      _step = _Step.checking;
      _handling = false;
    });

    try {
      var status = await (widget.permissionStatus ?? () => Permission.camera.status)();
      if (!status.isGranted) {
        status = await (widget.requestPermission ?? () => Permission.camera.request())();
      }
      if (!mounted) return;

      if (status.isGranted) {
        setState(() => _step = _Step.scanning);
      } else {
        log.w('[QR] Câmera sem permissão: $status');
        setState(() {
          _step = _Step.denied;
          _canAskAgain = !(status.isPermanentlyDenied || status.isRestricted);
        });
      }
    } catch (e) {
      log.e('[QR] Erro ao pedir permissão da câmera: $e');
      if (!mounted) return;
      setState(() {
        _step = _Step.error;
        _errorMessage = 'Não foi possível preparar a câmera.';
      });
    }
  }

  Future<void> _onCode(String code) async {
    if (_step != _Step.scanning || _handling) return;
    _handling = true;
    setState(() => _step = _Step.processing);

    try {
      final result = await (widget.linkChild ?? _defaultLinkChild)(code);
      final data = result['linkedChild'];
      if (result['success'] != true || data is! Map) {
        throw Exception('${result['message'] ?? result['error'] ?? 'Dados da criança não encontrados'}');
      }
      final child = childFromLinkedChild(Map<String, dynamic>.from(data));
      if (!mounted) return;
      setState(() {
        _linkedChild = child;
        _step = _Step.linked;
      });
      widget.onLinked?.call(child);
    } catch (e) {
      log.e('[QR] Erro ao vincular: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e'.replaceFirst('Exception: ', '');
        _step = _Step.error;
      });
    } finally {
      _handling = false;
    }
  }

  static Future<Map<String, dynamic>> _defaultLinkChild(String code) async {
    final api = ApiService();
    await api.init();
    return api.linkChildWithQRCode(code);
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
        const Icon(Icons.qr_code_scanner_rounded, color: PulynColors.primary),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Vincular criança',
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
        return _statusBox(
          const CircularProgressIndicator(),
          'Pedindo acesso à câmera...',
        );
      case _Step.denied:
        return _buildDenied();
      case _Step.scanning:
        return _buildScanner();
      case _Step.processing:
        return SizedBox(
          height: 240,
          child: _statusBox(const CircularProgressIndicator(), 'Validando QR Code...'),
        );
      case _Step.linked:
        return _buildLinked();
      case _Step.error:
        return _buildError();
    }
  }

  Widget _statusBox(Widget indicator, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          indicator,
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: PulynColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                (widget.cameraBuilder ?? _defaultCamera)(context, _onCode),
                // Moldura de mira e instrução, por cima da câmera (sem pegar toques)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Aponte a câmera para o QR Code',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.onClose != null)
          TextButton(onPressed: widget.onClose, child: const Text('Cancelar')),
      ],
    );
  }

  Widget _buildDenied() {
    final settings = widget.openSettings ?? openAppSettings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.no_photography_outlined, size: 44, color: PulynColors.warning),
        const SizedBox(height: 12),
        const Text(
          'Precisamos da câmera',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          _canAskAgain
              ? 'Para ler o QR Code, permita o acesso à câmera.'
              : 'O acesso à câmera está desativado. Ative nas configurações do app e volte aqui.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: PulynColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (_canAskAgain)
          ElevatedButton.icon(
            onPressed: _startCamera,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Permitir câmera'),
          )
        else ...[
          ElevatedButton.icon(
            onPressed: () => settings(),
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Abrir configurações'),
          ),
          TextButton(onPressed: _startCamera, child: const Text('Já permiti, tentar de novo')),
        ],
        if (widget.onClose != null)
          TextButton(onPressed: widget.onClose, child: const Text('Agora não')),
      ],
    );
  }

  Widget _buildLinked() {
    final child = _linkedChild!;
    final name = child.nickname.isNotEmpty ? child.nickname : child.name;
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
            name,
            if (child.age > 0) '${child.age} anos',
            if (child.teamName.isNotEmpty) child.teamName,
          ].join(' · '),
          textAlign: TextAlign.center,
          style: const TextStyle(color: PulynColors.textSecondary),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _startCamera,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Vincular outra criança'),
        ),
        if (widget.onClose != null)
          TextButton(onPressed: widget.onClose, child: const Text('Concluir')),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.error_outline_rounded, size: 44, color: PulynColors.danger),
        const SizedBox(height: 12),
        Text(
          _errorMessage.isEmpty ? 'Não foi possível vincular a criança.' : _errorMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, height: 1.4),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _startCamera,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar de novo'),
        ),
        if (widget.onClose != null)
          TextButton(onPressed: widget.onClose, child: const Text('Cancelar')),
      ],
    );
  }

  Widget _defaultCamera(BuildContext context, ValueChanged<String> onCode) => _CameraView(onCode: onCode);
}

/// Câmera de verdade (mobile_scanner). Dona do próprio controller: liga ao aparecer e
/// desliga ao sair da tela.
class _CameraView extends StatefulWidget {
  final ValueChanged<String> onCode;

  const _CameraView({required this.onCode});

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> {
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(detectionTimeoutMs: 1000, returnImage: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        if (capture.barcodes.isEmpty) return;
        final value = capture.barcodes.first.rawValue;
        if (value != null && value.isNotEmpty) widget.onCode(value);
      },
      errorBuilder: (context, error) {
        log.e('[QR] Erro na câmera: $error');
        return const ColoredBox(
          color: Colors.black,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Não foi possível abrir a câmera.\nConfira a permissão do app e se outro app não está usando a câmera.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
            ),
          ),
        );
      },
    );
  }
}
