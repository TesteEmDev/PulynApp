import 'package:flutter/material.dart';
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
  String? scannedCode;
  late ApiService _apiService;
  Child? linkedChild;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
  }

  /// ✅ Inicia o scanner com permissão
  Future<void> _startScanning() async {
    setState(() => isScanning = true);
  }

  /// ✅ Para o scanner
  void _stopScanning() {
    setState(() => isScanning = false);
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
            Text('Nome: ${child.nickname.isNotEmpty ? child.nickname : child.name}'),
            const SizedBox(height: 8),
            Text('Idade: ${child.age} anos'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Pergunta se deseja escanear outra
              _showScanAnotherDialog();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// ✅ Pergunta se deseja escanear outra criança
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
              Navigator.pop(dialogContext); // Fecha o dialog
              // Volta ao início com a criança vinculada
              if (linkedChild != null) {
                widget.onChildLinked(linkedChild!);
              }
              // ⚠️ NÃO fazer pop do modal aqui - deixa o widget.onChildLinked fazer
            },
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Fecha o dialog
              // Continua escaneando
              setState(() {
                isScanning = true;
                isProcessing = false;
                scannedCode = null;
              });
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
              // Volta a escanear
              setState(() {
                isScanning = true;
                isProcessing = false;
                scannedCode = null;
              });
            },
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
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
      body: !isScanning
          ? _buildInitialScreen()
          : _buildScannerScreen(),
    );
  }

  /// ✅ Tela inicial (pedindo permissão)
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
            onPressed: _startScanning,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Abrir Câmera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Tela do scanner em ação
  Widget _buildScannerScreen() {
    return Stack(
      children: [
        // Placeholder - você precisa adicionar qr_code_scanner aqui
        Container(
          color: Colors.black,
          child: const Center(
            child: Text(
              'Scanner de QR Code',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        // Overlay com instruções
        if (!isProcessing)
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '📱 Aponte a câmera para o código QR',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                // Scanner frame
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.green,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _stopScanning,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        // Loading
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
                      'Código: $scannedCode',
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
