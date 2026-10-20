import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/calor_models.dart';

// Mesma rampa do painel web (FrontEnd/src/components/uhf/CamadaCalor.tsx):
// 0 = azul, 0,33 = verde, 0,66 = amarelo, 1 = vermelho.
const List<(double, Color)> _paradas = [
  (0.0, Color(0xFF1E9BD7)),
  (0.33, Color(0xFF22C55E)),
  (0.66, Color(0xFFFACC15)),
  (1.0, Color(0xFFEF4444)),
];

Color corDoCalor(double t) {
  final v = t.clamp(0.0, 1.0);
  for (var i = 1; i < _paradas.length; i++) {
    final (fim, corFim) = _paradas[i];
    final (inicio, corInicio) = _paradas[i - 1];
    if (v <= fim) return Color.lerp(corInicio, corFim, (v - inicio) / (fim - inicio))!;
  }
  return _paradas.last.$2;
}

/// Camada de calor desenhada sobre a planta. Ocupa o canvas 450x320 (mesmas coordenadas dos checkpoints).
/// As células são desfocadas para parecer uma mancha contínua, como no painel web.
class CamadaCalor extends StatelessWidget {
  final CalorDaCrianca calor;

  const CamadaCalor({required this.calor, super.key});

  @override
  Widget build(BuildContext context) {
    if (calor.vazio) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(painter: _CalorPainter(calor)),
    );
  }
}

class _CalorPainter extends CustomPainter {
  final CalorDaCrianca calor;

  _CalorPainter(this.calor);

  @override
  void paint(Canvas canvas, Size size) {
    final lado = calor.celulaUnidades;
    final paint = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.5, lado * 0.8));
    for (final c in calor.celulas) {
      // Tempo somado: escala pela raiz, para uma passagem rápida (o rastro) continuar visível ao lado de onde a
      // criança ficou muito tempo. Mesma regra do painel web.
      final t = calor.acumulado ? math.sqrt(c.valor / calor.valorMax) : c.valor / calor.valorMax;
      paint.color = corDoCalor(t).withValues(alpha: 0.25 + 0.5 * math.min(1.0, t));
      canvas.drawRect(Rect.fromCenter(center: Offset(c.x, c.y), width: lado, height: lado), paint);
    }
  }

  @override
  bool shouldRepaint(_CalorPainter oldDelegate) => oldDelegate.calor != calor;
}

/// Trajeto de um filho sobre a planta (canvas 450x320): linha pelas posições do período, mais apagada quanto mais
/// antiga (mesmo peso do calor), com um ponto em cada lugar e um ponto maior onde ele foi visto por último.
class CamadaTrajeto extends StatelessWidget {
  final List<PontoTrajeto> pontos;
  final Color cor;

  const CamadaTrajeto({required this.pontos, this.cor = Colors.yellow, super.key});

  @override
  Widget build(BuildContext context) {
    if (pontos.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(child: CustomPaint(painter: _TrajetoPainter(pontos, cor)));
  }
}

class _TrajetoPainter extends CustomPainter {
  final List<PontoTrajeto> pontos;
  final Color cor;

  _TrajetoPainter(List<PontoTrajeto> pontos, this.cor) : pontos = semRepetidos(pontos);

  @override
  void paint(Canvas canvas, Size size) {
    final n = pontos.length;
    final alfas = alfasDoTrajeto(pontos);
    final linha = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    // O trecho de um lugar ao próximo foi feito quando a criança saiu do primeiro: usa a idade dele.
    for (var i = 1; i < n; i++) {
      linha.color = cor.withValues(alpha: alfas[i - 1]);
      canvas.drawLine(pontos[i - 1].posicao, pontos[i].posicao, linha);
    }
    final ponto = Paint();
    for (var i = 0; i < n - 1; i++) {
      ponto.color = cor.withValues(alpha: alfas[i]);
      canvas.drawCircle(pontos[i].posicao, 2.5, ponto);
    }
    final ultimo = pontos.last.posicao;
    canvas.drawCircle(ultimo, 5, Paint()..color = cor);
    canvas.drawCircle(
      ultimo,
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_TrajetoPainter oldDelegate) =>
      oldDelegate.cor != cor ||
      oldDelegate.pontos.length != pontos.length ||
      Iterable<int>.generate(pontos.length).any((i) => oldDelegate.pontos[i] != pontos[i]);
}

/// Várias janelas seguidas no mesmo lugar viram um ponto só no trajeto (fica o `ate` mais recente).
List<PontoTrajeto> semRepetidos(List<PontoTrajeto> pontos) {
  final lista = <PontoTrajeto>[];
  for (final p in pontos) {
    if (lista.isNotEmpty && (lista.last.posicao - p.posicao).distance <= 0.5) {
      lista[lista.length - 1] = PontoTrajeto(p.posicao, ate: p.ate ?? lista.last.ate);
    } else {
      lista.add(p);
    }
  }
  return lista;
}

/// Opacidade de cada ponto pela idade em relação ao ponto mais recente: 0,95 agora, 0,275 no piso (horas atrás).
List<double> alfasDoTrajeto(List<PontoTrajeto> pontos) {
  final datas = pontos.map((p) => p.ate).whereType<DateTime>();
  final referencia = datas.isEmpty ? null : datas.reduce((a, b) => a.isAfter(b) ? a : b);
  return [
    for (final p in pontos)
      0.2 + 0.75 * (referencia == null || p.ate == null ? 1.0 : pesoDaIdade(referencia.difference(p.ate!))),
  ];
}

/// Legenda: pouco tempo (azul) a muito tempo (vermelho) no lugar.
class LegendaCalor extends StatelessWidget {
  const LegendaCalor({super.key});

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(fontSize: 11, color: PulynColors.textMuted, fontWeight: FontWeight.w500);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Pouco tempo', style: estilo),
        const SizedBox(width: 8),
        Container(
          width: 96,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(colors: [for (final t in [0.0, 0.33, 0.66, 1.0]) corDoCalor(t)]),
          ),
        ),
        const SizedBox(width: 8),
        const Text('Muito tempo', style: estilo),
      ],
    );
  }
}
