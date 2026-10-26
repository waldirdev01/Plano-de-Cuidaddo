import 'dart:convert';
import 'dart:math';

import 'plano.dart';
import 'treino.dart';

/// A cumulative, patient-reported snapshot, not a prescription or a backup.
class RetornoAcompanhamento {
  RetornoAcompanhamento._(this.data, this.plano);
  static const formato = 'plano-de-cuidado-acompanhamento';
  static const limiteBytes = 5 * 1024 * 1024;
  final Map<String, dynamic> data;
  final Plano plano;
  String get id => data['id'] as String;
  DateTime get ate => Plano.parseDia(data['ate'] as String);
  DateTime get exportadoEm => DateTime.parse(data['exportadoEm'] as String);
  Map<String, dynamic> get registros =>
      data['registros'] as Map<String, dynamic>;

  /// Registros de treino por data, quando o plano tem treino.
  Map<String, dynamic> get registrosTreino =>
      (data['treino'] as Map<String, dynamic>?) ?? const {};

  static RetornoAcompanhamento criar(
    Plano plano,
    Map<String, Map<String, dynamic>> registros, {
    DateTime? agora,
  }) {
    final now = agora ?? DateTime.now();
    final hoje = DateTime(now.year, now.month, now.day);
    if (hoje.isBefore(plano.inicio)) {
      throw const FormatException(
        'O período de acompanhamento ainda não começou.',
      );
    }
    final fim = hoje.isAfter(plano.fim) ? plano.fim : hoje;
    final copia = jsonDecode(jsonEncode(plano.data)) as Map<String, dynamic>;
    // The original PDF, free clinical notes and personal URL are not needed
    // to read adherence. Do not send them back unnecessarily.
    copia.remove('pdf');
    copia.remove('secoes');
    copia['linkMonteSeuPrato'] = '';
    final campos = plano.camposRegistraveis.map((f) => f['id']).toSet();
    final recorte = <String, dynamic>{};
    for (final dia in registros.entries) {
      final d = Plano.parseDia(dia.key);
      if (d.isBefore(plano.inicio) || d.isAfter(fim)) continue;
      final valores = <String, dynamic>{
        for (final campo in dia.value.entries)
          if (campos.contains(campo.key) && campo.value != null)
            campo.key: campo.value,
      };
      if (valores.isNotEmpty) recorte[dia.key] = valores;
    }
    final treino = <String, dynamic>{};
    if (plano.data['treino'] != null) {
      for (final dia in registros.entries) {
        final d = Plano.parseDia(dia.key);
        if (d.isBefore(plano.inicio) || d.isAfter(fim)) continue;
        final valores = <String, dynamic>{
          for (final campo in dia.value.entries)
            if (campoDeTreino(campo.key) &&
                campo.value != null &&
                registroTreinoValido(campo.key, campo.value))
              campo.key: campo.value,
        };
        if (valores.isNotEmpty) treino[dia.key] = valores;
      }
    }
    final random = Random.secure();
    return parse(
      jsonEncode({
        'formato': formato,
        'versao': 1,
        'id': List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
        'exportadoEm': now.toIso8601String(),
        'de': Plano.formatDia(plano.inicio),
        'ate': Plano.formatDia(fim),
        'plano': copia,
        'registros': recorte,
        if (treino.isNotEmpty) 'treino': treino,
      }),
      agora: now,
    );
  }

  static RetornoAcompanhamento parse(String source, {DateTime? agora}) {
    if (utf8.encode(source).length > limiteBytes) {
      throw const FormatException('O acompanhamento excede o limite de 5 MB.');
    }
    try {
      final d = jsonDecode(source);
      if (d is! Map<String, dynamic> || d['formato'] != formato) {
        throw const FormatException(
          'Selecione um arquivo de acompanhamento do paciente.',
        );
      }
      if (d['versao'] != 1) {
        throw const FormatException(
          'Versão de acompanhamento não suportada. Atualize o aplicativo.',
        );
      }
      if (d['id'] is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(d['id'])) {
        throw const FormatException(
          'Identificador do acompanhamento inválido.',
        );
      }
      final p = Plano.parse(jsonEncode(d['plano']));
      if (p.data['versao'] != 4) {
        throw const FormatException(
          'A devolução de acompanhamento exige um plano conferido do modelo PDF atual (versão 4).',
        );
      }
      final de = Plano.parseDia(d['de'] as String);
      final ate = Plano.parseDia(d['ate'] as String);
      final now = agora ?? DateTime.now();
      final hoje = DateTime(now.year, now.month, now.day);
      final exportado = DateTime.parse(d['exportadoEm'] as String);
      if (de != p.inicio ||
          ate.isBefore(de) ||
          ate.isAfter(p.fim) ||
          ate.isAfter(hoje) ||
          ate.isAfter(
            DateTime(exportado.year, exportado.month, exportado.day),
          ) ||
          Plano.diasEntre(de, ate) > 3660 ||
          d['registros'] is! Map<String, dynamic>) {
        throw const FormatException('Período do acompanhamento inválido.');
      }
      final campos = {
        for (final f in p.camposRegistraveis) f['id'] as String: f,
      };
      for (final dia in (d['registros'] as Map<String, dynamic>).entries) {
        final data = Plano.parseDia(dia.key);
        if (data.isBefore(de) ||
            data.isAfter(ate) ||
            dia.value is! Map<String, dynamic>) {
          throw const FormatException(
            'Data de registro fora do acompanhamento.',
          );
        }
        for (final item in (dia.value as Map<String, dynamic>).entries) {
          final f = campos[item.key];
          if (f == null || !_valorValido(item.value, f)) {
            throw const FormatException(
              'O acompanhamento contém um campo ou valor inválido.',
            );
          }
        }
      }
      final tr = d['treino'];
      if (tr != null) {
        if (tr is! Map<String, dynamic> || p.data['treino'] == null) {
          throw const FormatException(
            'O acompanhamento contém registros de treino sem treino no plano.',
          );
        }
        for (final dia in tr.entries) {
          final data = Plano.parseDia(dia.key);
          if (data.isBefore(de) ||
              data.isAfter(ate) ||
              dia.value is! Map<String, dynamic>) {
            throw const FormatException(
              'Data de registro de treino fora do acompanhamento.',
            );
          }
          for (final item in (dia.value as Map<String, dynamic>).entries) {
            if (!campoDeTreino(item.key) ||
                !registroTreinoValido(item.key, item.value)) {
              throw const FormatException(
                'O acompanhamento contém um registro de treino inválido.',
              );
            }
          }
        }
      }
      return RetornoAcompanhamento._(d, p);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'O arquivo de acompanhamento está incompleto ou corrompido.',
      );
    }
  }

  static bool _valorValido(dynamic v, Map<String, dynamic> f) {
    if (v == null) return true;
    return switch (f['tipo']) {
      'refeicao' => ['feito', 'nao_feito', 'dispensado'].contains(v),
      'sim_nao' => v is bool,
      'contador' => v is num && v.isFinite && v >= 0,
      'escala' => v is num && v.isFinite && v >= f['min'] && v <= f['max'],
      'texto' => v is String && v.length <= 20000,
      'checklist' =>
        v is List && v.every((item) => (f['itens'] as List).contains(item)),
      _ => false,
    };
  }

  void conferirProfissional(String nome, String registro) {
    final profissional = plano.data['profissional'] as Map;
    String normalizar(String s) =>
        PerfilPaciente.normalizarNome(s).replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (nome.trim().isEmpty ||
        registro.trim().isEmpty ||
        PerfilPaciente.normalizarNome(nome) !=
            PerfilPaciente.normalizarNome(plano.nomeProfissional) ||
        normalizar(registro) !=
            normalizar(profissional['registro'] as String)) {
      throw const FormatException(
        'Este acompanhamento é destinado a outra profissional. Confira o nome e o registro em Perfil profissional.',
      );
    }
  }

  int get quantidadeRegistros => registros.values.fold(
    0,
    (n, dia) => n + (dia as Map).values.where((v) => v != null).length,
  );
}
