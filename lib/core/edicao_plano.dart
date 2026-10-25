import 'dart:convert';
import 'dart:math';

import 'plano.dart';

String novoId() {
  final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Map<String, dynamic> copiarDados(Map<String, dynamic> data) =>
    jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

Map<String, dynamic> novoPlano(String nome, String registro) {
  final now = DateTime.now();
  return {
    'formato': 'plano-de-cuidado',
    'versao': 3,
    'id': novoId(),
    'criadoEm': now.toIso8601String(),
    'profissional': {'nome': nome, 'registro': registro},
    'paciente': {'nome': '', 'nascimento': ''},
    'inicio': Plano.formatDia(now),
    'retorno': {
      'data': Plano.formatDia(now.add(const Duration(days: 14))),
      'hora': '13:30',
    },
    'envioSemanal': {'diaDaSemana': 5, 'ate': '18:00'},
    'metas': <Map<String, dynamic>>[],
    'camposDiarios': <Map<String, dynamic>>[],
    'secoes': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> duplicarPlano(
  Plano original,
  String nome,
  String registro,
) {
  if (original.data['versao'] == 4) {
    throw const FormatException(
      'Para outro paciente, preencha e importe um novo PDF no padrão. Não duplique uma exportação conferida.',
    );
  }
  final data = copiarDados(original.data);
  data['id'] = novoId();
  data['versao'] = 3;
  data['criadoEm'] = DateTime.now().toIso8601String();
  data['paciente'] = {'nome': '', 'nascimento': ''};
  data['profissional'] = {'nome': nome, 'registro': registro};
  // The attached document belongs to the original patient.
  data.remove('pdf');
  return data;
}

String nomeArquivoPlano(Plano plano) {
  var first = plano.nomePaciente
      .trim()
      .split(RegExp(r'\s+'))
      .first
      .toLowerCase();
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  for (var i = 0; i < from.length; i++) {
    first = first.replaceAll(from[i], to[i]);
  }
  first = first.replaceAll(RegExp('[^a-z0-9]'), '');
  if (first.isEmpty) first = 'paciente';
  return 'plano-$first-${plano.data['inicio']}.plano';
}

/// Templates only supply editable wording; clinical decisions stay with the author.
Map<String, dynamic> modeloCampo(String nome) => switch (nome) {
  'Refeições à mesa' => {
    'id': novoId(),
    'titulo': nome,
    'tipo': 'checklist',
    'itens': ['Café', 'Almoço', 'Jantar', 'Lanches'],
    'descricao': '',
    'seEntao': <String>[],
    'lembretes': <String>[],
  },
  'Água' => {
    'id': novoId(),
    'titulo': nome,
    'tipo': 'contador',
    'alvo': 0,
    'unidade': 'copos',
    'descricao': '',
    'seEntao': <String>[],
    'lembretes': <String>[],
  },
  'Nota do dia' => {
    'id': novoId(),
    'titulo': nome,
    'tipo': 'escala',
    'min': 1,
    'max': 10,
  },
  _ => {
    'id': novoId(),
    'titulo': nome == 'Criar do zero' ? '' : nome,
    'tipo': 'texto',
  },
};
