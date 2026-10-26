import 'dart:convert';

import 'alimentacao.dart';
import 'treino.dart';

/// Contract validator and date helpers shared by import, screens and tests.
class Plano {
  Plano(this.data);

  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get nomePaciente => (data['paciente'] as Map)['nome'] as String;
  String? get nascimentoPaciente =>
      (data['paciente'] as Map)['nascimento'] as String?;
  String get nomeProfissional =>
      (data['profissional'] as Map?)?['nome'] as String? ?? 'Profissional';
  DateTime get inicio => parseDia(data['inicio'] as String);
  DateTime get retorno => parseDia((data['retorno'] as Map)['data'] as String);
  DateTime get fim =>
      data['versao'] == 4 ? parseDia(data['fim'] as String) : retorno;
  List<Map<String, dynamic>> get refeicoesPrescritas =>
      (data['refeicoesPrescritas'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get camposRefeicoes => [
    for (final m in refeicoesPrescritas) {...m, 'tipo': 'refeicao'},
  ];
  List<Map<String, dynamic>> get camposRegistraveis => [
    ...metas.where((m) => m['tipo'] != 'refeicoes'),
    ...camposDiarios,
    ...camposRefeicoes,
  ];
  List<Map<String, dynamic>> get metas =>
      (data['metas'] as List? ?? const []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get camposDiarios =>
      (data['camposDiarios'] as List? ?? const []).cast<Map<String, dynamic>>();
  /// Bloco opcional de treino (ver `core/treino.dart`).
  PrescricaoTreino? get treino {
    final raw = data['treino'];
    return raw is Map ? PrescricaoTreino.fromMap(raw) : null;
  }

  AlimentacaoPlano? get alimentacao {
    final raw = data['alimentacao'];
    return raw is Map ? AlimentacaoPlano.fromMap(raw) : null;
  }

  static DateTime parseDia(String value) {
    final p = value.split('-');
    if (p.length != 3 ||
        p[0].length != 4 ||
        p[1].length != 2 ||
        p[2].length != 2) {
      throw const FormatException('Data inválida. Use AAAA-MM-DD.');
    }
    final date = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    if (formatDia(date) != value) throw const FormatException('Data inválida.');
    return date;
  }

  static String formatDia(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static int diasEntre(DateTime a, DateTime b) => DateTime(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime(a.year, a.month, a.day)).inDays;

  static Plano parse(String source) {
    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException(
        'Este arquivo não contém um plano válido. Selecione o arquivo .plano enviado pela profissional.',
      );
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['formato'] != 'plano-de-cuidado' ||
        decoded['versao'] is! int) {
      throw const FormatException(
        'Este arquivo não é um Plano de Cuidado válido.',
      );
    }
    if ((decoded['versao'] as int) > 4) {
      throw const FormatException(
        'Este plano foi feito numa versão mais nova do app. Atualize o app.',
      );
    }
    if (decoded['versao'] != 1 &&
        decoded['versao'] != 2 &&
        decoded['versao'] != 3 &&
        decoded['versao'] != 4) {
      throw const FormatException('A versão deste plano não é compatível.');
    }
    try {
      if ((decoded['id'] as String).trim().isEmpty ||
          ((decoded['paciente'] as Map)['nome'] as String).trim().isEmpty ||
          ((decoded['profissional'] as Map)['nome'] as String).trim().isEmpty ||
          ((decoded['profissional'] as Map)['registro'] as String)
              .trim()
              .isEmpty) {
        throw const FormatException('Faltam dados de identificação do plano.');
      }
      final nascimento = (decoded['paciente'] as Map)['nascimento'];
      if (decoded['versao'] == 2 ||
          decoded['versao'] == 4 ||
          nascimento != null) {
        if (nascimento is! String) {
          throw const FormatException(
            'Informe a data de nascimento do paciente.',
          );
        }
        PerfilPaciente.validarNascimento(nascimento);
      }
      final inicio = parseDia(decoded['inicio'] as String);
      final retorno = parseDia((decoded['retorno'] as Map)['data'] as String);
      final horaRetorno = (decoded['retorno'] as Map)['hora'];
      if (horaRetorno != null && !_horaValida(horaRetorno)) {
        throw const FormatException('O horário do retorno é inválido.');
      }
      if (retorno.isBefore(inicio)) {
        throw const FormatException(
          'A data do retorno antecede o início do plano.',
        );
      }
      final metas = decoded['metas'] as List? ?? const [];
      final diarios = decoded['camposDiarios'] as List? ?? const [];
      _validarCampos(metas, versao: decoded['versao'] as int);
      _validarCampos(diarios);
      final refeicoes = decoded['refeicoesPrescritas'] as List? ?? const [];
      if (decoded['versao'] < 4 &&
          (decoded.containsKey('fim') ||
              decoded.containsKey('refeicoesPrescritas'))) {
        throw const FormatException(
          'Período de registros e refeições prescritas exigem a versão 4 do plano.',
        );
      }
      if (decoded['versao'] == 4) {
        final fim = parseDia(decoded['fim'] as String);
        if (fim.isBefore(inicio) || fim.isAfter(retorno)) {
          throw const FormatException(
            'O fim dos registros deve estar entre o início e o retorno.',
          );
        }
        if (refeicoes.length > 8) {
          throw const FormatException(
            'O plano suporta até oito refeições prescritas.',
          );
        }
        final nomes = <String>{};
        for (final m in refeicoes) {
          if (m is! Map ||
              m['id'] is! String ||
              (m['id'] as String).isEmpty ||
              m['titulo'] is! String ||
              (m['titulo'] as String).trim().isEmpty ||
              !nomes.add(
                PerfilPaciente.normalizarNome(m['titulo'] as String),
              ) ||
              !_horaValida(m['horario']) ||
              !['obrigatoria', 'condicional'].contains(m['regra']) ||
              m['condicao'] is! String ||
              (m['condicao'] as String).trim().isEmpty ||
              m['descricao'] is! String ||
              (m['descricao'] as String).trim().isEmpty) {
            throw const FormatException(
              'Uma refeição prescrita está incompleta ou repetida.',
            );
          }
          final condicao = PerfilPaciente.normalizarNome(
            m['condicao'] as String,
          );
          if ((m['regra'] == 'obrigatoria' && condicao != 'nao se aplica') ||
              (m['regra'] == 'condicional' && condicao == 'nao se aplica')) {
            throw const FormatException(
              'Confira a condição de dispensa da refeição.',
            );
          }
        }
        if (metas.any((m) => m['tipo'] == 'refeicoes') && refeicoes.isEmpty) {
          throw const FormatException(
            'A meta alimentar exige as refeições prescritas.',
          );
        }
        final link = decoded['linkMonteSeuPrato'];
        if (link is! String) {
          throw const FormatException('Confira o link pessoal do plano.');
        }
        if (link.isNotEmpty) {
          final u = Uri.tryParse(link);
          if (u == null ||
              u.scheme != 'https' ||
              u.host != 'drapriscilakcarvalho.com.br' ||
              u.path != '/monte-seu-prato.html' ||
              !RegExp(r'(?:^|&)p=[A-Za-z0-9_-]+').hasMatch(u.fragment)) {
            throw const FormatException(
              'O link pessoal do plano está inválido.',
            );
          }
        }
      }
      final ids = [
        ...metas,
        ...diarios,
        ...refeicoes,
      ].map((field) => field['id'] as String).toList();
      if (ids.toSet().length != ids.length) {
        throw const FormatException(
          'O plano contém identificadores repetidos.',
        );
      }
      final sections = decoded['secoes'] as List? ?? const [];
      for (final section in sections) {
        if (section is! Map ||
            section['titulo'] is! String ||
            section['texto'] is! String) {
          throw const FormatException('Uma seção de texto está incompleta.');
        }
      }
      if (decoded['alimentacao'] != null) {
        if (refeicoes.isNotEmpty) {
          throw const FormatException(
            'Use somente uma rotina alimentar: prescrita ou com opções nutricionais.',
          );
        }
        final rawAlimentacao = decoded['alimentacao'];
        if (rawAlimentacao is! Map) {
          throw const FormatException('O plano alimentar está inválido.');
        }
        AlimentacaoPlano.fromMap(rawAlimentacao);
      }
      if (decoded['treino'] != null) {
        PrescricaoTreino.validar(decoded['treino']);
      }
      final semanal = decoded['envioSemanal'];
      if (semanal != null &&
          (semanal['diaDaSemana'] is! int ||
              semanal['diaDaSemana'] < 0 ||
              semanal['diaDaSemana'] > 6 ||
              !_horaValida(semanal['ate']))) {
        throw const FormatException('O dia do envio semanal é inválido.');
      }
      final pdf = decoded['pdf'];
      if (pdf != null) {
        if (pdf is! Map || pdf['nome'] is! String || pdf['base64'] is! String) {
          throw const FormatException('O PDF anexado ao plano está inválido.');
        }
        final bytes = base64Decode(pdf['base64'] as String);
        if (bytes.length < 5 || ascii.decode(bytes.sublist(0, 5)) != '%PDF-') {
          throw const FormatException('O PDF anexado ao plano está inválido.');
        }
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('O arquivo está incompleto ou corrompido.');
    }
    return Plano(decoded);
  }

  static Plano parseBytes(List<int> bytes) {
    if (bytes.length >= 5 &&
        ascii.decode(bytes.take(5).toList(), allowInvalid: true) == '%PDF-') {
      throw const FormatException(
        'Você selecionou um PDF. Para importar as metas, selecione o arquivo .plano enviado pela profissional.',
      );
    }
    String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException {
      throw const FormatException(
        'Este arquivo não é um plano válido em UTF-8. Selecione um arquivo .plano.',
      );
    }
    return parse(source);
  }

  static void _validarCampos(List fields, {int versao = 3}) {
    const types = {'checklist', 'contador', 'sim_nao', 'texto', 'escala'};
    for (final raw in fields) {
      if (raw is! Map ||
          raw['id'] is! String ||
          (raw['id'] as String).trim().isEmpty ||
          raw['titulo'] is! String ||
          (raw['titulo'] as String).trim().isEmpty ||
          !(types.contains(raw['tipo']) ||
              (versao == 4 && raw['tipo'] == 'refeicoes'))) {
        throw const FormatException(
          'Uma meta ou anotação usa um tipo não suportado.',
        );
      }
      if (raw['tipo'] == 'checklist' &&
          (raw['itens'] is! List ||
              (raw['itens'] as List).any((item) => item is! String))) {
        throw const FormatException(
          'A lista de itens do plano está incompleta.',
        );
      }
      if (raw['tipo'] == 'contador' &&
          (raw['alvo'] is! num ||
              raw['alvo'] < 0 ||
              !(raw['alvo'] as num).isFinite ||
              raw['unidade'] is! String ||
              (raw['unidade'] as String).trim().isEmpty)) {
        throw const FormatException('O contador do plano está incompleto.');
      }
      if (versao == 4 && raw['tipo'] == 'contador') {
        final distribution = raw['distribuicao'];
        if (distribution is! String) {
          throw const FormatException('Informe a distribuição da contagem.');
        }
        if (PerfilPaciente.normalizarNome(distribution) != 'livre') {
          var sum = 0.0;
          final hours = <String>{};
          for (final part in distribution.split(';')) {
            final pair = part.split('=');
            final amount = pair.length == 2
                ? num.tryParse(pair[1].trim().replaceAll(',', '.'))
                : null;
            if (pair.length != 2 ||
                !_horaValida(pair[0].trim()) ||
                !hours.add(pair[0].trim()) ||
                amount == null ||
                !amount.isFinite ||
                amount <= 0) {
              throw const FormatException(
                'A distribuição da contagem está inválida.',
              );
            }
            sum += amount;
          }
          if ((sum - (raw['alvo'] as num)).abs() > 0.000001) {
            throw const FormatException(
              'A soma da distribuição não corresponde à quantidade diária.',
            );
          }
        }
      }
      if (raw['tipo'] == 'escala' &&
          (raw['min'] is! num ||
              raw['max'] is! num ||
              raw['min'] > raw['max'])) {
        throw const FormatException('A escala do plano está inválida.');
      }
      if (raw['lembretes'] != null &&
          (raw['lembretes'] is! List ||
              (raw['lembretes'] as List).any((hour) => !_horaValida(hour)))) {
        throw const FormatException('Um horário de lembrete é inválido.');
      }
    }
  }

  static bool _horaValida(Object? value) {
    if (value is! String || !RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) {
      return false;
    }
    final parts = value.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour <= 23 && minute <= 59;
  }
}

/// A local recipient check; this does not authenticate a person or encrypt files.
class PerfilPaciente {
  PerfilPaciente({required String nome, required this.nascimento})
    : nome = nome.trim() {
    if (normalizarNome(nome).isEmpty) {
      throw const FormatException('Informe seu nome completo.');
    }
    validarNascimento(nascimento);
  }
  final String nome;
  final String nascimento;
  Map<String, String> toJson() => {'nome': nome, 'nascimento': nascimento};
  factory PerfilPaciente.fromJson(Map<String, dynamic> data) => PerfilPaciente(
    nome: data['nome'] as String,
    nascimento: data['nascimento'] as String,
  );

  static void validarNascimento(String value) {
    DateTime date;
    try {
      date = Plano.parseDia(value);
    } catch (_) {
      throw const FormatException('Data de nascimento inválida.');
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date.year < 1900 || date.isAfter(today)) {
      throw const FormatException('Data de nascimento inválida.');
    }
  }

  static String normalizarNome(String value) {
    const grupos = {
      'a': 'áàâãä',
      'e': 'éèêë',
      'i': 'íìîï',
      'o': 'óòôõö',
      'u': 'úùûü',
      'c': 'ç',
      'n': 'ñ',
    };
    var result = value.toLowerCase();
    for (final entry in grupos.entries) {
      for (final char in entry.value.split('')) {
        result = result.replaceAll(char, entry.key);
      }
    }
    // Also accept decomposed accents from keyboard/file encodings.
    return result
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool corresponde(Plano plano) =>
      normalizarNome(nome) == normalizarNome(plano.nomePaciente) &&
      nascimento == plano.nascimentoPaciente;

  void conferir(Plano plano) {
    if (plano.nascimentoPaciente == null) {
      throw const FormatException(
        'O plano não informa a data de nascimento. Peça à profissional um plano com nome completo e nascimento.',
      );
    }
    if (!corresponde(plano)) {
      throw const FormatException(
        'Este plano não corresponde ao seu cadastro. Confira seu nome e nascimento ou peça à profissional que verifique o arquivo enviado.',
      );
    }
  }
}

class IntervaloSemana {
  const IntervaloSemana(this.de, this.ate);
  final DateTime de;
  final DateTime ate;
}

/// Returns the visible week fragment, clipped to plan boundaries and today.
IntervaloSemana semanaDoPlano(DateTime day, DateTime inicio, DateTime retorno) {
  final today = DateTime(day.year, day.month, day.day);
  final first = DateTime(inicio.year, inicio.month, inicio.day);
  final last = DateTime(retorno.year, retorno.month, retorno.day);
  final visibleDay = today.isBefore(first)
      ? first
      : today.isAfter(last)
      ? last
      : today;
  final monday = visibleDay.subtract(
    Duration(days: visibleDay.weekday - DateTime.monday),
  );
  final sunday = monday.add(const Duration(days: 6));
  final start = monday.isBefore(first) ? first : monday;
  final end = sunday.isAfter(last) ? last : sunday;
  return IntervaloSemana(start, end);
}

List<DateTime> diasDoPlano(DateTime inicio, DateTime retorno) => [
  for (
    var d = DateTime(inicio.year, inicio.month, inicio.day);
    !d.isAfter(DateTime(retorno.year, retorno.month, retorno.day));
    d = d.add(const Duration(days: 1))
  )
    d,
];
