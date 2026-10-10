import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/alimentacao.dart';
import 'package:plano_de_cuidado/core/armazenamento.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('modelo alimentar v3 calcula rotina e substituição do dia', () {
    final alimento = AlimentacaoPlano.fromMap(AlimentacaoPlano.modeloTeste());
    final padrao = alimento.selecoesParaDia('2026-10-08');
    final totalPadrao = alimento.total(padrao);
    expect(padrao['almoco'], 'almoco_frango');
    expect(totalPadrao.kcal, 1600);

    final alterado = {...padrao, 'almoco': 'almoco_carne'};
    final totalAlterado = alimento.total(alterado);
    expect(totalAlterado.kcal, 1630);
    expect(alimento.opcao('almoco', 'almoco_carne')!.qualidade, 'alternativa');
  });

  test('rejeita rotina que aponta para opção inexistente', () {
    final dados = AlimentacaoPlano.modeloTeste();
    (dados['rotina'] as Map)['padrao'] = {'cafe': 'nao_existe'};
    expect(
      () => AlimentacaoPlano.fromMap(dados),
      throwsA(isA<FormatException>()),
    );
  });

  group('seleções alimentares persistem por acompanhamento e dia', () {
    late Database database;
    late Armazenamento storage;

    setUp(() async {
      sqfliteFfiInit();
      database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => Armazenamento.criarEsquema(db),
        ),
      );
      storage = Armazenamento.testing(database);
    });

    tearDown(() => database.close());

    test('não mistura dias nem ids diferentes', () async {
      await storage.salvarSelecoesAlimentacao('plano-a', '2026-10-08', {
        'almoco': 'almoco_carne',
      });
      await storage.salvarSelecoesAlimentacao('plano-b', '2026-10-08', {
        'almoco': 'almoco_frango',
      });
      expect(await storage.selecoesAlimentacao('plano-a', '2026-10-08'), {
        'almoco': 'almoco_carne',
      });
      expect(
        await storage.selecoesAlimentacao('plano-a', '2026-10-09'),
        isEmpty,
      );
      expect(await storage.selecoesAlimentacao('plano-b', '2026-10-08'), {
        'almoco': 'almoco_frango',
      });
    });
  });

  test('plano v3 mantém compatibilidade com a identificação do paciente', () {
    final data =
        jsonDecode(
              File('exemplos/plano-maria-2026-10-02.plano').readAsStringSync(),
            )
            as Map<String, dynamic>;
    data['versao'] = 3;
    data['alimentacao'] = AlimentacaoPlano.modeloTeste();
    final plano = Plano.parse(jsonEncode(data));
    expect(plano.alimentacao!.refeicoes, hasLength(3));
    expect(plano.nomePaciente, 'Maria Exemplo');
  });

  test('exemplo v3 exportável é aceito pelo parser', () {
    final source = File(
      'exemplos/plano-alimentar-teste-v3.plano',
    ).readAsStringSync();
    final plano = Plano.parse(source);
    expect(plano.alimentacao!.titulo, 'Rotina alimentar de teste');
    expect(plano.alimentacao!.refeicoes.first.horario, '07:30');
  });
}
