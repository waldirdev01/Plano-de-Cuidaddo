import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/edicao_plano.dart';
import 'package:plano_de_cuidado/core/exportacao_pdf.dart';
import 'package:plano_de_cuidado/core/importacao_pdf.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'package:plano_de_cuidado/core/pre_consulta.dart';

import 'fixtures/rascunho_conferido.dart';

Map<String, dynamic> _plano({Object? reavaliacao}) {
  final d = novoPlano('Médica Exemplo', 'CRM TESTE');
  d['paciente'] = {'nome': 'Ana Exemplo', 'nascimento': '1990-01-01'};
  d['inicio'] = '2026-11-01';
  d['retorno'] = {'data': '2026-11-30', 'hora': '13:30'};
  if (reavaliacao != null) d['reavaliacao'] = reavaliacao;
  return d;
}

void main() {
  group('pedido de reavaliação no .plano', () {
    test('plano sem o campo não pede reavaliação', () {
      expect(Plano.parse(jsonEncode(_plano())).reavaliacao, isNull);
    });

    test('lê itens e datas pedidos pela médica', () {
      final p = Plano.parse(
        jsonEncode(
          _plano(
            reavaliacao: {
              'itens': ['medidas', 'humor'],
              'datas': ['2026-11-01', '2026-11-15', '2026-11-30'],
            },
          ),
        ),
      );
      expect(p.reavaliacao!.itens, ['medidas', 'humor']);
      expect(p.reavaliacao!.datas, hasLength(3));
      expect(p.reavaliacao!.respostasVazias().keys, ['medidas', 'emocional']);
    });

    test('recusa pedidos fora do contrato', () {
      for (final r in <Object>[
        {
          'itens': <String>[],
          'datas': ['2026-11-15'],
        },
        {
          'itens': ['peso'],
          'datas': ['2026-11-15'],
        },
        {
          'itens': ['sono', 'sono'],
          'datas': ['2026-11-15'],
        },
        {
          'itens': ['sono'],
          'datas': <String>[],
        },
        {
          'itens': ['sono'],
          'datas': ['2026-10-31'],
        },
        {
          'itens': ['sono'],
          'datas': ['2026-12-01'],
        },
        {
          'itens': ['sono'],
          'datas': ['2026-11-20', '2026-11-10'],
        },
        {
          'itens': ['sono'],
          'datas': ['2026-11-10', '2026-11-10'],
        },
        {
          'itens': ['sono'],
          'datas': ['15/11/2026'],
        },
        {
          'itens': ['sono'],
          'datas': [
            for (var d = 1; d <= 13; d++) '2026-11-${'$d'.padLeft(2, '0')}',
          ],
        },
        {
          'itens': ['sono'],
          'datas': ['2026-11-15'],
          'extra': 1,
        },
        'medidas',
      ]) {
        expect(
          () => Plano.parse(jsonEncode(_plano(reavaliacao: r))),
          throwsFormatException,
          reason: '$r',
        );
      }
    });

    test('reavaliação respondida segue os itens do pedido', () {
      final p = Plano.parse(
        jsonEncode(
          _plano(
            reavaliacao: {
              'itens': ['medidas'],
              'datas': ['2026-11-15'],
            },
          ),
        ),
      );
      final respostas = p.reavaliacao!.respostasVazias();
      respostas['medidas']['peso'] = 70.5;
      final a = Reavaliacao.criar(
        PerfilPaciente(nome: 'Ana Exemplo', nascimento: '1990-01-01'),
        planoId: p.id,
        itens: p.reavaliacao!.itens,
        respostas: respostas,
      );
      expect(Reavaliacao.parse(jsonEncode(a.data)).medidas!['peso'], 70.5);
    });
  });

  group('reavaliação na conferência do PDF', () {
    test('vai no .plano exportado', () {
      final r = rascunhoConferido();
      final inicio = r.campos['inicio'] as String;
      r.data['reavaliacao'] = {
        'itens': ['sono'],
        'datas': [inicio],
      };
      expect(r.validarConferencia(), isEmpty);
      final p = planoDoPdfConferido(r, profissional: 'M', registro: 'R');
      expect(p.reavaliacao!.datas, [inicio]);
    });

    test('data fora do período aparece como pendência e não exporta', () {
      final r = rascunhoConferido();
      r.data['reavaliacao'] = {
        'itens': ['sono'],
        'datas': ['2000-01-01'],
      };
      expect(
        r.validarConferencia(),
        contains(
          'As datas da reavaliação devem ficar entre o início do plano e o retorno.',
        ),
      );
      expect(
        () => planoDoPdfConferido(r, profissional: 'M', registro: 'R'),
        throwsFormatException,
      );
    });

    test('pedido danificado no rascunho impede a restauração', () {
      final r = rascunhoConferido();
      r.data['reavaliacao'] = {
        'itens': ['peso'],
        'datas': ['2026-11-15'],
      };
      expect(
        () => ArquivosRascunhoPdf.validarParaRestaurar(
          jsonDecode(jsonEncode(r.data)),
        ),
        throwsFormatException,
      );
    });
  });
}
