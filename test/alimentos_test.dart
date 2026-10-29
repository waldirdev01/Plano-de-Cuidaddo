import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/alimentos.dart';
import 'package:plano_de_cuidado/core/exportacao_pdf.dart';
import 'package:plano_de_cuidado/core/padrao_pdf.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'package:plano_de_cuidado/core/retorno_acompanhamento.dart';

import 'fixtures/pdf_texto.dart';
import 'fixtures/rascunho_conferido.dart';

void main() {
  late TabelaAlimentos t;
  setUpAll(() {
    t = TabelaAlimentos.padrao = TabelaAlimentos.deJson(
      File('assets/alimentos/taco.json').readAsStringSync(),
    );
  });
  ItemAlimento item(String nome, double g) => ItemAlimento(t.porNome(nome)!, g);

  test('tabela TACO embutida tem os valores da 4ª edição', () {
    expect(t.alimentos.length, greaterThan(500));
    final arroz = t.porNome('ARROZ,TIPO 1 , cozido')!;
    expect(arroz.por100.kcal, 128);
    expect(arroz.por100.carboidrato, 28.1);
    expect(arroz.grupo, 'carboidrato');
    expect(t.porNome('Batata, inglesa, cozida')!.grupo, 'carboidrato');
    expect(t.porNome('Frango, peito, sem pele, grelhado')!.grupo, 'proteina');
    expect(t.porNome('Alface, crespa, crua')!.grupo, 'livre');
  });

  test('troca mantém o macro principal do grupo, arredondada a 5 g', () {
    final arroz = item('Arroz, tipo 1, cozido', 100);
    expect(
      gramasEquivalentes(arroz, t.porNome('Batata, inglesa, cozida')!),
      235,
    );
    final frango = item('Frango, peito, sem pele, grelhado', 120);
    expect(
      gramasEquivalentes(
        frango,
        t.porNome('Ovo, de galinha, inteiro, cozido/10minutos')!,
      ),
      290,
    );
    final alface = item('Alface, crespa, crua', 40);
    expect(
      gramasEquivalentes(alface, t.porNome('Tomate, com semente, cru')!),
      40,
    );
    final trocas = t.trocasPara(arroz);
    expect(trocas.every((i) => i.alimento.grupo == 'carboidrato'), isTrue);
    expect(trocas.any((i) => i.alimento.id == arroz.alimento.id), isFalse);
    expect(trocas.every((i) => i.gramas >= 5 && i.gramas <= 1000), isTrue);
    final nomes = trocas.map((i) => i.alimento.nome).toList();
    expect(nomes, contains('Batata, inglesa, cozida'));
    expect(nomes, isNot(contains('Arroz, tipo 1, cru')));
    expect(nomes, isNot(contains('Alho, cru')));
    expect(t.porNome('Feijoada')!.grupo, 'preparado');
  });

  test('linha Alimentos do PDF exige nomes da tabela e gramas', () {
    final itens = t.lerLinhaPdf(
      'Arroz, tipo 1, cozido 100 g; Feijão, carioca, cozido 80g; Alface, crespa, crua 30,5 g',
    );
    expect(itens.map((i) => i.gramas), [100, 80, 30.5]);
    expect(
      () => t.lerLinhaPdf('Arroz cozido 100 g'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'mensagem',
          allOf(contains('fora da tabela'), contains('Arroz, tipo 1, cozido')),
        ),
      ),
    );
    expect(
      () => t.lerLinhaPdf('Arroz, tipo 1, cozido 4 colheres'),
      throwsFormatException,
    );
    expect(
      () => t.lerLinhaPdf(
        'Arroz, tipo 1, cozido 100 g; Arroz, tipo 1, cozido 50 g',
      ),
      throwsFormatException,
    );
  });

  test('alimentos do PDF chegam ao plano com a composição de cada um', () {
    final texto = textoPlanoPdfTeste.replaceFirst(
      'Prescricao: Alimentos e quantidades do plano fictício para o café.',
      'Prescricao: Alimentos e quantidades do plano fictício para o café.\n'
          'Alimentos: Pão, trigo, francês 50 g; Ovo, de galinha, inteiro, cozido/10minutos 100 g',
    );
    final r = rascunhoConferido();
    final lido = PadraoPdf.ler(texto, tabela: t);
    r.data['refeicoes'] = lido['refeicoes'];
    for (final key in (r.data['confirmacoes'] as Map).keys) {
      r.data['confirmacoes'][key] = true;
    }
    final plano = planoDoPdfConferido(r, profissional: 'M', registro: 'R');
    final cafe = plano.refeicoesPrescritas.first;
    final itens = validarAlimentos(cafe['alimentos']);
    expect(itens.first.alimento.nome, 'Pão, trigo, francês');
    expect(itens.first.nutrientes.kcal, 150);
    expect(plano.refeicoesPrescritas[1].containsKey('alimentos'), isFalse);
    final dados = jsonDecode(jsonEncode(plano.data)) as Map<String, dynamic>;
    ((dados['refeicoesPrescritas'] as List).first as Map)['alimentos'] = [
      {'id': 1, 'nome': 'X', 'grupo': 'inventado', 'gramas': 10, 'por100': {}},
    ];
    expect(() => Plano.parse(jsonEncode(dados)), throwsFormatException);
  });

  test('troca menos indicada é sinalizada e há opções melhores', () {
    final arroz = item('Arroz, tipo 1, cozido', 150);
    final trocas = t.trocasPara(arroz);
    ItemAlimento opcao(String nome) =>
        trocas.firstWhere((i) => i.alimento.nome == nome);
    expect(
      motivoMenosIndicada(
        opcao('Biscoito, doce, recheado com chocolate'),
        arroz,
      ),
      'ultraprocessado ou frito',
    );
    expect(
      motivoMenosIndicada(opcao('Batata, inglesa, cozida'), arroz),
      isNull,
    );
    final melhores = melhoresTrocas(trocas, arroz);
    expect(melhores, hasLength(3));
    expect(
      melhores.every((m) => motivoMenosIndicada(m, arroz) == null),
      isTrue,
    );
  });

  test('acompanhamento leva o que comeu, com as trocas do dia', () {
    final now = DateTime.now();
    final hoje = DateTime(now.year, now.month, now.day);
    final r = rascunhoConferido();
    r.campos['inicio'] = Plano.formatDia(
      hoje.subtract(const Duration(days: 1)),
    );
    r.campos['fim'] = Plano.formatDia(hoje.add(const Duration(days: 1)));
    r.campos['retorno'] = Plano.formatDia(hoje.add(const Duration(days: 2)));
    final meals = r.lista('refeicoes');
    meals[0]['alimentos'] = [
      for (final i in t.lerLinhaPdf(
        'Arroz, tipo 1, cozido 150 g; Feijão, carioca, cozido 100 g',
      ))
        i.toMap(),
    ];
    meals[1]['alimentos'] = [
      for (final i in t.lerLinhaPdf('Banana, prata, crua 80 g')) i.toMap(),
    ];
    final plano = planoDoPdfConferido(r, profissional: 'M', registro: 'R');
    final p0 = plano.refeicoesPrescritas[0]['id'] as String;
    final p1 = plano.refeicoesPrescritas[1]['id'] as String;
    final dia = Plano.formatDia(hoje);
    final batata = ItemAlimento(t.porNome('Batata, inglesa, cozida')!, 355);
    final retorno = RetornoAcompanhamento.criar(
      plano,
      {
        dia: {p0: 'feito', p1: 'nao_feito'},
      },
      trocas: {
        dia: {'$p0|0': batata.toMap()},
      },
      agora: now,
    );
    final comido = retorno.comido[dia] as Map<String, dynamic>;
    expect(comido.keys, [p0]);
    expect(comido[p0]['trocas'], [0]);
    expect(
      validarAlimentos(comido[p0]['alimentos']).first.alimento.nome,
      'Batata, inglesa, cozida',
    );
    final volta = RetornoAcompanhamento.parse(
      jsonEncode(retorno.data),
      agora: now,
    );
    expect(volta.comido, retorno.comido);
    final ruim = jsonDecode(jsonEncode(retorno.data)) as Map<String, dynamic>;
    ruim['comido'][dia][p0]['trocas'] = [7];
    expect(
      () => RetornoAcompanhamento.parse(jsonEncode(ruim), agora: now),
      throwsFormatException,
    );
    ruim['comido'][dia] = {'inexistente': comido[p0]};
    expect(
      () => RetornoAcompanhamento.parse(jsonEncode(ruim), agora: now),
      throwsFormatException,
    );
  });
}
