import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/armazenamento.dart';
import 'package:plano_de_cuidado/core/pre_consulta.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final ana = PerfilPaciente(
  nome: 'Ana Exemplo Completo',
  nascimento: '1990-01-01',
);
final agora = DateTime(2026, 10, 27, 10);

Map<String, dynamic> respostasAna() {
  final r = PreConsulta.respostasVazias();
  r['ident'] = {
    'cpf': '123.456.789-00',
    'sexo': 'F',
    'email': 'ana@exemplo.com',
    'nomeMae': 'Maria Exemplo',
    'cep': '70000-000',
    'logradouro': 'Quadra 1, casa 2, Brasília/DF',
  };
  r['saude'] = {
    'comorbidades': ['Diabetes tipo 2', comorbidadeSop],
    'detalhes': {'Diabetes tipo 2': 'desde 2020'},
    'outras': '',
    'cirurgias': 'cesárea em 2018',
    'alergias': '',
    'historiaFamiliar': ['Câncer antes dos 50 anos'],
    'famDetalhes': {'Câncer antes dos 50 anos': 'mãe, mama, 45 anos'},
  };
  r['medidas'] = {'peso': 78.5, 'altura': 165, 'cintura': 92, 'quadril': 104};
  r['alimentacao'] = {'emocional': 7};
  r['sono'] = {
    'horas': 6.5,
    'restaurador': 'Parcialmente',
    'acordaNoite': 'Sim',
    'acordaVezes': 2,
    'acordaMotivo': 'banheiro',
    'ronco': 'Não sei',
    'pausas': 'Não',
  };
  r['emocional'] = {
    'phq2': [1, 0],
    'gad2': [2, null],
  };
  r['habitos'] = {'alcool': 1, 'tabagismo': 'Nunca fumei', 'apoio': 8};
  r['hormonal'] = {
    'dum': '2026-10-10',
    'ciclo': 'Regular',
    'menopausa': 'Não',
    'hormonio': '',
  };
  return r;
}

PreConsulta preConsultaAna({PerfilPaciente? paciente}) => PreConsulta.criar(
  paciente ?? ana,
  respostasAna(),
  termoAceitoEm: agora.subtract(const Duration(minutes: 9)),
  agora: agora,
);

/// Parses a changed copy of [base]; [mudar] edits the decoded JSON.
void recusa(
  Map<String, dynamic> base,
  void Function(Map<String, dynamic> d) mudar, {
  bool reavaliacao = false,
}) {
  final d = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
  mudar(d);
  final source = jsonEncode(d);
  expect(
    () => reavaliacao
        ? Reavaliacao.parse(source, agora: agora)
        : PreConsulta.parse(source, agora: agora),
    throwsFormatException,
  );
}

void main() {
  group('pré-consulta', () {
    test('ida e volta preserva respostas e calcula IMC e RCQ como número', () {
      final p = preConsultaAna();
      final lido = PreConsulta.parse(jsonEncode(p.data), agora: agora);
      expect(lido.nomePaciente, 'Ana Exemplo Completo');
      expect(lido.respostas['saude']['comorbidades'], contains(comorbidadeSop));
      expect(lido.imc, 28.8);
      expect(lido.relacaoCinturaQuadril, 0.88);
      expect(lido.data['termo']['versao'], termoPreConsultaVersao);
    });

    test('respostas vazias são aceitas e não calculam medidas', () {
      final p = PreConsulta.criar(
        ana,
        PreConsulta.respostasVazias(),
        termoAceitoEm: agora,
        agora: agora,
      );
      expect(p.imc, isNull);
      expect(p.relacaoCinturaQuadril, isNull);
    });

    test('recusa arquivo fora do contrato', () {
      final base = preConsultaAna().data;
      recusa(base, (d) => d['formato'] = 'plano-de-cuidado');
      recusa(base, (d) => d['versao'] = 2);
      recusa(base, (d) => d['extra'] = true);
      recusa(base, (d) => d['id'] = 'curto');
      recusa(base, (d) => d['termo']['versao'] = '01/01/2020');
      recusa(
        base,
        (d) => d['termo']['aceitoEm'] = agora
            .add(const Duration(hours: 1))
            .toIso8601String(),
      );
      recusa(base, (d) => d['paciente']['nome'] = 'Ana');
      recusa(base, (d) => d['paciente']['nascimento'] = '2999-01-01');
      recusa(base, (d) => d['respostas']['ident']['cpf'] = '12345678900');
      recusa(base, (d) => d['respostas']['ident']['cep'] = '7000');
      recusa(base, (d) => d['respostas']['ident']['sexo'] = 'X');
      recusa(base, (d) => d['respostas']['ident']['novo'] = '');
    });

    test('recusa respostas clínicas inválidas', () {
      final base = preConsultaAna().data;
      recusa(
        base,
        (d) => (d['respostas']['saude']['comorbidades'] as List).add('Gripe'),
      );
      recusa(
        base,
        (d) => d['respostas']['saude']['detalhes']['Problema nos rins'] = 'x',
      );
      recusa(base, (d) => d['respostas']['medidas']['peso'] = 7850);
      recusa(base, (d) => d['respostas']['medidas']['altura'] = '165');
      recusa(base, (d) => d['respostas']['emocional']['phq2'] = [4, 0]);
      recusa(base, (d) => d['respostas']['emocional']['gad2'] = [1]);
      recusa(base, (d) => d['respostas']['habitos']['alcool'] = 5);
      recusa(base, (d) => d['respostas']['habitos']['apoio'] = 11);
      recusa(base, (d) => d['respostas']['alimentacao']['emocional'] = 7.5);
      recusa(base, (d) => d['respostas']['sono']['horas'] = 30);
      recusa(base, (d) => d['respostas']['sono']['acordaNoite'] = 'Não');
      recusa(base, (d) => d['respostas']['hormonal']['dum'] = '2026-12-01');
    });

    test('SOP e saúde hormonal só valem para sexo feminino', () {
      final base = preConsultaAna().data;
      recusa(base, (d) {
        d['respostas']['ident']['sexo'] = 'M';
        (d['respostas']['saude']['comorbidades'] as List).remove(
          comorbidadeSop,
        );
      });
      final masculino = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
      final r = masculino['respostas'] as Map<String, dynamic>;
      r['ident']['sexo'] = 'M';
      (r['saude']['comorbidades'] as List).remove(comorbidadeSop);
      r['hormonal'] = PreConsulta.respostasVazias()['hormonal'];
      expect(
        PreConsulta.parse(jsonEncode(masculino), agora: agora).id,
        base['id'],
      );
      recusa(masculino, (d) {
        (d['respostas']['saude']['comorbidades'] as List).add(comorbidadeSop);
      });
    });
  });

  group('reavaliação', () {
    Reavaliacao medidasEHumor() => Reavaliacao.criar(
      ana,
      planoId: 'plano-ana',
      itens: ['medidas', 'humor'],
      respostas: {
        'medidas': {'peso': 75, 'altura': 165, 'cintura': 88, 'quadril': 102},
        'emocional': {
          'phq2': [0, 0],
          'gad2': [1, 1],
        },
      },
      agora: agora,
    );

    test('aceita só as seções pedidas e recalcula IMC', () {
      final r = medidasEHumor();
      final lido = Reavaliacao.parse(jsonEncode(r.data), agora: agora);
      expect(lido.itens, ['medidas', 'humor']);
      expect(lido.imc, 27.5);
      expect(lido.relacaoCinturaQuadril, 0.86);
    });

    test('sem medidas pedidas não calcula IMC', () {
      final r = Reavaliacao.criar(
        ana,
        planoId: 'plano-ana',
        itens: ['sono'],
        respostas: {'sono': sonoVazio()},
        agora: agora,
      );
      expect(r.imc, isNull);
    });

    test('recusa itens e seções fora do pedido', () {
      final base = medidasEHumor().data;
      recusa(base, (d) => d['itens'] = [], reavaliacao: true);
      recusa(
        base,
        (d) => d['itens'] = ['medidas', 'medidas'],
        reavaliacao: true,
      );
      recusa(base, (d) => d['itens'] = ['medidas', 'peso'], reavaliacao: true);
      recusa(
        base,
        (d) => d['respostas']['sono'] = sonoVazio(),
        reavaliacao: true,
      );
      recusa(
        base,
        (d) => (d['respostas'] as Map).remove('emocional'),
        reavaliacao: true,
      );
      recusa(base, (d) => d['planoId'] = '', reavaliacao: true);
      recusa(
        base,
        (d) => d['formato'] = PreConsulta.formato,
        reavaliacao: true,
      );
    });
  });

  group('histórico local', () {
    late Database database;
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
      storage = Armazenamento.testing(database);
    });
    tearDown(() => database.close());

    test(
      'agrupa por nome e nascimento, mesmo com acento ou caixa diferente',
      () async {
        expect(
          await storage.guardarPreConsulta(preConsultaAna(), agora: agora),
          isTrue,
        );
        final semAcento = preConsultaAna(
          paciente: PerfilPaciente(
            nome: 'ANA  exemplo completo',
            nascimento: '1990-01-01',
          ),
        );
        expect(
          await storage.guardarPreConsulta(semAcento, agora: agora),
          isTrue,
        );
        final outra = preConsultaAna(
          paciente: PerfilPaciente(
            nome: 'Ana Exemplo Completo',
            nascimento: '1991-01-01',
          ),
        );
        await storage.guardarPreConsulta(outra, agora: agora);
        final pacientes = await storage.pacientes();
        expect(pacientes, hasLength(2));
        final daAna = pacientes.firstWhere((p) => p.nascimento == '1990-01-01');
        expect(await storage.preConsultasDoPaciente(daAna.id), hasLength(2));
      },
    );

    test(
      'receber o mesmo arquivo de novo não duplica; conteúdo trocado é recusado',
      () async {
        final p = preConsultaAna();
        expect(await storage.guardarPreConsulta(p, agora: agora), isTrue);
        expect(await storage.guardarPreConsulta(p, agora: agora), isFalse);
        final alterado = jsonDecode(jsonEncode(p.data)) as Map<String, dynamic>;
        alterado['respostas']['alimentacao']['emocional'] = 1;
        await expectLater(
          storage.guardarPreConsulta(
            PreConsulta.parse(jsonEncode(alterado), agora: agora),
            agora: agora,
          ),
          throwsFormatException,
        );
        final id = (await storage.pacientes()).single.id;
        expect(await storage.preConsultasDoPaciente(id), hasLength(1));
      },
    );

    test('reavaliação entra na ficha da mesma paciente', () async {
      await storage.guardarPreConsulta(preConsultaAna(), agora: agora);
      final r = Reavaliacao.criar(
        ana,
        planoId: 'plano-ana',
        itens: ['sono'],
        respostas: {'sono': sonoVazio()},
        agora: agora,
      );
      expect(await storage.guardarReavaliacao(r, agora: agora), isTrue);
      final id = (await storage.pacientes()).single.id;
      expect((await storage.reavaliacoesDoPaciente(id)).single.id, r.id);
    });

    test(
      'backup e restauração levam o histórico; cópia antiga limpa o histórico',
      () async {
        await storage.guardarPreConsulta(preConsultaAna(), agora: agora);
        final backup = await storage.backupConteudo();
        final antiga = jsonDecode(backup) as Map<String, dynamic>
          ..remove('pacientes')
          ..remove('preConsultas')
          ..remove('reavaliacoes');
        await storage.restaurar(jsonEncode(antiga));
        expect(await storage.pacientes(), isEmpty);
        await storage.restaurar(backup);
        final id = (await storage.pacientes()).single.id;
        expect(await storage.preConsultasDoPaciente(id), hasLength(1));
        expect(await storage.backupConteudo(), backup);
      },
    );

    test('cópia com histórico inconsistente não restaura nada', () async {
      await storage.guardarPreConsulta(preConsultaAna(), agora: agora);
      final backup = await storage.backupConteudo();
      final d = jsonDecode(backup) as Map<String, dynamic>;
      (d['pacientes'] as List).single['nascimento'] = '1980-05-05';
      await expectLater(
        storage.restaurar(jsonEncode(d)),
        throwsFormatException,
      );
      expect(await storage.backupConteudo(), backup);
    });

    test(
      'banco da versão anterior ganha as tabelas sem perder dados',
      () async {
        final antigo = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        await antigo.execute(
          'CREATE TABLE config(chave TEXT PRIMARY KEY, valor TEXT NOT NULL)',
        );
        await antigo.insert('config', {
          'chave': 'papel',
          'valor': 'profissional',
        });
        await Armazenamento.criarHistorico(antigo);
        final s = Armazenamento.testing(antigo);
        expect(await s.papel(), 'profissional');
        expect(
          await s.guardarPreConsulta(preConsultaAna(), agora: agora),
          isTrue,
        );
        await antigo.close();
      },
    );
  });
}
