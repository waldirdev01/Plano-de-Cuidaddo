import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_de_cuidado/core/importacao_pdf.dart';
import 'package:plano_de_cuidado/core/padrao_pdf.dart';
import 'package:plano_de_cuidado/core/plano.dart';
import 'fixtures/pdf_texto.dart';

RascunhoPdf exemploPdf([String? text]) => RascunhoPdf.analisar(
  TextoPdf(paginas: [text ?? textoPlanoPdfTeste], links: const [linkPdfTeste]),
  nomeArquivo: 'exemplo.pdf',
  bytes: Uint8List.fromList(utf8.encode('%PDF-FAKE')),
);
Matcher erro(String message) => throwsA(
  isA<FormatException>().having(
    (e) => e.message,
    'mensagem',
    contains(message),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'modelo distribuído preenchido com dados fictícios respeita o contrato',
    () {
      final blocos = <String, Map<String, String>>{};
      var bloco = '';
      final marcador = RegExp(
        r'^(?:DADOS DO PLANO|META [1-8]|REFEICAO [1-8]|ORIENTACOES LIVRES)$',
      );
      for (final line in textoPlanoPdfTeste.split('\n')) {
        if (marcador.hasMatch(line)) {
          bloco = line;
          blocos[bloco] = {};
        } else if (line.contains(':') && bloco.isNotEmpty) {
          final colon = line.indexOf(':');
          blocos[bloco]![line.substring(0, colon)] = line
              .substring(colon + 1)
              .trim();
        }
      }
      bloco = '';
      final template = File(
        'docs/modelos/plano-cuidado-padrao-1.txt',
      ).readAsStringSync();
      final filled = template
          .split('\n')
          .map((line) {
            if (marcador.hasMatch(line)) bloco = line;
            if (!line.contains('[PREENCHER')) return line;
            if (bloco == 'ORIENTACOES LIVRES') {
              return 'Orientação fictícia de referência.';
            }
            final label = line.substring(0, line.indexOf(':'));
            final value = blocos[bloco]![label];
            expect(
              value,
              isNotNull,
              reason:
                  'Campo do modelo precisa existir no exemplo: $bloco / $label',
            );
            return '$label: $value';
          })
          .join('\n');
      final r = exemploPdf(filled);
      expect(r.lista('pendencias'), isEmpty);
      expect(r.campos['nascimento'], '1990-01-01');
      expect(r.lista('refeicoes')[2]['regra'], 'condicional');
      expect(r.lista('metas').last['alvo'], '4');
    },
  );
  test('padrão 1 extrai campos explícitos e separa lanche condicional', () {
    final r = exemploPdf();
    expect(r.data['padraoPdf'], PadraoPdf.versao);
    expect(r.nome, 'Ana Exemplo Completo');
    expect(r.campos['nascimento'], '1990-01-01');
    expect(r.campos['consulta'], '2026-10-16');
    expect(r.campos['emissao'], '2026-10-17');
    expect(r.campos['inicio'], '2026-10-17');
    expect(r.campos['fim'], '2026-10-30');
    expect(r.campos['retorno'], '2026-10-31');
    expect(r.campos['horaRetorno'], '10:00');
    expect(r.campos['envioDia'], '5');
    expect(r.campos['envioHora'], '18:00');
    expect(
      r.campos['link'],
      '',
      reason: 'Anotação não substitui NENHUM escrito no campo.',
    );
    expect(r.lista('metas'), hasLength(2));
    expect(r.lista('metas').last['alvo'], '4');
    expect(r.lista('metas').last['unidade'], 'copos de 500 ml');
    expect(r.lista('metas').last['horarios'], '10:00, 12:00');
    expect(r.lista('refeicoes').map((m) => m['horario']), [
      '09:30',
      '12:00',
      '15:30',
      '19:00',
    ]);
    expect(r.lista('metas').first['itens'], 'Café da manhã, Almoço, Jantar');
    expect(r.lista('refeicoes')[2]['regra'], 'condicional');
    expect(r.lista('pendencias'), isEmpty);
    expect(r.data.containsKey('alimentacao'), false);
    expect(() => Plano.parse(jsonEncode(r.data)), throwsFormatException);
  });
  test(
    'padrão válido conclui sem decisões extras e exige as três confirmações',
    () {
      final r = exemploPdf();
      expect(r.validarConferencia(), hasLength(3));
      for (final k in (r.data['confirmacoes'] as Map).keys) {
        r.data['confirmacoes'][k] = true;
      }
      expect(r.validarConferencia(), isEmpty);
      r.campos['fim'] = '2026-11-05';
      expect(r.validarConferencia().join(), contains('depois do retorno'));
      r.campos['inicio'] = 'data incompleta';
      expect(r.validarConferencia(), isNotEmpty);
    },
  );
  test('recusa template em branco, modelo antigo, estranho e imagem', () {
    expect(
      () => exemploPdf(
        File('docs/modelos/plano-cuidado-padrao-1.txt').readAsStringSync(),
      ),
      erro('colchetes'),
    );
    for (final text in [
      textoPlanoPdfTeste.replaceAll(PadraoPdf.identificador, ''),
      textoPlanoPdfTeste.replaceAll(PadraoPdf.versao, 'PLANO-CUIDADO/2'),
      'Texto de outro documento. ' * 20,
      '',
    ]) {
      expect(() => exemploPdf(text), throwsFormatException);
    }
  });
  test('campos obrigatórios e rótulos não são adivinhados', () {
    expect(
      () => exemploPdf(
        textoPlanoPdfTeste.replaceAll('Nascimento: 01/01/1990\n', ''),
      ),
      erro('nascimento'),
    );
    expect(
      () => exemploPdf(
        textoPlanoPdfTeste.replaceAll('Hora do retorno:', 'Horario de voltar:'),
      ),
      erro('Rótulo'),
    );
    expect(
      () => exemploPdf(
        textoPlanoPdfTeste.replaceAll(
          'Envio semanal: SEXTA',
          'Envio semanal: SEXTA\nEnvio semanal: SABADO',
        ),
      ),
      erro('repetido'),
    );
    expect(
      () => exemploPdf(textoPlanoPdfTeste.replaceAll('FIM META', '')),
      throwsFormatException,
    );
    expect(
      () => exemploPdf(textoPlanoPdfTeste.replaceAll('META 2', 'META 3')),
      erro('sequência'),
    );
    expect(
      () => exemploPdf(
        textoPlanoPdfTeste.replaceAll('FIM ORIENTACOES LIVRES', ''),
      ),
      erro('marcador'),
    );
  });
  test('valida datas reais, formatos, ordem, horários e dia do envio', () {
    for (final replacement in {
      'Nascimento: 01/01/1990': 'Nascimento: 31/02/1990',
      'Consulta: 16/10/2026': 'Consulta: 2026-10-16',
      'Inicio dos registros: 17/10/2026': 'Inicio dos registros: 01/11/2026',
      'Hora do retorno: 10:00': 'Hora do retorno: 25:00',
      'Hora do envio: 18:00': 'Hora do envio: 6 da tarde',
      'Envio semanal: SEXTA': 'Envio semanal: toda semana',
      'Horario: 09:30': 'Horario: por volta das 9h30',
    }.entries) {
      expect(
        () => exemploPdf(
          textoPlanoPdfTeste.replaceAll(replacement.key, replacement.value),
        ),
        throwsFormatException,
        reason: replacement.key,
      );
    }
  });
  test(
    'contagem exige soma coerente e justificativa não substitui correção',
    () {
      expect(
        () => exemploPdf(textoPlanoPdfTeste.replaceAll('15:00=1', '15:00=2')),
        erro('soma 5'),
      );
      for (final invalid in ['0', '-1', 'NaN', 'Infinity', 'quatro']) {
        expect(
          () => exemploPdf(
            textoPlanoPdfTeste.replaceAll(
              'Quantidade diaria: 4',
              'Quantidade diaria: $invalid',
            ),
          ),
          throwsFormatException,
        );
      }
      for (final invalid in [
        '07:00=1; 07:00=3',
        '7h=4',
        '07:00=0',
        '1 ao acordar e mais 2 depois',
      ]) {
        expect(
          () => exemploPdf(
            textoPlanoPdfTeste.replaceAll(
              '07:00=1; 10:00=1; 12:00=1; 15:00=1',
              invalid,
            ),
          ),
          throwsFormatException,
        );
      }
      final r = exemploPdf();
      r.lista('metas').last['alvo'] = '5';
      r.data['decisoes']['agua'] = 'Texto livre não corrige o alvo.';
      expect(r.validarConferencia().join(), contains('soma 4'));
    },
  );
  test('LIVRE e ausência de lembrete não inventam horários ou quantidades', () {
    final r = exemploPdf(
      textoPlanoPdfTeste
          .replaceAll('07:00=1; 10:00=1; 12:00=1; 15:00=1', 'LIVRE')
          .replaceAll('Lembretes: 10:00, 12:00', 'Lembretes: NENHUM'),
    );
    expect(r.lista('metas').last['distribuicao'], 'LIVRE');
    expect(r.lista('metas').last['horarios'], '');
    expect(r.lista('metas').last['alvo'], '4');
    expect(
      () => exemploPdf(
        textoPlanoPdfTeste.replaceAll(
          'Lembretes: 10:00, 12:00',
          'Lembretes: 10:00, 10:00',
        ),
      ),
      erro('sem repetir'),
    );
  });
  test('regra condicional é explícita e lista obrigatória é recalculada', () {
    expect(
      () => exemploPdf(
        textoPlanoPdfTeste.replaceAll('Regra: CONDICIONAL', 'Regra: TALVEZ'),
      ),
      erro('OBRIGATORIA ou CONDICIONAL'),
    );
    expect(
      () => exemploPdf(
        textoPlanoPdfTeste.replaceAll(
          'Quando não sentir fome, conforme orientação da profissional.',
          'NAO SE APLICA',
        ),
      ),
      erro('Descreva a condição'),
    );
    final r = exemploPdf();
    final lanche = r.lista('refeicoes')[2];
    lanche['regra'] = 'obrigatoria';
    lanche['condicao'] = 'NAO SE APLICA';
    r.validarConferencia();
    expect(r.lista('metas').first['itens'], contains('Lanche da tarde'));
    lanche['condicao'] = 'Se não sentir fome';
    expect(r.validarConferencia().join(), contains('NAO SE APLICA'));
  });
  test('quantidade de refeições é variável e nomes não se repetem', () {
    final text = textoPlanoPdfTeste.replaceFirst(
      RegExp(r'REFEICAO 4[\s\S]*?FIM REFEICAO'),
      '',
    );
    expect(exemploPdf(text).lista('refeicoes'), hasLength(3));
    expect(
      () => exemploPdf(
        textoPlanoPdfTeste.replaceAll('Nome: Jantar', 'Nome: Almoço'),
      ),
      erro('sem repetir'),
    );
    final noMeals = textoPlanoPdfTeste.replaceAll(
      RegExp(r'REFEICAO [1-8][\s\S]*?FIM REFEICAO'),
      '',
    );
    expect(() => exemploPdf(noMeals), erro('ao menos uma REFEICAO'));
  });
  test(
    'confirmação diária não extrai horários nem condutas de texto livre',
    () {
      final text = textoPlanoPdfTeste
          .replaceFirst('Tipo: REFEICOES', 'Tipo: CONFIRMACAO')
          .replaceFirst(
            'Texto livre que não cria alarmes automaticamente.',
            'Alarme 23h e dose no texto: não transformar em tarefa.',
          );
      final r = exemploPdf(text);
      expect(r.lista('metas').first['tipo'], 'sim_nao');
      expect(r.lista('metas').first['horarios'], '');
      expect(r.lista('secoes').single['texto'], contains('23h'));
      expect(
        () => exemploPdf(
          textoPlanoPdfTeste.replaceFirst('Tipo: REFEICOES', 'Tipo: SEMANAL'),
        ),
        throwsFormatException,
      );
    },
  );
  test('link pessoal precisa estar escrito completo no campo', () {
    expect(
      exemploPdf(
        textoPlanoPdfTeste.replaceAll(
          'Link pessoal: NENHUM',
          'Link pessoal: $linkPdfTeste',
        ),
      ).campos['link'],
      linkPdfTeste,
    );
    expect(
      () => exemploPdf(
        textoPlanoPdfTeste.replaceAll(
          'Link pessoal: NENHUM',
          'Link pessoal: https://drapriscilakcarvalho.com.br/monte-seu-prato.html',
        ),
      ),
      erro('Link pessoal'),
    );
  });
  test('exportação pode quebrar linhas de valores sem mudar prescrição', () {
    final text = textoPlanoPdfTeste
        .replaceAll(
          'Exemplo fictício para testar a contagem.',
          'Exemplo fictício para\ntestar a contagem.',
        )
        .replaceAll('Unidade: copos de 500 ml', 'Unidade: copos de\n500 ml')
        .replaceAll(
          'Link pessoal: NENHUM',
          'Link pessoal: ${linkPdfTeste.substring(0, 45)}\n${linkPdfTeste.substring(45)}',
        );
    final r = exemploPdf(text);
    expect(r.campos['link'], linkPdfTeste);
    expect(r.lista('metas').last['unidade'], 'copos de 500 ml');
    expect(r.lista('metas').last['descricao'], contains('para\ntestar'));
    expect(r.data['paginas'], [text]);
  });
  test(
    'persistência preserva rascunhos do padrão e do modelo antigo',
    () async {
      final dir = Directory.systemTemp.createTempSync('rascunho-pdf-test-');
      try {
        final store = ArquivosRascunhoPdf(diretorio: dir);
        final r = exemploPdf();
        await store.salvar(r);
        final reopened = (await store.listar()).single;
        expect(reopened.id, r.id);
        expect(reopened.lista('refeicoes')[2]['regra'], 'condicional');
        r.data.remove('padraoPdf');
        for (final m in r.lista('metas')) {
          m.remove('distribuicao');
        }
        for (final m in r.lista('refeicoes')) {
          m.remove('regra');
          m.remove('condicao');
        }
        r.data['pendencias'] = [
          {
            'id': 'agua',
            'titulo': 'Aviso antigo',
            'detalhe': 'Texto antigo',
            'origem': 'PDF antigo',
          },
        ];
        r.data['decisoes']['agua'] = 'Decisão já salva';
        await store.salvar(r);
        expect(
          (await store.listar()).single.data['decisoes']['agua'],
          'Decisão já salva',
        );
        await File('${dir.path}/danificado.json').writeAsString('{');
        await File(
          '${dir.path}/incompleto.json',
        ).writeAsString('{"formato":"rascunho-importacao-pdf","versao":1}');
        expect(await store.listar(), hasLength(1));
        r.data['id'] = '../../outro';
        expect(() => store.salvar(r), throwsFormatException);
      } finally {
        dir.deleteSync(recursive: true);
      }
    },
  );
  test(
    'leitor valida assinatura, limite e erros nativos antes do parser',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(canalLeituraPdf, (call) async {
        expect(call.method, 'extrair');
        return {
          'paginas': [textoPlanoPdfTeste],
          'links': [linkPdfTeste],
        };
      });
      try {
        expect(
          (await TextoPdf.ler(
            Uint8List.fromList(utf8.encode('%PDF-test')),
          )).links,
          [linkPdfTeste],
        );
        await expectLater(
          TextoPdf.ler(Uint8List.fromList([1, 2, 3])),
          throwsFormatException,
        );
        await expectLater(
          TextoPdf.ler(Uint8List(10 * 1024 * 1024 + 1)),
          throwsFormatException,
        );
        messenger.setMockMethodCallHandler(
          canalLeituraPdf,
          (_) => throw PlatformException(code: 'pdf', message: 'PDF protegido'),
        );
        await expectLater(
          TextoPdf.ler(Uint8List.fromList(utf8.encode('%PDF-test'))),
          erro('PDF protegido'),
        );
      } finally {
        messenger.setMockMethodCallHandler(canalLeituraPdf, null);
      }
    },
  );
}
