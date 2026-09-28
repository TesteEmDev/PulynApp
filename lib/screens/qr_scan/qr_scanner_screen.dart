import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../utils/logger.dart';
import '../../services/api_service.dart';
import '../../models/family_models.dart';

class QRScannerScreen extends StatefulWidget {
  final String apiUrl;
  final Function(Child) onChildLinked;

  const QRScannerScreen({
    super.key,
    required this.apiUrl,
    required this.onChildLinked,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool isScanning = false;
  bool isProcessing = false;
  bool _isInitializing = false; // ✅ Nova flag para proteger inicialização
  String? scannedCode;
  late ApiService _apiService;
  MobileScannerController? _scannerController;
  Child? linkedChild;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    log.i('[QR] 🚀 QRScannerScreen inicializado');
    log.i('[QR] 📱 Device: Android/iOS (verificar manualmente)');
    log.i('[QR] 🔐 Permissões: CAMERA (deverá pedir ao abrir a câmera)');
    log.i('[QR] 📱 Dependência: permission_handler ^11.4.0 instalado');
    log.i(
      '[QR] 📱 Método: _startScanning() -> _hasCameraPermission() -> _requestCameraPermission()',
    );
  }

  /// ✅ Pede permissão de câmera
  Future<bool> _requestCameraPermission() async {
    log.i('[QR] 🔐 Pedindo permissão de câmera...');

    final status = await Permission.camera.request();

    log.i('[QR] 📱 Status da permissão: $status');

    if (status.isDenied) {
      log.e('[QR] ❌ Permissão NEGADA pelo usuário');
      return false;
    } else if (status.isPermanentlyDenied) {
      log.e('[QR] ❌ Permissão PERMANENTEMENTE NEGADA - abrindo configurações');
      openAppSettings();
      return false;
    } else if (status.isGranted) {
      log.i('[QR] ✅ Permissão CONCEDIDA');
      return true;
    } else if (status.isRestricted) {
      log.e('[QR] ⚠️ Permissão RESTRITA');
      return false;
    }

    return false;
  }

  /// ✅ Verifica se tem permissão de câmera (versão sem pedir)
  Future<bool> _hasCameraPermission() async {
    final status = await Permission.camera.status;
    log.i('[QR] 🔍 Status atual da câmera: $status');
    return status.isGranted;
  }

  /// ✅ Inicializa o scanner
  void _initializeScanner() {
    if (_scannerController != null) return;

    log.i('[QR] 🚀 Criando MobileScannerController...');
    _scannerController = MobileScannerController(
      detectionTimeoutMs: 1000,
      returnImage: false,
    );
    log.i('[QR] ✅ Controller criado com sucesso');
  }

  /// ✅ Inicia o scanner - VERSÃO SIMPLIFICADA
  Future<void> _startScanning() async {
    if (_isInitializing || isScanning || !mounted) {
      log.w('[QR] ⚠️ Já está inicializando ou scanning');
      return;
    }

    setState(() => _isInitializing = true);

    try {
      log.i('[QR] 📱 Iniciando processo de scanning...');

      // 1. Verificar/obter permissão
      final hasPermission = await _hasCameraPermission();
      if (!hasPermission) {
        final granted = await _requestCameraPermission();
        if (!granted) {
          log.e('[QR] ❌ Permissão negada');
          if (mounted) _showPermissionDeniedDialog();
          return;
        }
      }

      // 2. Criar controller (SEM chamar start!)
      log.i('[QR] 🎥 Criando controller...');
      _initializeScanner();

      // 3. Atualizar estado para mostrar a câmera
      // O MobileScanner widget chamará start() automaticamente quando montado
      if (mounted) {
        setState(() {
          isScanning = true;
          _hasScanned = false;
          isProcessing = false;
          scannedCode = null;
        });
      }

      log.i(
        '[QR] ✅ Pronto! MobileScanner será montado e iniciará automaticamente',
      );
    } catch (e) {
      log.e('[QR] ❌ Erro no processo: $e');
      if (mounted) {
        _showErrorDialog('Erro', 'Falha ao preparar câmera: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  /// ✅ Para o scanner com proteção de mounted
  void _stopScanning() {
    log.i('[QR] 🛑 Parando scanner...');
    try {
      _scannerController?.stop();
      log.i('[QR] ✅ Scanner parado');
    } catch (e) {
      log.e('[QR] ⚠️ Erro ao parar scanner: $e');
    }

    if (mounted) {
      setState(() => isScanning = false);
    }
  }

  /// ✅ Processa QR code escaneado com melhor proteção
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_hasScanned || isProcessing) {
      log.w(
        '[QR] ⚠️ Já está processando (hasScanned: $_hasScanned, isProcessing: $isProcessing)',
      );
      return;
    }

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final qrCode = barcodes.first.rawValue;
    if (qrCode == null || qrCode.isEmpty) return;

    log.i('[QR] ✅ QR Code detectado: $qrCode');

    // ✅ Marcar como escaneado ANTES de iniciar processamento
    _hasScanned = true;

    if (mounted) {
      setState(() {
        scannedCode = qrCode;
        isProcessing = true;
      });
    }

    await _processQRCode(qrCode);
  }

  /// ✅ Processa o QR code com melhor tratamento de erro
  Future<void> _processQRCode(String qrCode) async {
    try {
      log.i('[QR] 🔄 Processando QR code: $qrCode');

      await _apiService.init();

      final result = await _apiService.linkChildWithQRCode(qrCode);

      log.i('[QR] ✅ Resposta completa: $result');
      log.i('[QR] ✅ Success: ${result['success']}');
      log.i('[QR] ✅ LinkedChild: ${result['linkedChild']}');

      if (result['success'] == true) {
        log.i('[QR] ✅ Criança vinculada com sucesso!');

        // ✅ CORRIGIDO: Procura por 'linkedChild' (não 'children' nem 'child')
        final childData = result['linkedChild'] as Map<String, dynamic>?;

        if (childData != null) {
          log.i('[QR] 👶 Dados da criança recebidos: $childData');
          
          // Converter resposta do backend para modelo Child
          final child = Child(
            id: childData['id'] ?? '',
            name: childData['name'] ?? '',
            nickname: childData['nickname'] ?? '',
            age: childData['age'] ?? 0,
            teamName: childData['evento'] ?? 'Sem time',
            profileImage: null,
            currentScore: 0,
            totalScore: 0,
            teamId: '',
            teamColor: '#cccccc',
            rank: 0,
            achievements: [],
          );

          log.i('[QR] ✅ Child model criado: ${child.nickname}');

          if (mounted) {
            setState(() => linkedChild = child);
            _showSuccessDialog(child);
          }
        } else {
          log.e('[QR] ❌ linkedChild é null ou não é Map');
          throw Exception('Dados da criança não encontrados na resposta');
        }
      } else {
        log.e('[QR] ❌ Success não é true. Result: $result');
        throw Exception(result['message'] ?? result['error'] ?? 'Erro desconhecido');
      }
    } on Exception catch (e) {
      log.e('[QR] ❌ Erro ao vincular: $e');
      log.e('[QR] 📍 Stack: ${StackTrace.current}');
      if (mounted) {
        _showErrorDialog('Erro ao Vincular', 'Não foi possível vincular a criança:\n\n$e');
      }
    } catch (e) {
      log.e('[QR] ❌ Erro genérico ao vincular: $e');
      log.e('[QR] 📍 Tipo: ${e.runtimeType}');
      log.e('[QR] 📍 Stack: ${StackTrace.current}');
      if (mounted) {
        _showErrorDialog('Erro', 'Erro inesperado: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
          _hasScanned = false;
        });
      }
    }
  }

  void _showSuccessDialog(Child child) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('✅ Criança Vinculada!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nome: ${child.nickname.isNotEmpty ? child.nickname : child.name}',
            ),
            const SizedBox(height: 8),
            Text('Idade: ${child.age} anos'),
            if (child.teamName?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text('Time: ${child.teamName}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showScanAnotherDialog();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showScanAnotherDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Escanear Outra Criança?'),
        content: const Text('Deseja vincular outra criança?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Fecha o diálogo
              if (linkedChild != null) {
                log.i('[QR] 👶 Criança vinculada: ${linkedChild!.name}');
                // ✅ onChildLinked já fecha a tela de scanner (Navigator.pop)
                // em todos os pontos de uso. Um segundo pop aqui bateria em
                // uma rota já fechada e derrubava o app.
                widget.onChildLinked(linkedChild!);
              }
            },
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Fecha o diálogo
              if (mounted) {
                setState(() {
                  isScanning = true;
                  isProcessing = false;
                  scannedCode = null;
                  _hasScanned = false;
                });
              }
            },
            child: const Text('Sim'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  isScanning = true;
                  isProcessing = false;
                  scannedCode = null;
                  _hasScanned = false;
                });
              }
            },
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('❌ Permissão de Câmera Negada'),
        content: const Text(
          'Para escanear QR codes, você precisa permitir acesso à câmera.\n\n'
          'Abra as configurações do app e permita acesso à câmera.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  _isInitializing = false;
                });
              }
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Abrir Configurações'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    log.i('[QR] 🧹 Limpando QRScannerScreen...');
    try {
      _scannerController?.stop();
      _scannerController?.dispose();
      log.i('[QR] ✅ Scanner limpo');
    } catch (e) {
      log.e('[QR] ⚠️ Erro ao limpar scanner: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR Code'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  /// ✅ Melhor organização da lógica de renderização
  Widget _buildBody() {
    // Se não está escaneando, mostra tela inicial
    if (!isScanning) {
      return _buildInitialScreen();
    }

    // Se está escaneando mas scanner não foi inicializado, mostra loading
    if (_scannerController == null) {
      return _buildLoadingScreen();
    }

    // Se está escaneando e tem scanner, mostra câmera
    return _buildScannerScreen();
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          const Text('Inicializando câmera...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildInitialScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_2, size: 80, color: Colors.blue),
          const SizedBox(height: 24),
          Text(
            'Escanear QR Code',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          const Text(
            'Clique no botão abaixo para iniciar\no scanner de câmera',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            // ✅ Desabilitar enquanto está inicializando
            onPressed: _isInitializing ? null : _startScanning,
            icon: const Icon(Icons.camera_alt),
            label: Text(_isInitializing ? 'Iniciando...' : 'Abrir Câmera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerScreen() {
    if (_scannerController == null) {
      log.w('[QR] ⚠️ Controller é null, mostrando loading');
      return _buildLoadingScreen();
    }

    log.i(
      '[QR] 🎥 Renderizando scanner screen com controller: $_scannerController',
    );

    return Stack(
      children: [
        // 🎥 Câmera ao fundo - VERSÃO MAIS ROBUSTA
        MobileScanner(
          key: ValueKey(
            _scannerController.hashCode,
          ), // ✅ Chave única para forçar rebuild
          controller: _scannerController!,
          onDetect: _onDetect,
          errorBuilder: (context, error) {
            log.e('[QR] 🚨 ERRO NA CÂMERA: $error');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 80),
                  const SizedBox(height: 24),
                  Text(
                    'Erro ao acessar câmera',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Possíveis soluções:\n• Permitir acesso à câmera nas configurações\n• Verificar se outra app está usando a câmera\n• Reiniciar o aplicativo',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _stopScanning,
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            );
          },
        ),

        // 📱 Overlay com instruções (SEM cobrir câmera)
        if (!isProcessing)
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Instrução no topo
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '📱 Aponte a câmera para o QR Code',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

              // Scanner frame no meio
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // Botão Cancelar no fundo
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _stopScanning,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),

        // ⏳ Loading overlay
        if (isProcessing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.green),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Validando QR Code...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (scannedCode != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Código: ${scannedCode!.length > 20 ? scannedCode!.substring(0, 20) : scannedCode}...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
