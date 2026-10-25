import 'edicao_plano.dart';
import 'plano.dart';

/// Deterministic, versioned document contract. Free prose is never interpreted.
class PadraoPdf {
  static const versao = 'PLANO-CUIDADO/1';
  static const identificador = 'PADRAO DO APLICATIVO: $versao';
  static const dias = [
    'DOMINGO',
    'SEGUNDA',
    'TERCA',
    'QUARTA',
    'QUINTA',
    'SEXTA',
    'SABADO',
  ];
  static String normal(String s) => PerfilPaciente.normalizarNome(s);

  static Map<String, dynamic> ler(String texto) {
    final lines = texto
        .replaceAll('\r', '')
        .replaceAll('\u00a0', ' ')
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.where((s) => normal(s) == normal(identificador)).length != 1) {
      throw const FormatException(
        'Use o novo modelo PLANO-CUIDADO/1. PDFs antigos ou de outro formato não são interpretados. Os rascunhos já salvos continuam disponíveis.',
      );
    }
    if (RegExp(r'\[PREENCHER', caseSensitive: false).hasMatch(texto)) {
      throw const FormatException(
        'O modelo ainda contém campos entre colchetes. Preencha todos eles antes de exportar o PDF.',
      );
    }
    final dados = <String, String>{};
    final metas = <Map<String, dynamic>>[];
    final refeicoes = <Map<String, dynamic>>[];
    String? orientacoes;
    var i = 0;
    while (i < lines.length) {
      final line = normal(lines[i]);
      if (line == normal(identificador) || line == 'plano de cuidado') {
        i++;
        continue;
      }
      final end = switch (line) {
        'dados do plano' => 'fim dados do plano',
        'orientacoes livres' => 'fim orientacoes livres',
        _ when RegExp(r'^meta [1-8]$').hasMatch(line) => 'fim meta',
        _ when RegExp(r'^refeicao [1-8]$').hasMatch(line) => 'fim refeicao',
        _ => null,
      };
      if (end == null) {
        throw FormatException(
          'Linha fora do padrão: "${lines[i]}". Use os blocos e rótulos do modelo.',
        );
      }
      final start = ++i;
      while (i < lines.length && normal(lines[i]) != end) {
        i++;
      }
      if (i == lines.length) {
        throw FormatException('Falta o marcador ${end.toUpperCase()}.');
      }
      final body = lines.sublist(start, i++);
      if (line == 'orientacoes livres') {
        if (orientacoes != null) {
          throw const FormatException(
            'Mantenha somente um bloco ORIENTACOES LIVRES.',
          );
        }
        orientacoes = body.join('\n');
      } else if (line == 'dados do plano') {
        if (dados.isNotEmpty) {
          throw const FormatException(
            'Mantenha somente um bloco DADOS DO PLANO.',
          );
        }
        dados.addAll(
          _campos(body, [
            'Paciente',
            'Nascimento',
            'Consulta',
            'Emissao',
            'Inicio dos registros',
            'Fim dos registros',
            'Retorno',
            'Hora do retorno',
            'Envio semanal',
            'Hora do envio',
            'Link pessoal',
          ], 'DADOS DO PLANO'),
        );
      } else if (line.startsWith('meta ')) {
        if (line != 'meta ${metas.length + 1}') {
          throw const FormatException(
            'Numere as metas em sequência, de 1 a 8.',
          );
        }
        final fields = _campos(
          body,
          [
            'Titulo',
            'Tipo',
            'Lembretes',
            'Orientacao',
            'Quantidade diaria',
            'Unidade',
            'Distribuicao',
          ],
          line,
          opcionais: ['Quantidade diaria', 'Unidade', 'Distribuicao'],
        );
        final tipo = normal(fields['tipo']!);
        if (!['refeicoes', 'contagem', 'confirmacao'].contains(tipo)) {
          throw const FormatException(
            'Tipo de meta: use REFEICOES, CONTAGEM ou CONFIRMACAO.',
          );
        }
        final count = tipo == 'contagem';
        if (count &&
            [
              'quantidade diaria',
              'unidade',
              'distribuicao',
            ].any((k) => !fields.containsKey(k))) {
          throw const FormatException(
            'Meta CONTAGEM exige Quantidade diaria, Unidade e Distribuicao.',
          );
        }
        if (!count &&
            [
              'quantidade diaria',
              'unidade',
              'distribuicao',
            ].any(fields.containsKey)) {
          throw const FormatException(
            'Quantidade diaria, Unidade e Distribuicao são exclusivos da meta CONTAGEM.',
          );
        }
        metas.add({
          'id': novoId(),
          'titulo': fields['titulo'],
          'descricao': fields['orientacao'],
          'tipo': count
              ? 'contador'
              : tipo == 'refeicoes'
              ? 'checklist'
              : 'sim_nao',
          'alvo': fields['quantidade diaria'] ?? '',
          'unidade': fields['unidade'] ?? '',
          'distribuicao': fields['distribuicao'] ?? '',
          'itens': '',
          'horarios': normal(fields['lembretes']!) == 'nenhum'
              ? ''
              : fields['lembretes'],
        });
      } else {
        if (line != 'refeicao ${refeicoes.length + 1}') {
          throw const FormatException(
            'Numere as refeições em sequência, de 1 a 8.',
          );
        }
        final fields = _campos(body, [
          'Nome',
          'Horario',
          'Regra',
          'Condicao para dispensar',
          'Prescricao',
        ], line);
        refeicoes.add({
          'id': novoId(),
          'titulo': fields['nome'],
          'horario': fields['horario'],
          'referencia': '${fields['horario']} · ${fields['regra']}',
          'regra': normal(fields['regra']!),
          'condicao': fields['condicao para dispensar'],
          'descricao': fields['prescricao'],
        });
      }
    }
    if (dados.isEmpty ||
        metas.isEmpty ||
        orientacoes == null ||
        orientacoes.isEmpty) {
      throw const FormatException(
        'Preencha DADOS DO PLANO, ao menos uma META e ORIENTACOES LIVRES.',
      );
    }
    final campos = <String, dynamic>{
      'nome': dados['paciente'],
      'nascimento': _data(dados['nascimento']!),
      'consulta': _data(dados['consulta']!),
      'emissao': _data(dados['emissao']!),
      'inicio': _data(dados['inicio dos registros']!),
      'fim': _data(dados['fim dos registros']!),
      'retorno': _data(dados['retorno']!),
      'horaRetorno': dados['hora do retorno'],
      'envioDia':
          '${dias.indexWhere((d) => normal(d) == normal(dados['envio semanal']!))}',
      'envioHora': dados['hora do envio'],
      'link': normal(dados['link pessoal']!) == 'nenhum'
          ? ''
          : dados['link pessoal'],
    };
    if (campos['envioDia'] == '-1') {
      throw const FormatException(
        'Envio semanal: use DOMINGO, SEGUNDA, TERCA, QUARTA, QUINTA, SEXTA ou SABADO.',
      );
    }
    final result = <String, dynamic>{
      'padraoPdf': versao,
      'campos': campos,
      'metas': metas,
      'refeicoes': refeicoes,
      'secoes': [
        {'titulo': 'Orientações da médica', 'texto': orientacoes},
      ],
    };
    atualizarItens(result);
    final errors = validar(result);
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    return result;
  }

  static Map<String, String> _campos(
    List<String> lines,
    List<String> rotulos,
    String bloco, {
    List<String> opcionais = const [],
  }) {
    final validos = rotulos.map(normal).toSet();
    final fields = <String, String>{};
    String? atual;
    for (final line in lines) {
      final colon = line.indexOf(':');
      final candidate = colon < 0 ? '' : normal(line.substring(0, colon));
      if (validos.contains(candidate)) {
        if (fields.containsKey(candidate)) {
          throw FormatException('Campo repetido em $bloco: $candidate.');
        }
        atual = candidate;
        fields[atual] = line.substring(colon + 1).trim();
      } else if (atual != null &&
          ['orientacao', 'prescricao'].contains(atual)) {
        fields[atual] = '${fields[atual]}\n$line';
      } else if (atual != null && colon < 0) {
        // PDF export may wrap a long value, including a personal URL.
        fields[atual] =
            '${fields[atual]}${atual == 'link pessoal' ? '' : ' '}$line';
      } else {
        throw FormatException(
          'Rótulo não reconhecido em $bloco: "$line". Não renomeie os campos do modelo.',
        );
      }
    }
    for (final key
        in rotulos.where((k) => !opcionais.contains(k)).map(normal)) {
      if ((fields[key] ?? '').isEmpty) {
        throw FormatException('Preencha "$key" no bloco $bloco.');
      }
    }
    return fields;
  }

  static String _data(String value) {
    if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(value)) {
      throw FormatException('Data fora do padrão: "$value". Use DD/MM/AAAA.');
    }
    final p = value.split('/');
    final iso = '${p[2]}-${p[1]}-${p[0]}';
    try {
      Plano.parseDia(iso);
    } catch (_) {
      throw FormatException('Data inválida: "$value".');
    }
    return iso;
  }

  static bool hora(String s) =>
      RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(s.trim());
  static double? numero(String s) {
    if (!RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(s.trim())) return null;
    final n = double.tryParse(s.trim().replaceAll(',', '.'));
    return n != null && n.isFinite && n > 0 ? n : null;
  }

  /// Rebuild from explicit rules so optional meals never silently become failures.
  static void atualizarItens(Map<String, dynamic> d) {
    final meals = (d['refeicoes'] as List).cast<Map<String, dynamic>>();
    for (final meta in (d['metas'] as List).cast<Map<String, dynamic>>()) {
      if (meta['tipo'] == 'checklist') {
        meta['itens'] = meals
            .where((m) => m['regra'] == 'obrigatoria')
            .map((m) => m['titulo'])
            .join(', ');
      }
    }
  }

  static List<String> validar(Map<String, dynamic> d) {
    final errors = <String>[];
    final c = d['campos'] as Map;
    if ((c['nome'] as String).trim().split(RegExp(r'\s+')).length < 2) {
      errors.add('Informe o nome completo do paciente.');
    }
    try {
      PerfilPaciente.validarNascimento(c['nascimento'] as String);
    } catch (_) {
      errors.add('Informe um nascimento válido.');
    }
    for (final key in ['horaRetorno', 'envioHora']) {
      if (!hora(c[key] as String)) {
        errors.add('Use HH:MM no retorno e no envio semanal.');
      }
    }
    final datas = <String, DateTime>{};
    for (final key in ['consulta', 'emissao', 'inicio', 'fim', 'retorno']) {
      try {
        datas[key] = Plano.parseDia(c[key] as String);
      } catch (_) {
        errors.add('Confira a data de $key.');
      }
    }
    if ((datas['inicio'] != null &&
            datas['fim'] != null &&
            datas['fim']!.isBefore(datas['inicio']!)) ||
        (datas['fim'] != null &&
            datas['retorno'] != null &&
            datas['retorno']!.isBefore(datas['fim']!))) {
      errors.add(
        'As datas devem seguir início dos registros, fim dos registros e retorno.',
      );
    }
    if (!RegExp(r'^[0-6]$').hasMatch(c['envioDia'] as String)) {
      errors.add('Defina o dia do envio semanal.');
    }
    if ((d['metas'] as List).isEmpty ||
        (d['metas'] as List).length > 8 ||
        (d['refeicoes'] as List).length > 8) {
      errors.add('O padrão exige de uma a oito metas e até oito refeições.');
    }
    final link = (c['link'] as String).trim();
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'drapriscilakcarvalho.com.br' ||
          uri.path != '/monte-seu-prato.html' ||
          !RegExp(r'(?:^|&)p=[A-Za-z0-9_-]+').hasMatch(uri.fragment)) {
        errors.add(
          'Link pessoal: cole o endereço completo com https e #p=... ou use NENHUM.',
        );
      }
    }
    for (final meta in (d['metas'] as List).cast<Map<String, dynamic>>()) {
      if (!['contador', 'checklist', 'sim_nao'].contains(meta['tipo'])) {
        errors.add('Tipo de meta não suportado pelo padrão 1.');
      }
      if ((meta['horarios'] as String).trim().isNotEmpty) {
        final times = (meta['horarios'] as String)
            .split(',')
            .map((h) => h.trim())
            .toList();
        if (times.any((h) => !hora(h)) ||
            times.toSet().length != times.length) {
          errors.add(
            'Lembretes de ${meta['titulo']}: use HH:MM separados por vírgula, sem repetir.',
          );
        }
      }
      if (meta['tipo'] == 'contador') {
        final target = numero(meta['alvo'] as String);
        if (target == null) {
          errors.add(
            'Quantidade diaria de ${meta['titulo']}: informe um número maior que zero.',
          );
        }
        if ((meta['unidade'] as String).trim().isEmpty) {
          errors.add('Informe a unidade de ${meta['titulo']}.');
        }
        final distribution = (meta['distribuicao'] as String? ?? '').trim();
        if (normal(distribution) != 'livre') {
          final times = <String>{};
          double sum = 0;
          var valid = distribution.isNotEmpty;
          for (final item in distribution.split(';')) {
            final pair = item.trim().split('=');
            if (pair.length != 2 ||
                !hora(pair[0]) ||
                numero(pair[1]) == null ||
                !times.add(pair[0].trim())) {
              valid = false;
            } else {
              sum += numero(pair[1])!;
            }
          }
          if (!valid) {
            errors.add(
              'Distribuicao de ${meta['titulo']}: use HH:MM=quantidade; HH:MM=quantidade, sem horários repetidos, ou LIVRE.',
            );
          } else if (target != null && (sum - target).abs() > 0.000001) {
            errors.add(
              'A distribuição de ${meta['titulo']} soma $sum, mas a quantidade diária é ${meta['alvo']}. Corrija os campos; uma justificativa não substitui a correção.',
            );
          }
        }
      }
    }
    final meals = (d['refeicoes'] as List).cast<Map<String, dynamic>>();
    if ((d['metas'] as List).any((m) => m['tipo'] == 'checklist') &&
        meals.isEmpty) {
      errors.add('Meta REFEICOES exige ao menos uma REFEICAO.');
    }
    final names = <String>{};
    for (final meal in meals) {
      if ((meal['titulo'] as String).trim().isEmpty ||
          !names.add(normal(meal['titulo'] as String))) {
        errors.add('Cada refeição precisa de nome próprio, sem repetir.');
      }
      if (!hora(meal['horario'] as String)) {
        errors.add('Horário de ${meal['titulo']}: use HH:MM.');
      }
      final rule = meal['regra'];
      final condition = (meal['condicao'] as String? ?? '').trim();
      if (!['obrigatoria', 'condicional'].contains(rule)) {
        errors.add(
          'Regra de ${meal['titulo']}: use OBRIGATORIA ou CONDICIONAL.',
        );
      }
      if (rule == 'obrigatoria' && normal(condition) != 'nao se aplica') {
        errors.add(
          '${meal['titulo']} obrigatória: Condicao para dispensar deve ser NAO SE APLICA.',
        );
      }
      if (rule == 'condicional' &&
          (condition.isEmpty || normal(condition) == 'nao se aplica')) {
        errors.add('Descreva a condição para dispensar ${meal['titulo']}.');
      }
      if ((meal['descricao'] as String).trim().isEmpty) {
        errors.add('Preencha a prescrição de ${meal['titulo']}.');
      }
    }
    return errors;
  }
}
