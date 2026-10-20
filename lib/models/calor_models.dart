import 'dart:ui' show Offset;

/// Uma célula do mapa de calor, em coordenadas da planta (canvas 450x320).
class CelulaCalor {
  final double x;
  final double y;
  final double valor;

  const CelulaCalor({required this.x, required this.y, required this.valor});
}

double _numero(dynamic valor, [double padrao = 0]) =>
    valor is num ? valor.toDouble() : double.tryParse('${valor ?? ''}') ?? padrao;

/// Calor de UM filho, vindo dos leitores UHF (GET /uhf/familia/crianca/:id).
/// O backend só considera a pulseira dessa criança: os pais nunca recebem dados de outras crianças.
class CalorDaCrianca {
  final List<CelulaCalor> celulas;
  final double celulaUnidades; // lado da célula, na unidade da planta
  final double valorMax;
  final Offset? posicao; // onde a pulseira foi vista na última janela (null = não foi vista)
  final DateTime? balde; // início da janela de 5 s mostrada
  // true nos períodos (5 min, 30 min, evento todo): o valor é tempo somado, o mais antigo com menos peso, e um lugar
  // por onde a criança só passou continua no mapa
  final bool acumulado;

  const CalorDaCrianca({
    required this.celulas,
    required this.celulaUnidades,
    required this.valorMax,
    this.posicao,
    this.balde,
    this.acumulado = false,
  });

  bool get vazio => celulas.isEmpty || valorMax <= 0;

  factory CalorDaCrianca.fromJson(Map<String, dynamic> json) {
    final posicao = json['posicao'];
    return CalorDaCrianca(
      celulas: (json['celulas'] as List? ?? const [])
          .whereType<Map>()
          .map((c) => CelulaCalor(x: _numero(c['x']), y: _numero(c['y']), valor: _numero(c['valor'])))
          .toList(),
      celulaUnidades: _numero(json['celulaUnidades'], 5),
      valorMax: _numero(json['valorMax']),
      posicao: posicao is Map ? Offset(_numero(posicao['x']), _numero(posicao['y'])) : null,
      balde: DateTime.tryParse('${json['balde'] ?? ''}'),
      acumulado: json['acumulado'] == true,
    );
  }

  /// Junta o calor de vários filhos (soma célula a célula) para desenhar numa camada só.
  static CalorDaCrianca juntar(Iterable<CalorDaCrianca> calores) {
    final lista = calores.where((c) => !c.vazio).toList();
    if (lista.isEmpty) return const CalorDaCrianca(celulas: [], celulaUnidades: 5, valorMax: 0);
    if (lista.length == 1) return lista.first;
    final soma = <Offset, double>{};
    for (final calor in lista) {
      for (final c in calor.celulas) {
        final chave = Offset(c.x, c.y);
        soma[chave] = (soma[chave] ?? 0) + c.valor;
      }
    }
    final celulas = soma.entries.map((e) => CelulaCalor(x: e.key.dx, y: e.key.dy, valor: e.value)).toList();
    return CalorDaCrianca(
      celulas: celulas,
      celulaUnidades: lista.first.celulaUnidades,
      valorMax: celulas.fold<double>(0, (m, c) => c.valor > m ? c.valor : m),
      acumulado: lista.first.acumulado,
    );
  }
}
