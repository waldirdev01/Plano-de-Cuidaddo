import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/armazenamento.dart';
import 'package:plano_de_cuidado/core/exportacao_pdf.dart';
import 'package:plano_de_cuidado/core/importacao_pdf.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixtures/rascunho_conferido.dart';

void main() {
  late Database database;
  late Directory dir;
  late ArquivosRascunhoPdf arquivos;
  late Armazenamento storage;
  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, _) => Armazenamento.criarEsquema(d),
      ),
    );
    dir = Directory.systemTemp.createTempSync('rascunhos-backup');
    arquivos = ArquivosRascunhoPdf(diretorio: dir);
    storage = Armazenamento.testing(database, rascunhosPdf: arquivos);
  });
  tearDown(() async {
    await database.close();
    dir.deleteSync(recursive: true);
  });

  void apagarRascunhos() {
    for (final f in dir.listSync()) {
      f.deleteSync();
    }
  }

  test(
    'backup leva o rascunho conferido e a restauração o devolve intacto',
    () async {
      final r = rascunhoConferido();
      await arquivos.salvar(r);
      final salvo = (await arquivos.listar()).single;
      final backup = await storage.backupConteudo();
      apagarRascunhos();
      expect(await arquivos.listar(), isEmpty);
      await storage.restaurar(backup);
      final volta = (await arquivos.listar()).single;
      expect(jsonEncode(volta.data), jsonEncode(salvo.data));
      expect(volta.estado, 'conferido');
      final plano = planoDoPdfConferido(
        volta,
        profissional: 'M',
        registro: 'R',
      );
      expect(plano.data['versao'], 4);
    },
  );

  test(
    'restaurar mantém rascunhos do aparelho que não estão na cópia',
    () async {
      await arquivos.salvar(rascunhoConferido());
      final backup = await storage.backupConteudo();
      final novo = rascunhoConferido();
      await arquivos.salvar(novo);
      await storage.restaurar(backup);
      expect((await arquivos.listar()).map((r) => r.id), contains(novo.id));
      expect(await arquivos.listar(), hasLength(2));
    },
  );

  test('rascunho danificado na cópia não restaura nada', () async {
    await arquivos.salvar(rascunhoConferido());
    await storage.setConfig('papel', 'profissional');
    final backup = await storage.backupConteudo();
    final d = jsonDecode(backup) as Map<String, dynamic>;
    (d['rascunhosPdf'] as List).add({'formato': 'rascunho-importacao-pdf'});
    await storage.setConfig('papel', 'paciente');
    final antes = await storage.backupConteudo();
    await expectLater(storage.restaurar(jsonEncode(d)), throwsFormatException);
    expect(await storage.backupConteudo(), antes);
  });

  test(
    'cópia antiga, sem rascunhos, não mexe nos rascunhos do aparelho',
    () async {
      await arquivos.salvar(rascunhoConferido());
      final antiga =
          jsonDecode(await storage.backupConteudo()) as Map<String, dynamic>
            ..remove('rascunhosPdf');
      apagarRascunhos();
      final local = rascunhoConferido();
      await arquivos.salvar(local);
      await storage.restaurar(jsonEncode(antiga));
      expect((await arquivos.listar()).single.id, local.id);
    },
  );
}
