import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/armazenamento.dart';
import 'package:plano_de_cuidado/core/edicao_plano.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late Armazenamento storage;
  late Plano plano;
  final perfil = PerfilPaciente(
    nome: 'Maria Exemplo',
    nascimento: '1985-04-12',
  );
  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, _) => Armazenamento.criarEsquema(d),
      ),
    );
    storage = Armazenamento.testing(database);
    plano = Plano.parse(
      File('exemplos/plano-maria-2026-10-02.plano').readAsStringSync(),
    );
  });
  tearDown(() => database.close());

  test('aceita somente nome completo e nascimento coincidentes', () {
    expect(perfil.corresponde(plano), isTrue);
    final outra = copiarDados(
      plano.data,
    )..['paciente'] = {'nome': 'Outra Pessoa', 'nascimento': perfil.nascimento};
    expect(
      () => perfil.conferir(Plano.parse(jsonEncode(outra))),
      throwsFormatException,
    );
    outra['paciente'] = {'nome': perfil.nome, 'nascimento': '1985-04-13'};
    expect(
      () => perfil.conferir(Plano.parse(jsonEncode(outra))),
      throwsFormatException,
    );
  });
  test('acentos caixa espaços e acento decomposto não impedem conferência', () {
    final d = copiarDados(plano.data)
      ..['paciente'] = {
        'nome': '  JOSÉ   DA SILVA  ',
        'nascimento': perfil.nascimento,
      };
    final p = Plano.parse(jsonEncode(d));
    expect(
      PerfilPaciente(
        nome: 'jose da silva',
        nascimento: perfil.nascimento,
      ).corresponde(p),
      isTrue,
    );
    expect(
      PerfilPaciente(
        nome: 'Jose\u0301 da Silva',
        nascimento: perfil.nascimento,
      ).corresponde(p),
      isTrue,
    );
    expect(
      PerfilPaciente(
        nome: 'José Silva',
        nascimento: perfil.nascimento,
      ).corresponde(p),
      isFalse,
    );
  });
  test('rejeita nascimento ausente inválido e futuro na versão 2', () {
    for (final birth in [
      null,
      '',
      '2025-02-29',
      '2000-13-01',
      '2500-01-01',
      '2000-1-01',
      1990,
    ]) {
      final d = copiarDados(plano.data);
      d['paciente']['nascimento'] = birth;
      expect(() => Plano.parse(jsonEncode(d)), throwsFormatException);
    }
  });
  test(
    'importação sem cadastro não grava nem cria perfil a partir do arquivo',
    () async {
      await expectLater(storage.importar(plano), throwsFormatException);
      expect(await storage.planos(), isEmpty);
      expect(await storage.perfilPaciente(), isNull);
    },
  );
  test('importa correspondente e preserva registros ao reimportar', () async {
    await storage.salvarPerfilPaciente(perfil);
    await storage.importar(plano);
    await storage.salvarRegistro(plano.id, '2026-10-05', 'agua', 2);
    await storage.importar(plano);
    expect((await storage.planoAtivo())!.id, plano.id);
    expect((await storage.registros(plano.id, '2026-10-05'))['agua'], 2);
  });
  test(
    'arquivo errado e mesmo-id adulterado não alteram planos registros e envios',
    () async {
      await storage.salvarPerfilPaciente(perfil);
      await storage.importar(plano);
      await storage.salvarRegistro(plano.id, '2026-10-05', 'agua', 3);
      await storage.registrarEnvio(
        plano.id,
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 5),
      );
      final antes = await storage.backupConteudo();
      for (final sameId in [true, false]) {
        final d = copiarDados(plano.data);
        d['paciente']['nome'] = 'Paciente Errado';
        if (!sameId) d['id'] = novoId();
        await expectLater(
          storage.importar(Plano.parse(jsonEncode(d))),
          throwsFormatException,
        );
        expect(await storage.backupConteudo(), antes);
      }
    },
  );
  test('planos sem nascimento não passam na importação', () async {
    await storage.salvarPerfilPaciente(perfil);
    final d = copiarDados(plano.data)..['versao'] = 1;
    (d['paciente'] as Map).remove('nascimento');
    await expectLater(
      storage.importar(Plano.parse(jsonEncode(d))),
      throwsFormatException,
    );
    expect(await storage.planos(), isEmpty);
  });
  test('cadastro persiste e faz parte da cópia de segurança', () async {
    await storage.salvarPerfilPaciente(perfil);
    await storage.importar(plano);
    final backup = await storage.backupConteudo();
    for (final t in ['planos', 'registros', 'envios', 'config']) {
      await database.delete(t);
    }
    await storage.restaurar(backup);
    expect((await storage.perfilPaciente())!.corresponde(plano), isTrue);
    expect((await storage.planoAtivo())!.id, plano.id);
  });
  test(
    'restaurar cópia de outro paciente não substitui o cadastro local',
    () async {
      await storage.salvarPerfilPaciente(perfil);
      await storage.importar(plano);
      final original = await storage.backupConteudo();
      final d = jsonDecode(original) as Map<String, dynamic>;
      (d['config'] as List).firstWhere(
        (r) => r['chave'] == 'perfil_paciente',
      )['valor'] = jsonEncode({
        'nome': 'Outra Pessoa',
        'nascimento': perfil.nascimento,
      });
      await expectLater(
        storage.restaurar(jsonEncode(d)),
        throwsFormatException,
      );
      expect(await storage.backupConteudo(), original);
    },
  );
  test('duplicação limpa nome e nascimento; exportação usa versão 3', () {
    final d = duplicarPlano(plano, 'Médica Teste', 'CRM Teste');
    expect(d['versao'], 3);
    expect(d['paciente'], {'nome': '', 'nascimento': ''});
    expect(() => Plano.parse(jsonEncode(d)), throwsFormatException);
    expect(
      Plano.parseBytes(utf8.encode(jsonEncode(plano.data))).nascimentoPaciente,
      perfil.nascimento,
    );
  });
}
