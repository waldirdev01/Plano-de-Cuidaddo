import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:plano_de_cuidado/core/importacao_pdf.dart';
import 'package:plano_de_cuidado/core/exportacao_pdf.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'pdf_texto.dart';

RascunhoPdf rascunhoConferido({int refeicoes = 4}) {
  var text = textoPlanoPdfTeste;
  if (refeicoes < 4) {
    for (var n = refeicoes + 1; n <= 4; n++) {
      text = text.replaceFirst(RegExp('REFEICAO $n[\\s\\S]*?FIM REFEICAO'), '');
    }
  }
  for (var n = 5; n <= refeicoes; n++) {
    text = text.replaceFirst('ORIENTACOES LIVRES', '''REFEICAO $n
Nome: Refeição de exemplo $n
Horario: 20:00
Regra: OBRIGATORIA
Condicao para dispensar: NAO SE APLICA
Prescricao: Texto fictício da refeição adicional.
FIM REFEICAO
ORIENTACOES LIVRES''');
  }
  final r = RascunhoPdf.analisar(
    TextoPdf(paginas: [text]),
    nomeArquivo: 'ficticio.pdf',
    bytes: Uint8List.fromList(utf8.encode('%PDF-ficticio')),
  );
  for (final key in (r.data['confirmacoes'] as Map).keys) {
    r.data['confirmacoes'][key] = true;
  }
  r.data['estado'] = 'conferido';
  r.data['salvo'] = true;
  return r;
}

Plano planoPdfTeste({int refeicoes = 4}) => planoDoPdfConferido(
  rascunhoConferido(refeicoes: refeicoes),
  profissional: 'Médica Exemplo',
  registro: 'CRM TESTE',
);
