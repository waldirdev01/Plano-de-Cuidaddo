import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/armazenamento.dart';
import 'package:plano_de_cuidado/core/edicao_plano.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late Armazenamento db;
  // Fixture fictício versionado: os testes devem funcionar em um clone limpo.
  final dados =
      jsonDecode(
            File('exemplos/plano-maria-2026-10-02.plano').readAsStringSync(),
          )
          as Map<String, dynamic>;
  dados['versao'] = 2;
  dados['paciente'] = {'nome': 'Maria Exemplo', 'nascimento': '1985-04-12'};
  final original = Plano.parse(jsonEncode(dados));
  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, _) => Armazenamento.criarEsquema(d),
      ),
    );
    db = Armazenamento.testing(database);
    await db.salvarPerfilPaciente(
      PerfilPaciente(
        nome: original.nomePaciente,
        nascimento: original.nascimentoPaciente!,
      ),
    );
  });
  tearDown(() => database.close());
  test(
    'criar, editar e buscar planos profissionais mantém o plano do paciente',
    () async {
      await db.importar(original);
      final data = novoPlano('Médica Teste', 'CRM Teste');
      data['paciente']['nome'] = 'João Teste';
      data['paciente']['nascimento'] = '1990-01-01';
      data['metas'] = [
        modeloCampo('Refeições à mesa'),
        modeloCampo('Água'),
        {'id': novoId(), 'titulo': 'Sim?', 'tipo': 'sim_nao'},
      ];
      data['camposDiarios'] = [
        modeloCampo('Atividade física'),
        modeloCampo('Emoção ao comer'),
        modeloCampo('Nota do dia'),
      ];
      final created = Plano.parse(jsonEncode(data));
      await db.salvarCriado(created);
      expect((await db.planoAtivo())!.id, original.id);
      expect((await db.planosCriados()).single.id, created.id);
      data['paciente']['nome'] = 'João Editado';
      await db.salvarCriado(Plano.parse(jsonEncode(data)));
      expect((await db.planosCriados()).single.nomePaciente, 'João Editado');
      expect(nomeArquivoPlano(created), startsWith('plano-joao-'));
    },
  );
  test('duplicar não inclui identidade nem PDF do outro paciente', () async {
    final data = duplicarPlano(original, 'Outra Profissional', 'CRN Teste');
    expect(data['id'], isNot(original.id));
    expect(data['paciente']['nome'], isEmpty);
    expect(data.containsKey('pdf'), isFalse);
    data['metas'][0]['titulo'] = 'Alterada';
    expect(original.metas[0]['titulo'], isNot('Alterada'));
    data['paciente']['nome'] = 'Outra Pessoa';
    data['paciente']['nascimento'] = '1990-01-01';
    await db.salvarCriado(Plano.parse(jsonEncode(data)));
    expect((await db.planosCriados()).single.nomePaciente, 'Outra Pessoa');
  });
  test(
    'exportar, importar e reimportar mantém registros de dias diferentes',
    () async {
      await db.salvarCriado(original);
      final exported = utf8.encode(jsonEncode(original.data));
      await db.importar(Plano.parseBytes(exported));
      await db.salvarRegistro(original.id, '2026-10-03', 'mesa', ['Café']);
      await db.salvarRegistro(original.id, '2026-10-04', 'mesa', ['Almoço']);
      await db.salvarRegistro(original.id, '2026-10-04', 'agua', 3);
      final edit = copiarDados(original.data);
      edit['metas'][0]['descricao'] = 'Descrição atualizada';
      await db.salvarCriado(Plano.parse(jsonEncode(edit)));
      await db.importar(Plano.parseBytes(utf8.encode(jsonEncode(edit))));
      expect((await db.registros(original.id, '2026-10-03'))['mesa'], ['Café']);
      expect((await db.registros(original.id, '2026-10-04'))['mesa'], [
        'Almoço',
      ]);
      expect((await db.registros(original.id, '2026-10-04'))['agua'], 3);
      expect(
        (await db.planoAtivo())!.metas[0]['descricao'],
        'Descrição atualizada',
      );
    },
  );
  test('PDF e imagem soltos são recusados com mensagens em português', () {
    expect(
      () => Plano.parseBytes([37, 80, 68, 70, 45, 255]),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'mensagem',
          contains('PDF'),
        ),
      ),
    );
    expect(
      () => Plano.parseBytes([137, 80, 78, 71, 13, 10, 26, 10]),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'mensagem',
          contains('UTF-8'),
        ),
      ),
    );
    expect(
      () => Plano.parseBytes(utf8.encode('{quebrado')),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'mensagem',
          contains('plano válido'),
        ),
      ),
    );
  });
  test('nomes de exportação não contêm caminhos ou acentos', () {
    final data = copiarDados(original.data);
    data['paciente']['nome'] = '../../Álvaro Teste';
    final name = nomeArquivoPlano(Plano.parse(jsonEncode(data)));
    expect(name, 'plano-alvaro-2026-10-03.plano');
  });
  test(
    'backup e restauração recuperam rascunhos, dias, envios e perfil',
    () async {
      await db.importar(original);
      await db.salvarRegistro(original.id, '2026-10-03', 'mesa', ['Café']);
      await db.registrarEnvio(
        original.id,
        DateTime(2026, 10, 9, 17),
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 9),
      );
      await db.encerrarAcompanhamento(original.id);
      await db.setConfig('profissional_nome', 'Nome do perfil');
      final draft = duplicarPlano(original, 'Outra Profissional', 'CRN');
      draft['paciente']['nome'] = 'Rascunho';
      draft['paciente']['nascimento'] = '1990-01-01';
      await db.salvarCriado(Plano.parse(jsonEncode(draft)));
      final source = await db.backupConteudo();
      for (final table in ['planos', 'registros', 'envios', 'config']) {
        await database.delete(table);
      }
      await db.restaurar(source);
      expect(await db.planoAtivo(), isNull);
      expect(await db.estadoAcompanhamento(original.id), 'encerrado');
      expect((await db.planosCriados()).single.nomePaciente, 'Rascunho');
      expect((await db.registros(original.id, '2026-10-03'))['mesa'], ['Café']);
      expect(await db.ultimoEnvio(original.id), '2026-10-09');
      expect(await db.config('profissional_nome'), 'Nome do perfil');
      expect(
        () => db.restaurar(source.replaceFirst('"versao":1', '"versao":2')),
        throwsFormatException,
      );
      expect(await db.planoAtivo(), isNull);
    },
  );
}
