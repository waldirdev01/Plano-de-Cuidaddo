import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/alimentacao.dart';
import 'package:plano_de_cuidado/core/exportacao_pdf.dart';
import 'package:plano_de_cuidado/core/importacao_pdf.dart';
import 'package:plano_de_cuidado/core/plano.dart';

import 'fixtures/rascunho_conferido.dart';

void main() {
  Plano exportar(RascunhoPdf r) =>
      planoDoPdfConferido(r, profissional: 'M', registro: 'R');

  test('sem rotina, o plano do PDF leva as refeições prescritas', () {
    final p = exportar(rascunhoConferido());
    expect(p.alimentacao, isNull);
    expect(p.refeicoesPrescritas, hasLength(4));
    expect(p.metas.where((m) => m['tipo'] == 'refeicoes'), hasLength(1));
  });

  test('rotina com metas substitui as refeições e a meta de refeições', () {
    final r = rascunhoConferido();
    final outras = r.lista('metas').where((m) => m['tipo'] != 'checklist');
    r.data['alimentacao'] = AlimentacaoPlano.modeloTeste()
      ..['meta'] = {
        'kcal': 2270,
        'proteina': 104,
        'carboidrato': 282,
        'gordura': 81,
        'fibra': 30,
      };
    final p = Plano.parse(jsonEncode(exportar(r).data));
    expect(p.alimentacao!.meta.kcal, 2270);
    expect(p.alimentacao!.meta.proteina, 104);
    expect(p.refeicoesPrescritas, isEmpty);
    expect(p.metas.map((m) => m['id']), outras.map((m) => m['id']));
    expect(p.data['pdf'], isNotNull);
  });

  test('rotina danificada no rascunho não é exportada nem restaurada', () {
    final r = rascunhoConferido();
    r.data['alimentacao'] = {'titulo': 'x', 'meta': {'kcal': 1}};
    expect(
      () => ArquivosRascunhoPdf.validarParaRestaurar(
        jsonDecode(jsonEncode(r.data)),
      ),
      throwsFormatException,
    );
    expect(() => exportar(r), throwsFormatException);
  });
}
