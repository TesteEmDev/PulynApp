import 'package:flutter/material.dart';
import '../../utils/logger.dart';
import '../../services/api_service.dart';
import '../../models/family_models.dart';
import '../qr_scan/qr_scanner_screen.dart';
import '../../screens/child/child_detail_screen.dart';

class LinkedChildrenScreen extends StatefulWidget {
  final String apiUrl;

  const LinkedChildrenScreen({
    super.key,
    required this.apiUrl,
  });

  @override
  State<LinkedChildrenScreen> createState() => _LinkedChildrenScreenState();
}

class _LinkedChildrenScreenState extends State<LinkedChildrenScreen> {
  List<Child> children = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      log.i('📦 Carregando crianças vinculadas...');

      final apiService = ApiService();
      await apiService.init();
      
      final childrenList = await apiService.getChildren();

      setState(() {
        children = childrenList;
        isLoading = false;
      });

      log.i('✅ ${children.length} crianças carregadas');
    } catch (e) {
      log.e('❌ Erro: $e');
      setState(() {
        error = 'Erro ao carregar crianças: $e';
        isLoading = false;
      });
    }
  }

  void _openQRScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.95,
        child: QRScannerScreen(
          apiUrl: widget.apiUrl,
          onChildLinked: (child) {
            log.i('✅ Criança vinculada: ${child.nickname}');
            Navigator.pop(context);
            _loadChildren(); // Recarregar lista
          },
        ),
      ),
    );
  }

  Future<void> _unlinkChild(String childId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desvinc ular Criança?'),
        content: const Text(
          'Esta ação removerá o acesso aos dados desta criança.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desvinc ular', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final apiService = ApiService();
      await apiService.init();
      
      await apiService.dio.delete('/family/children/$childId/unlink');

      log.i('✅ Criança desvinculada');
      _loadChildren();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Criança desvinculada com sucesso')),
        );
      }
    } catch (e) {
      log.e('❌ Erro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao desvinc ular: $e')),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Crianças'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadChildren,
                        child: const Text('Tentar Novamente'),
                      ),
                    ],
                  ),
                )
              : children.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.child_friendly,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text('Nenhuma criança vinculada'),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _openQRScanner,
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text('Escanear QR Code'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadChildren,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: children.length,
                        itemBuilder: (context, index) {
                          final child = children[index];
                          return _buildChildCard(child);
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openQRScanner,
        backgroundColor: Colors.green,
        tooltip: 'Vincular Nova Criança',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChildCard(Child child) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChildDetailScreen(
              childId: child.id,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _parseColor(child.teamColor),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _parseColor(child.teamColor),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: Text(
                          (child.nickname.isNotEmpty ? child.nickname : child.name)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.nickname.isNotEmpty ? child.nickname : child.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${child.age} anos • ${child.teamName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pontos: ${child.currentScore}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          onTap: () => _unlinkChild(child.id),
                          child: const Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Desvinc ular'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(dynamic colorValue) {
    if (colorValue == null) return Colors.blue;
    if (colorValue is Color) return colorValue;
    if (colorValue is String) {
      // Parse hex color: "#FF0000"
      try {
        return Color(int.parse(colorValue.replaceFirst('#', '0xff')));
      } catch (e) {
        return Colors.blue;
      }
    }
    return Colors.blue;
  }
}
