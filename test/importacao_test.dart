import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/armazenamento.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late Armazenamento storage;
  late String sample;

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
    sample = File('exemplos/plano-maria-2026-10-02.plano').readAsStringSync();
    await storage.salvarPerfilPaciente(
      PerfilPaciente(nome: 'Maria Exemplo', nascimento: '1985-04-12'),
    );
  });

  tearDown(() => database.close());

  test('reimportar o mesmo id atualiza o plano e preserva anotações', () async {
    final first = Plano.parse(sample);
    await storage.importar(first);
    await storage.salvarRegistro(
      first.id,
      '2026-10-03',
      'atividade',
      'caminhada',
    );

    final updated = Plano.parse(
      sample.replaceFirst('Maria Exemplo', 'MARIA EXEMPLO'),
    );
    await storage.importar(updated);

    expect((await storage.planoAtivo())?.nomePaciente, 'MARIA EXEMPLO');
    expect(await storage.registros(first.id, '2026-10-03'), {
      'atividade': 'caminhada',
    });
    expect(await storage.planos(status: 'ativo'), hasLength(1));
  });

  test(
    'plano novo vira seleção atual sem misturar os acompanhamentos salvos',
    () async {
      final first = Plano.parse(sample);
      await storage.importar(first);
      await storage.salvarRegistro(
        first.id,
        '2026-10-03',
        'atividade',
        'caminhada',
      );

      final another = Plano.parse(sample.replaceFirst(first.id, 'novo-id-123'));
      await storage.importar(another);

      expect((await storage.planoAtivo())?.id, 'novo-id-123');
      expect(await storage.planosPaciente(), hasLength(2));
      expect(await storage.registros(first.id, '2026-10-03'), {
        'atividade': 'caminhada',
      });
      await storage.selecionarPlano(first.id);
      expect((await storage.planoAtivo())?.id, first.id);
    },
  );

  test(
    'trocar entre acompanhamentos conserva os registros de cada plano',
    () async {
      final first = Plano.parse(sample);
      final second = Plano.parse(
        sample.replaceFirst(first.id, 'segundo-id-123'),
      );
      await storage.importar(first);
      await storage.salvarRegistro(
        first.id,
        '2026-10-03',
        'atividade',
        'caminhada',
      );
      await storage.importar(second);
      await storage.salvarRegistro(
        second.id,
        '2026-10-04',
        'atividade',
        'leitura',
      );

      await storage.selecionarPlano(first.id);
      expect((await storage.planoAtivo())?.id, first.id);
      expect(await storage.registros(first.id, '2026-10-03'), {
        'atividade': 'caminhada',
      });
      await storage.selecionarPlano(second.id);
      expect((await storage.planoAtivo())?.id, second.id);
      expect(await storage.registros(second.id, '2026-10-04'), {
        'atividade': 'leitura',
      });
      expect(await storage.registros(first.id, '2026-10-03'), {
        'atividade': 'caminhada',
      });
    },
  );

  test(
    'selecionar plano de outra pessoa é recusado sem trocar o ativo',
    () async {
      final first = Plano.parse(sample);
      final otherData = jsonDecode(sample) as Map<String, dynamic>;
      otherData['id'] = 'outra-pessoa-id';
      otherData['paciente']['nascimento'] = '1990-01-01';
      final other = Plano.parse(jsonEncode(otherData));
      await storage.importar(first);
      await database.insert('planos', {
        'id': other.id,
        'json': jsonEncode(other.data),
        'status': 'arquivado',
        'origem': 'importado',
        'atualizado_em': DateTime.now().toIso8601String(),
      });

      await expectLater(
        storage.selecionarPlano(other.id),
        throwsFormatException,
      );
      expect((await storage.planoAtivo())?.id, first.id);
    },
  );

  test(
    'encerrar mantém registros e reativar permite selecionar de novo',
    () async {
      final plan = Plano.parse(sample);
      await storage.importar(plan);
      await storage.salvarRegistro(
        plan.id,
        '2026-10-03',
        'atividade',
        'caminhada',
      );

      await storage.encerrarAcompanhamento(plan.id);
      expect(await storage.estadoAcompanhamento(plan.id), 'encerrado');
      expect(await storage.planoAtivo(), isNull);
      expect(await storage.registros(plan.id, '2026-10-03'), {
        'atividade': 'caminhada',
      });

      await storage.reativarAcompanhamento(plan.id);
      await storage.selecionarPlano(plan.id);
      expect(await storage.estadoAcompanhamento(plan.id), 'em_andamento');
      expect((await storage.planoAtivo())?.id, plan.id);
    },
  );

  test(
    'lista e troca exibem somente arquivos do destinatário cadastrado',
    () async {
      final plan = Plano.parse(sample);
      final otherData = jsonDecode(sample) as Map<String, dynamic>;
      otherData['id'] = 'outro-destinatario';
      otherData['paciente']['nascimento'] = '1990-01-01';
      final other = Plano.parse(jsonEncode(otherData));
      await storage.importar(plan);
      await database.insert('planos', {
        'id': other.id,
        'json': jsonEncode(other.data),
        'status': 'ativo',
        'origem': 'importado',
        'atualizado_em': DateTime.now().toIso8601String(),
      });

      expect((await storage.planosPaciente()).map((p) => p.id), [plan.id]);
      await expectLater(
        storage.selecionarPlano(other.id),
        throwsFormatException,
      );
      expect((await storage.planoAtivo())?.id, plan.id);
    },
  );

  test('arquivo inválido não modifica o plano ativo', () async {
    final first = Plano.parse(sample);
    await storage.importar(first);
    expect(
      () => Plano.parse(utf8.decode([0x25, 0x50, 0x44, 0x46])),
      throwsFormatException,
    );
    expect((await storage.planoAtivo())?.id, first.id);
  });
}
