import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'edicao_plano.dart';
import 'plano.dart';
import 'padrao_pdf.dart';

const canalLeituraPdf = MethodChannel('br.com.waldirdev01.plano_cuidado/pdf');

class TextoPdf {
  const TextoPdf({required this.paginas, this.links = const []});
  final List<String> paginas;
  final List<String> links;
  String get texto => paginas.join('\n\n');

  static Future<TextoPdf> ler(Uint8List bytes) async {
    if (bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('Selecione um PDF de até 10 MB.');
    }
    if (bytes.length < 5 ||
        ascii.decode(bytes.take(5).toList(), allowInvalid: true) != '%PDF-') {
      throw const FormatException('Selecione um documento PDF válido.');
    }
    try {
      final raw = await canalLeituraPdf.invokeMapMethod<String, dynamic>(
        'extrair',
        {'bytes': bytes},
      );
      if (raw == null || raw['paginas'] is! List || raw['links'] is! List) {
        throw const FormatException('Não foi possível ler o conteúdo do PDF.');
      }
      return TextoPdf(
        paginas: (raw['paginas'] as List).cast<String>(),
        links: (raw['links'] as List).cast<String>(),
      );
    } on MissingPluginException {
      throw const FormatException(
        'A leitura local de PDF está disponível no aplicativo iOS atualizado.',
      );
    } on PlatformException catch (e) {
      throw FormatException(e.message ?? 'Não foi possível ler este PDF.');
    }
  }
}

/// A separate review document, NEVER a patient .plano. No contract/DB migration.
class RascunhoPdf {
  RascunhoPdf(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get estado => data['estado'] as String;
  String get nome => data['campos']['nome'] as String;
  Map<String, dynamic> get campos => data['campos'] as Map<String, dynamic>;
  List<Map<String, dynamic>> lista(String key) =>
      (data[key] as List).cast<Map<String, dynamic>>();

  List<String> validarConferencia() {
    final errors = <String>[];
    final padronizado = data['padraoPdf'] == PadraoPdf.versao;
    if (padronizado) {
      PadraoPdf.atualizarItens(data);
      errors.addAll(PadraoPdf.validar(data));
    }
    if ((campos['nome'] as String).trim().isEmpty) {
      errors.add('Informe o nome completo do paciente.');
    }
    for (final key in ['consulta', 'emissao']) {
      final value = (campos[key] as String).trim();
      if (value.isNotEmpty || padronizado) {
        try {
          Plano.parseDia(value);
        } catch (_) {
          errors.add(
            'Confira a data de ${key == 'consulta' ? 'consulta' : 'emissão'}.',
          );
        }
      }
    }
    final link = (campos['link'] as String).trim();
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'drapriscilakcarvalho.com.br' ||
          uri.path != '/monte-seu-prato.html' ||
          !RegExp(r'(?:^|&)p=[A-Za-z0-9_-]+').hasMatch(uri.fragment)) {
        errors.add(
          'Confira o link pessoal completo do Monte seu prato (https e #p=...).',
        );
      }
    }
    try {
      PerfilPaciente.validarNascimento(campos['nascimento'] as String);
    } catch (_) {
      errors.add('Informe um nascimento válido (DD/MM/AAAA).');
    }
    final dates = <String, DateTime>{};
    for (final entry in {
      'inicio': 'início dos registros',
      'fim': 'fim dos registros',
      'retorno': 'retorno',
    }.entries) {
      try {
        dates[entry.key] = Plano.parseDia(campos[entry.key] as String);
      } catch (_) {
        errors.add('Confira a data de ${entry.value}.');
      }
    }
    if (dates['inicio'] != null &&
        dates['fim'] != null &&
        dates['fim']!.isBefore(dates['inicio']!)) {
      errors.add('O fim dos registros não pode anteceder o início.');
    }
    if (dates['fim'] != null &&
        dates['retorno'] != null &&
        dates['retorno']!.isBefore(dates['fim']!)) {
      errors.add('Confira o fim dos registros: está depois do retorno.');
    }
    for (final key in ['horaRetorno', 'envioHora']) {
      final value = (campos[key] as String).trim();
      if (!_hora(value)) {
        errors.add(
          'Confira ${key == 'horaRetorno' ? 'o horário do retorno' : 'o horário do envio'} (HH:MM).',
        );
      }
    }
    if (!['0', '1', '2', '3', '4', '5', '6'].contains(campos['envioDia'])) {
      errors.add('Defina o dia do envio.');
    }
    for (final meta in lista('metas')) {
      if (!padronizado &&
          meta['tipo'] == 'checklist' &&
          (meta['itens'] as String).split(',').every((s) => s.trim().isEmpty)) {
        errors.add('Defina os itens para confirmar na meta alimentar.');
      }
      if ((meta['titulo'] as String).trim().isEmpty ||
          (meta['descricao'] as String).trim().isEmpty) {
        errors.add('Confira o título e a orientação de cada meta.');
      }
      if (meta['tipo'] == 'contador') {
        final n = double.tryParse(
          (meta['alvo'] as String).replaceAll(',', '.'),
        );
        if (n == null ||
            !n.isFinite ||
            n <= 0 ||
            (meta['unidade'] as String).trim().isEmpty) {
          errors.add('Defina quantidade e unidade da hidratação.');
        }
      }
      _validarHorarios(meta['horarios'] as String, errors);
    }
    for (final meal in lista('refeicoes')) {
      if (!_hora(meal['horario'] as String)) {
        errors.add('Confira o horário de ${meal['titulo']}.');
      }
      if ((meal['descricao'] as String).trim().isEmpty) {
        errors.add('Confira o texto de ${meal['titulo']}.');
      }
    }
    final checks = data['confirmacoes'] as Map;
    for (final entry in {
      'identidade': 'Confirme o destinatário e o nome completo.',
      'periodo': 'Confirme as datas e os horários.',
      'conteudo': 'Confirme a fidelidade das metas, refeições e textos.',
    }.entries) {
      if (checks[entry.key] != true) errors.add(entry.value);
    }
    for (final issue in lista('pendencias')) {
      if (((data['decisoes'] as Map)[issue['id']] as String? ?? '')
          .trim()
          .isEmpty) {
        errors.add('Registre a decisão sobre: ${issue['titulo']}.');
      }
    }
    return errors.toSet().toList();
  }

  static bool _hora(String value) =>
      RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value.trim());
  static void _validarHorarios(String value, List<String> errors) {
    if (value.trim().isEmpty) return;
    if (value.split(',').any((h) => !_hora(h))) {
      errors.add('Use horários HH:MM separados por vírgula.');
    }
  }

  static RascunhoPdf analisar(
    TextoPdf pdf, {
    required String nomeArquivo,
    required Uint8List bytes,
  }) {
    if (pdf.texto.trim().length < 100) {
      throw const FormatException(
        'Este PDF não contém texto legível. Exporte o modelo como PDF com texto selecionável, não como foto.',
      );
    }
    final parsed = PadraoPdf.ler(pdf.texto);
    return RascunhoPdf({
      ...parsed,
      'formato': 'rascunho-importacao-pdf',
      'versao': 1,
      'id': novoId(),
      'estado': 'rascunho',
      'atualizadoEm': DateTime.now().toIso8601String(),
      'pdf': {
        'nome': nomeArquivo.split(RegExp(r'[/\\\\]')).last,
        'base64': base64Encode(bytes),
      },
      'paginas': pdf.paginas,
      'linksOriginais': pdf.links,
      'origens': {
        'identidade': pdf.texto,
        'periodo': pdf.texto,
        'retorno': pdf.texto,
      },
      'pendencias': <Map<String, dynamic>>[],
      'decisoes': <String, String>{},
      'confirmacoes': {
        'identidade': false,
        'periodo': false,
        'conteudo': false,
      },
    });
  }
}

/// Drafts live outside plans/records and the patient import path.
class ArquivosRascunhoPdf {
  ArquivosRascunhoPdf({this.diretorio});
  final Directory? diretorio;
  Future<Directory> _dir() async {
    final dir =
        diretorio ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}/rascunhos_pdf',
        );
    return dir.create(recursive: true);
  }

  Future<void> salvar(RascunhoPdf r) async {
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(r.id)) {
      throw const FormatException('Identificação do rascunho inválida.');
    }
    r.data['atualizadoEm'] = DateTime.now().toIso8601String();
    final path = '${(await _dir()).path}/${r.id}.json';
    final temp = File('$path.tmp');
    await temp.writeAsString(jsonEncode(r.data), flush: true);
    await temp.rename(path);
  }

  Future<List<RascunhoPdf>> listar() async {
    final drafts = <RascunhoPdf>[];
    await for (final f in (await _dir()).list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final d = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        if (d['formato'] == 'rascunho-importacao-pdf' && d['versao'] == 1) {
          final r = RascunhoPdf(d);
          _conferirEstrutura(r);
          drafts.add(r);
        }
      } catch (_) {
        /* One damaged draft must not hide the remaining drafts. */
      }
    }
    drafts.sort(
      (a, b) => (b.data['atualizadoEm'] as String).compareTo(
        a.data['atualizadoEm'] as String,
      ),
    );
    return drafts;
  }

  // Validate partial drafts structurally, not clinically. A damaged file must
  // not make the professional home page crash or imply clinical approval.
  static void _conferirEstrutura(RascunhoPdf r) {
    void strings(Map map, List<String> keys) {
      if (keys.any((key) => map[key] is! String)) {
        throw const FormatException('Rascunho danificado.');
      }
    }

    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(r.id) ||
        !['rascunho', 'conferido'].contains(r.estado)) {
      throw const FormatException('Rascunho danificado.');
    }
    strings(r.campos, [
      'nome',
      'nascimento',
      'consulta',
      'emissao',
      'inicio',
      'fim',
      'retorno',
      'horaRetorno',
      'envioDia',
      'envioHora',
      'link',
    ]);
    strings(r.data['pdf'] as Map, ['nome', 'base64']);
    strings(r.data['origens'] as Map, ['identidade', 'periodo', 'retorno']);
    DateTime.parse(r.data['atualizadoEm'] as String);
    (r.data['paginas'] as List).cast<String>().toList();
    for (final group in {
      'metas': [
        'id',
        'titulo',
        'descricao',
        'tipo',
        'alvo',
        'unidade',
        'itens',
        'horarios',
      ],
      'refeicoes': ['id', 'titulo', 'referencia', 'horario', 'descricao'],
      'secoes': ['titulo', 'texto'],
      'pendencias': ['id', 'titulo', 'detalhe', 'origem'],
    }.entries) {
      for (final item in r.lista(group.key)) {
        strings(item, group.value);
      }
    }
    (r.data['decisoes'] as Map).cast<String, String>();
    if (r.data.containsKey('padraoPdf')) {
      if (r.data['padraoPdf'] != PadraoPdf.versao) {
        throw const FormatException('Padrão de PDF não suportado.');
      }
      for (final meta in r.lista('metas')) {
        strings(meta, ['distribuicao']);
        if (!['contador', 'checklist', 'sim_nao'].contains(meta['tipo'])) {
          throw const FormatException('Tipo de meta danificado no rascunho.');
        }
      }
      for (final meal in r.lista('refeicoes')) {
        strings(meal, ['regra', 'condicao']);
        if (!['obrigatoria', 'condicional'].contains(meal['regra'])) {
          throw const FormatException(
            'Regra de refeição danificada no rascunho.',
          );
        }
      }
    }
    final checks = r.data['confirmacoes'] as Map;
    if ([
      'identidade',
      'periodo',
      'conteudo',
    ].any((key) => checks[key] is! bool)) {
      throw const FormatException('Rascunho danificado.');
    }
  }
}
