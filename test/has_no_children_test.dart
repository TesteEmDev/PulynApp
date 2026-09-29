import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/models/family_models.dart';
import 'package:pulyn_app/screens/home/home_screen.dart';

Child _child() => Child(
      id: 'c1',
      name: 'Lia',
      nickname: 'Lia',
      age: 7,
      currentScore: 0,
      totalScore: 0,
      teamId: 't',
      teamName: 'T',
      teamColor: '#1E9BD7',
      rank: 1,
      achievements: const [],
    );

/// Decide quando o botão de QR aparece na barra e o destaque aparece na home.
void main() {
  test('lista vazia carregada: mostra o QR Code', () {
    expect(hasNoChildren(const AsyncValue.data(<Child>[])), isTrue);
  });

  test('com criança vinculada: some (o botão só existe até a primeira vinculada)', () {
    expect(hasNoChildren(AsyncValue.data([_child()])), isFalse);
  });

  test('carregando pela primeira vez: não mostra (o QR não pisca por engano)', () {
    expect(hasNoChildren(const AsyncValue.loading()), isFalse);
  });

  test('erro sem dados: não mostra', () {
    expect(hasNoChildren(AsyncValue.error(Exception('x'), StackTrace.empty)), isFalse);
  });

  test('recarregando: vale a lista anterior (não pisca a cada atualização)', () {
    final reloadingEmpty = const AsyncLoading<List<Child>>().copyWithPrevious(const AsyncData(<Child>[]));
    final reloadingWithChild = const AsyncLoading<List<Child>>().copyWithPrevious(AsyncData([_child()]));

    expect(hasNoChildren(reloadingEmpty), isTrue);
    expect(hasNoChildren(reloadingWithChild), isFalse);
  });
}
