import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/exportacao_pdf.dart';
import 'package:plano_de_cuidado/core/importacao_pdf.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'package:plano_de_cuidado/core/retorno_acompanhamento.dart';
import 'package:plano_de_cuidado/core/treino.dart';

import 'fixtures/rascunho_conferido.dart';

Map<String, dynamic> _bloco({
  int nivel = 2,
  String objetivo = 'perda',
  List<String> lim = const [],
  bool pp = false,
}) => PrescricaoTreino(
  nivel: nivel,
  objetivo: objetivo,
  limitacoes: lim,
  posParto: pp,
).toMap();

Plano _planoAtualComTreino() {
  final p = planoPdfTeste();
  final hoje = DateTime.now();
  p.data['inicio'] = Plano.formatDia(hoje.subtract(const Duration(days: 2)));
  p.data['fim'] = Plano.formatDia(hoje.add(const Duration(days: 2)));
  p.data['retorno']['data'] = Plano.formatDia(hoje.add(const Duration(days: 3)));
  p.data['treino'] = _bloco();
  return Plano.parse(jsonEncode(p.data));
}

void main() {
  group('bloco treino no plano', () {
    test('aceita bloco válido e expõe os parâmetros', () {
      final p = _planoAtualComTreino();
      final t = p.treino!;
      expect(t.nivel, 2);
      expect(t.objetivo, 'perda');
      expect(t.posParto, false);
    });

    test('recusa sem triagem negativa, pós-parto sem liberação e valores inválidos', () {
      Map<String, dynamic> base() => _bloco();
      for (final mudar in <void Function(Map<String, dynamic>)>[
        (m) => m.remove('triagemNegativa'),
        (m) => m['triagemNegativa'] = false,
        (m) {
          m['posParto'] = true;
          m.remove('liberacaoPosParto');
        },
        (m) => m['nivel'] = 4,
        (m) => m['objetivo'] = 'outro',
        (m) => m['limitacoes'] = ['x'],
        (m) => m['limitacoes'] = ['j', 'j'],
      ]) {
        final m = base();
        mudar(m);
        expect(() => PrescricaoTreino.validar(m), throwsFormatException);
      }
    });

    test('rascunho de PDF conferido exporta o treino no .plano v4', () {
      final r = rascunhoConferido();
      expect(planoDoPdfConferido(r, profissional: 'M', registro: 'R').treino, isNull);
      r.data['treino'] = _bloco(nivel: 1, objetivo: 'saude', lim: ['j']);
      final p = planoDoPdfConferido(r, profissional: 'M', registro: 'R');
      expect(p.data['versao'], 4);
      expect(p.treino!.nivel, 1);
      expect(p.treino!.limitacoes, ['j']);
      final relido = RascunhoPdf(jsonDecode(jsonEncode(r.data)) as Map<String, dynamic>);
      relido.data['treino'] = {'nivel': 9};
      expect(
        () => planoDoPdfConferido(relido, profissional: 'M', registro: 'R'),
        throwsFormatException,
      );
    });

    test('Plano.parse recusa plano com treino inválido', () {
      final p = planoPdfTeste();
      p.data['treino'] = {'nivel': 1, 'objetivo': 'perda'};
      expect(() => Plano.parse(jsonEncode(p.data)), throwsFormatException);
    });
  });

  group('motor de treino', () {
    test('é determinístico', () {
      final presc = PrescricaoTreino(nivel: 3, objetivo: 'recomp');
      const esc = EscolhasTreino(local: 'a', dias: 5, minutos: 60);
      String chave(ProgramaTreino p) => [
        for (final d in p.dias)
          '${d.indice}${d.tipo}${d.titulo}${[for (final i in d.itens) '${i.nome}${[for (final s in i.semanas) '${s.series}${s.texto}']}']}',
      ].join('|');
      expect(chave(montarTreino(presc, esc)), chave(montarTreino(presc, esc)));
    });

    test('todas as combinações respeitam as regras de segurança', () {
      var combinacoes = 0;
      for (final n in [1, 2, 3]) {
        for (final o in objetivosTreino.keys) {
          for (final local in locaisForcaTreino.keys) {
            for (final aero in locaisAerobicoTreino.keys) {
              for (final d in [2, 3, 4, 5, 6]) {
                for (final t in [20, 30, 45, 60]) {
                  for (final lim in [
                    <String>[],
                    ['j'],
                    ['o'],
                    ['l'],
                    ['j', 'o', 'l'],
                  ]) {
                    for (final pp in [false, true]) {
                      combinacoes++;
                      final p = montarTreino(
                        PrescricaoTreino(
                          nivel: n,
                          objetivo: o,
                          limitacoes: lim,
                          posParto: pp,
                        ),
                        EscolhasTreino(local: local, aerobico: aero, dias: d, minutos: t),
                      );
                      final ctx = 'n=$n o=$o $local $aero d=$d t=$t lim=$lim pp=$pp';
                      expect(p.dias.length, d, reason: ctx);
                      var inferiorAnterior = false;
                      var indiceAnterior = -9;
                      for (final dia in p.dias) {
                        final inferior = dia.tipo == 'S' &&
                            (dia.titulo.startsWith('Parte inferior') ||
                                dia.titulo.startsWith('Corpo todo'));
                        if (inferior && inferiorAnterior && dia.indice - indiceAnterior == 1) {
                          fail('treino de pernas em dias seguidos: $ctx');
                        }
                        inferiorAnterior = inferior;
                        indiceAnterior = dia.indice;
                        if (dia.tipo != 'S') continue;
                        expect(dia.itens.length, greaterThanOrEqualTo(3), reason: ctx);
                        expect(
                          dia.itens.map((i) => i.nome).toSet().length,
                          dia.itens.length,
                          reason: 'exercício repetido: $ctx',
                        );
                        for (final i in dia.itens) {
                          if (i.emPar && i.unilateral) {
                            fail('unilateral em bi-set: $ctx');
                          }
                          expect(i.semanas.length, 4);
                        }
                      }
                      if (pp) {
                        for (final dia in p.dias.where((x) => x.tipo == 'C')) {
                          expect(
                            dia.intervalado.every((x) => x == null),
                            true,
                            reason: 'HIIT no pós-parto: $ctx',
                          );
                        }
                      }
                      if (n == 1) {
                        for (final dia in p.dias.where((x) => x.tipo == 'C')) {
                          expect(
                            dia.intervalado.every((x) => x == null),
                            true,
                            reason: 'HIIT em iniciante: $ctx',
                          );
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      expect(combinacoes, 21600);
    });

    test('limitação de joelho não recebe agachamento livre nem búlgaro', () {
      final p = montarTreino(
        PrescricaoTreino(nivel: 3, objetivo: 'recomp', limitacoes: ['j']),
        const EscolhasTreino(local: 'a', dias: 4, minutos: 60),
      );
      final nomes = [for (final d in p.dias) for (final i in d.itens) i.nome.toLowerCase()];
      expect(nomes.any((n) => n.contains('búlgaro')), false);
      expect(nomes.any((n) => n.contains('livre ou no smith')), false);
    });

    test('cabe no tempo e usa pares só de empurrar com puxar', () {
      final p = montarTreino(
        PrescricaoTreino(nivel: 2, objetivo: 'saude'),
        const EscolhasTreino(local: 'a', dias: 3, minutos: 30),
      );
      for (final d in p.dias.where((x) => x.tipo == 'S')) {
        expect(d.estimativaMin, lessThanOrEqualTo(32));
      }
    });
  });

  group('registro e sugestão de carga', () {
    RegistroExercicio reg(List<(bool, int?, double?)> series, {int? sobraram}) =>
        RegistroExercicio(
          nome: 'Agachamento',
          series: [for (final s in series) SerieRegistro(feita: s.$1, reps: s.$2, kg: s.$3)],
          sobraram: sobraram,
        );

    test('sobe quando todas as séries chegam ao topo da faixa', () {
      final s = sugerirCarga(reg([(true, 12, 40), (true, 12, 40), (true, 12, 40)]), 3, '8–12')!;
      expect(s.direcao, 'sobe');
      expect(s.kg, 41.5);
    });

    test('desce quando alguma série fica abaixo da faixa', () {
      final s = sugerirCarga(reg([(true, 8, 30), (true, 5, 30), (true, 8, 30)]), 3, '8–12')!;
      expect(s.direcao, 'desce');
      expect(s.kg, 28);
    });

    test('desce quando foi até a falha, mesmo com repetições na faixa', () {
      final s = sugerirCarga(reg([(true, 10, 20), (true, 10, 20), (true, 10, 20)], sobraram: 0), 3, '8–12')!;
      expect(s.direcao, 'desce');
    });

    test('mantém no meio da faixa e não sugere sem série feita', () {
      final s = sugerirCarga(reg([(true, 10, 20), (true, 10, 20), (true, 10, 20)]), 3, '8–12')!;
      expect(s.direcao, 'mantem');
      expect(sugerirCarga(reg([(false, 12, 20)]), 3, '8–12'), isNull);
    });

    test('sem carga registrada sugere mais repetições, não um número', () {
      final s = sugerirCarga(reg([(true, 12, null), (true, 12, null), (true, 12, null)]), 3, '8–12')!;
      expect(s.direcao, 'sobe');
      expect(s.kg, isNull);
    });

    test('valida a forma dos registros', () {
      expect(registroTreinoValido('trn_agachamento', reg([(true, 10, 20)]).toMap()), true);
      expect(registroTreinoValido('trn_agachamento', {'nome': 'x', 'series': 'não'}), false);
      expect(registroTreinoValido('outro_campo', reg([(true, 10, 20)]).toMap()), false);
      expect(registroTreinoValido(campoAerobicoTreino, {'feito': true, 'min': 30}), true);
      expect(registroTreinoValido(campoAerobicoTreino, {'feito': 'sim'}), false);
    });

    test('semana do programa conta do início e para na quarta', () {
      final i = DateTime(2026, 10, 1);
      expect(semanaDoPrograma(i, DateTime(2026, 10, 1)), 0);
      expect(semanaDoPrograma(i, DateTime(2026, 10, 8)), 1);
      expect(semanaDoPrograma(i, DateTime(2026, 11, 20)), 3);
    });
  });

  group('devolução com treino', () {
    test('inclui registros de treino e os revalida ao abrir', () {
      final p = _planoAtualComTreino();
      final hoje = Plano.formatDia(DateTime.now());
      final ex = RegistroExercicio(
        nome: 'Supino em máquina',
        series: [SerieRegistro(feita: true, reps: 12, kg: 30)],
      ).toMap();
      final r = RetornoAcompanhamento.criar(p, {
        hoje: {'trn_${chaveExercicio('Supino em máquina')}': ex, campoAerobicoTreino: {'feito': true, 'min': 30}},
      });
      expect(r.registrosTreino[hoje], isNotEmpty);
      final lido = RetornoAcompanhamento.parse(jsonEncode(r.data));
      expect((lido.registrosTreino[hoje] as Map).length, 2);
    });

    test('plano sem treino ignora registros trn_ e recusa envelope com treino', () {
      final p = planoPdfTeste();
      final hoje = DateTime.now();
      p.data['inicio'] = Plano.formatDia(hoje.subtract(const Duration(days: 2)));
      p.data['fim'] = Plano.formatDia(hoje.add(const Duration(days: 2)));
      p.data['retorno']['data'] = Plano.formatDia(hoje.add(const Duration(days: 3)));
      final semTreino = Plano.parse(jsonEncode(p.data));
      final dia = Plano.formatDia(hoje);
      final r = RetornoAcompanhamento.criar(semTreino, {
        dia: {campoAerobicoTreino: {'feito': true, 'min': 10}},
      });
      expect(r.data.containsKey('treino'), false);
      final adulterado = jsonDecode(jsonEncode(r.data)) as Map<String, dynamic>;
      adulterado['treino'] = {dia: {campoAerobicoTreino: {'feito': true, 'min': 10}}};
      expect(() => RetornoAcompanhamento.parse(jsonEncode(adulterado)), throwsFormatException);
    });

    test('recusa registro de treino malformado', () {
      final p = _planoAtualComTreino();
      final dia = Plano.formatDia(DateTime.now());
      final r = RetornoAcompanhamento.criar(p, {
        dia: {campoAerobicoTreino: {'feito': true, 'min': 10}},
      });
      final ruim = jsonDecode(jsonEncode(r.data)) as Map<String, dynamic>;
      (ruim['treino'] as Map)[dia] = {'trn_x': {'nome': '', 'series': []}};
      expect(() => RetornoAcompanhamento.parse(jsonEncode(ruim)), throwsFormatException);
    });
  });
}
