import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/models/calor_models.dart';
import 'package:pulyn_app/widgets/camada_calor.dart';

void main() {
  test('lê a resposta de /uhf/familia/crianca (números como texto e sem posição)', () {
    final calor = CalorDaCrianca.fromJson({
      'balde': '2026-10-20T18:00:00.000Z',
      'celulaUnidades': 5,
      'valorMax': '0.8',
      'celulas': [
        {'x': 90, 'y': 90.5, 'valor': 0.8},
        {'x': '95', 'y': 90, 'valor': 0.4},
      ],
      'posicao': null,
    });
    expect(calor.celulas.length, 2);
    expect(calor.celulas[1].x, 95);
    expect(calor.valorMax, 0.8);
    expect(calor.posicao, isNull);
    expect(calor.balde, DateTime.utc(2026, 10, 20, 18));
    expect(calor.vazio, isFalse);
    expect(CalorDaCrianca.fromJson({}).vazio, isTrue);
  });

  test('junta o calor de dois filhos somando as células iguais', () {
    const a = CalorDaCrianca(celulas: [CelulaCalor(x: 10, y: 10, valor: 0.5)], celulaUnidades: 5, valorMax: 0.5);
    const b = CalorDaCrianca(
      celulas: [CelulaCalor(x: 10, y: 10, valor: 0.3), CelulaCalor(x: 20, y: 10, valor: 0.2)],
      celulaUnidades: 5,
      valorMax: 0.3,
    );
    final junto = CalorDaCrianca.juntar([a, b, const CalorDaCrianca(celulas: [], celulaUnidades: 5, valorMax: 0)]);
    expect(junto.celulas.length, 2);
    expect(junto.valorMax, closeTo(0.8, 1e-9));
    expect(identical(CalorDaCrianca.juntar([a]), a), isTrue);
    expect(CalorDaCrianca.juntar([]).vazio, isTrue);
  });

  test('rampa de cor igual à do painel web: azul, verde, amarelo, vermelho', () {
    expect(corDoCalor(0).toARGB32(), 0xFF1E9BD7);
    expect(corDoCalor(0.33).toARGB32(), 0xFF22C55E);
    expect(corDoCalor(1).toARGB32(), 0xFFEF4444);
    expect(corDoCalor(5).toARGB32(), 0xFFEF4444);
    expect(corDoCalor(-1).toARGB32(), 0xFF1E9BD7);
  });
}
