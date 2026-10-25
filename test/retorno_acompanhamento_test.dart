import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/armazenamento.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'package:plano_de_cuidado/core/retorno_acompanhamento.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fixtures/rascunho_conferido.dart';

Plano planoAtual() {
  final p = planoPdfTeste();
  final hoje = DateTime.now();
  p.data['inicio'] = Plano.formatDia(hoje.subtract(const Duration(days: 2)));
  p.data['fim'] = Plano.formatDia(hoje.add(const Duration(days: 2)));
  p.data['retorno']['data'] = Plano.formatDia(
    hoje.add(const Duration(days: 3)),
  );
  return Plano.parse(jsonEncode(p.data));
}

void main() {
  test(
    'exporta cumulativo sem PDF, notas livres ou link; nunca inventa ausência',
    () {
      final p = planoAtual();
      final hoje = Plano.formatDia(DateTime.now());
      final agua = p.metas.last['id'] as String;
      final refeicao = p.camposRefeicoes.first['id'] as String;
      final r = RetornoAcompanhamento.criar(p, {
        hoje: {agua: 1.5, refeicao: 'nao_feito', 'campo_antigo': 10},
        Plano.formatDia(p.fim): {agua: 2},
        Plano.formatDia(p.inicio): {agua: null},
      });
      expect(r.data['de'], Plano.formatDia(p.inicio));
      expect(r.data['ate'], hoje);
      expect(r.registros, {
        hoje: {agua: 1.5, refeicao: 'nao_feito'},
      });
      expect(r.quantidadeRegistros, 2);
      expect(r.plano.data.containsKey('pdf'), false);
      expect(r.plano.data.containsKey('secoes'), false);
      expect(r.plano.data['linkMonteSeuPrato'], '');
      expect(p.data.containsKey('pdf'), true);
      expect(() => Plano.parse(jsonEncode(r.data)), throwsFormatException);
      expect(RetornoAcompanhamento.parse(jsonEncode(r.data)).id, r.id);
    },
  );

  test('distingue feito, não feito, dispensa, zero e falta de confirmação', () {
    final p = planoAtual();
    final hoje = Plano.formatDia(DateTime.now());
    final valores = <String, dynamic>{
      p.camposRefeicoes[0]['id'] as String: 'feito',
      p.camposRefeicoes[1]['id'] as String: 'nao_feito',
      p.camposRefeicoes[2]['id'] as String: 'dispensado',
      p.metas.last['id'] as String: 0,
    };
    final r = RetornoAcompanhamento.criar(p, {hoje: valores});
    expect(r.registros[hoje], valores);
    expect(
      (r.registros[hoje] as Map).containsKey(p.camposRefeicoes[3]['id']),
      false,
    );
    final novo = RetornoAcompanhamento.criar(p, {
      hoje: {...valores, p.camposRefeicoes[1]['id'] as String: 'feito'},
    });
    expect(novo.id, isNot(r.id));
    expect((r.registros[hoje] as Map)[p.camposRefeicoes[1]['id']], 'nao_feito');
  });

  test(
    'recusa antes do início e corta exportação após término sem incluir dias futuros',
    () {
      final p = planoAtual();
      expect(
        () => RetornoAcompanhamento.criar(
          p,
          {},
          agora: p.inicio.subtract(const Duration(days: 1)),
        ),
        throwsFormatException,
      );
      final r = RetornoAcompanhamento.criar(
        p,
        {},
        agora: p.fim.add(const Duration(days: 5)),
      );
      expect(r.ate, p.fim);
      expect(r.quantidadeRegistros, 0);
    },
  );

  test(
    'valida versão, limites, período, campos e tipos, sem aceitar corrompidos',
    () {
      final p = planoAtual();
      final dia = Plano.formatDia(DateTime.now());
      final r = RetornoAcompanhamento.criar(p, {});
      for (final editar in <void Function(Map<String, dynamic>)>[
        (d) => d['versao'] = 2,
        (d) => d['id'] = '../nao',
        (d) => d['plano']['paciente']['nascimento'] = 'inválido',
        (d) => d['de'] = Plano.formatDia(
          p.inicio.subtract(const Duration(days: 1)),
        ),
        (d) => d['ate'] = Plano.formatDia(p.fim.add(const Duration(days: 1))),
        (d) => d['ate'] = Plano.formatDia(p.fim),
        (d) => d['exportadoEm'] = 'quebrado',
        (d) => d['registros'] = [],
        (d) => d['registros'] = {'2026-02-30': {}},
        (d) => d['registros'] = {
          dia: {'desconhecido': true},
        },
        (d) => d['registros'] = {
          dia: {p.metas.last['id']: -1},
        },
        (d) => d['registros'] = {
          dia: {p.metas.last['id']: '1,5'},
        },
        (d) => d['registros'] = {
          dia: {p.camposRefeicoes.first['id']: true},
        },
        (d) => d['registros'] = {
          dia: {p.camposRefeicoes.first['id']: 'talvez'},
        },
      ]) {
        final d = jsonDecode(jsonEncode(r.data)) as Map<String, dynamic>;
        editar(d);
        expect(
          () => RetornoAcompanhamento.parse(jsonEncode(d)),
          throwsFormatException,
        );
      }
      expect(
        () => RetornoAcompanhamento.parse(
          ' ' * (RetornoAcompanhamento.limiteBytes + 1),
        ),
        throwsFormatException,
      );
      expect(
        () => RetornoAcompanhamento.parse('%PDF-x'),
        throwsFormatException,
      );
    },
  );

  test(
    'destinatária exige nome e registro, sem depender do perfil paciente',
    () {
      final r = RetornoAcompanhamento.criar(planoAtual(), {});
      r.conferirProfissional('Médica Exemplo', 'CRM TESTE');
      expect(
        () => r.conferirProfissional('Médica Exemplo', 'CRM OUTRO'),
        throwsFormatException,
      );
      expect(
        () => r.conferirProfissional('Outra Médica', 'CRM TESTE'),
        throwsFormatException,
      );
      expect(() => r.conferirProfissional('', ''), throwsFormatException);
    },
  );

  test(
    'recebimento separado, idempotente, não substitui registros; backup conserva retornos',
    () async {
      sqfliteFfiInit();
      final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await Armazenamento.criarEsquema(sql);
      final db = Armazenamento.testing(sql);
      try {
        final p = planoAtual();
        await db.salvarPerfilPaciente(
          PerfilPaciente(
            nome: p.nomePaciente,
            nascimento: p.nascimentoPaciente!,
          ),
        );
        await db.importar(p);
        final hoje = Plano.formatDia(DateTime.now());
        final agua = p.metas.last['id'] as String;
        await db.salvarRegistro(p.id, hoje, agua, 2.5);
        final r = RetornoAcompanhamento.criar(p, {
          hoje: {agua: 0},
        });
        expect(() => db.guardarRetorno(r), throwsFormatException);
        await db.setConfig('profissional_nome', 'Médica Exemplo');
        await db.setConfig('profissional_registro', 'CRM TESTE');
        expect(await db.guardarRetorno(r), true);
        expect(await db.guardarRetorno(r), false);
        expect(await db.retornosRecebidos(), hasLength(1));
        expect(await db.registros(p.id, hoje), {agua: 2.5});
        expect((await db.planoAtivo())!.data, p.data);
        final adulterado =
            jsonDecode(jsonEncode(r.data)) as Map<String, dynamic>;
        adulterado['registros'][hoje][agua] = 1;
        expect(
          () => db.guardarRetorno(
            RetornoAcompanhamento.parse(jsonEncode(adulterado)),
          ),
          throwsFormatException,
        );
        final novo = RetornoAcompanhamento.criar(p, {
          hoje: {agua: 3},
        });
        await db.guardarRetorno(novo);
        expect(await db.retornosRecebidos(), hasLength(2));
        final backup = await db.backupConteudo();
        await db.restaurar(backup);
        expect(await db.retornosRecebidos(), hasLength(2));
        expect(await db.registros(p.id, hoje), {agua: 2.5});
        await db.setConfig('profissional_registro', 'OUTRO');
        expect(await db.retornosRecebidos(), isEmpty);
      } finally {
        await sql.close();
      }
    },
  );
}
