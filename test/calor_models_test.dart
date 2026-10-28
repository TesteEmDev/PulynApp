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
    expect(calor.acumulado, isFalse);
    expect(calor.trajeto, isEmpty);
  });

  test('lê o tempo somado e o trajeto do período', () {
    final calor = CalorDaCrianca.fromJson({
      'acumulado': true,
      'trajeto': [
        {'balde': '2026-10-20T18:00:00.000Z', 'ate': '2026-10-20T18:05:00.000Z', 'x': 205, 'y': 134},
        {'balde': '2026-10-20T18:05:20.000Z', 'x': '204', 'y': 81.5},
      ],
    });
    expect(calor.acumulado, isTrue);
    expect(calor.trajeto, [
      PontoTrajeto(const Offset(205, 134), ate: DateTime.utc(2026, 10, 20, 18, 5)),
      PontoTrajeto(const Offset(204, 81.5), ate: DateTime.utc(2026, 10, 20, 18, 5, 20)),
    ]);
  });

  test('trajeto: janelas seguidas no mesmo lugar viram um ponto só', () {
    final t = DateTime.utc(2026, 10, 20, 18);
    PontoTrajeto p(double x, int min) => PontoTrajeto(Offset(x, 1), ate: t.add(Duration(minutes: min)));
    expect(semRepetidos([p(1, 0), p(1, 1), p(5, 2), p(5, 3), p(1, 4)]), [p(1, 1), p(5, 3), p(1, 4)]);
  });

  test('rastro: mais fraco quanto mais antigo, mas nunca some', () {
    expect(pesoDaIdade(Duration.zero), 1);
    expect(pesoDaIdade(const Duration(minutes: 20)), closeTo(0.5, 1e-9));
    expect(pesoDaIdade(const Duration(hours: 1)), closeTo(0.125, 1e-9));
    expect(pesoDaIdade(const Duration(hours: 3)), 0.1);
    final t = DateTime.utc(2026, 10, 20, 18);
    final alfas = alfasDoTrajeto([
      PontoTrajeto(Offset.zero, ate: t.subtract(const Duration(hours: 3))),
      PontoTrajeto(Offset.zero, ate: t.subtract(const Duration(minutes: 20))),
      PontoTrajeto(Offset.zero, ate: t),
    ]);
    expect(alfas[0], closeTo(0.275, 1e-9));
    expect(alfas[1], closeTo(0.575, 1e-9));
    expect(alfas[2], closeTo(0.95, 1e-9));
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

  test('cada filho tem uma cor de rastro diferente, fora da rampa do calor', () {
    final cores = [for (var i = 0; i < coresDosFilhos.length; i++) corDoFilho(i).toARGB32()];
    expect(cores.toSet().length, coresDosFilhos.length);
    expect(corDoFilho(coresDosFilhos.length), corDoFilho(0)); // mais filhos que cores: repete
    for (final t in [0.0, 0.33, 0.66, 1.0]) {
      expect(cores, isNot(contains(corDoCalor(t).toARGB32())));
    }
  });

  test('rampa de cor igual à do painel web: azul, verde, amarelo, vermelho', () {
    expect(corDoCalor(0).toARGB32(), 0xFF1E9BD7);
    expect(corDoCalor(0.33).toARGB32(), 0xFF22C55E);
    expect(corDoCalor(1).toARGB32(), 0xFFEF4444);
    expect(corDoCalor(5).toARGB32(), 0xFFEF4444);
    expect(corDoCalor(-1).toARGB32(), 0xFF1E9BD7);
  });
}
