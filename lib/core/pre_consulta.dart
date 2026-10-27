import 'dart:convert';
import 'dart:math';

import 'plano.dart';

/// Pre-consultation and follow-up reassessment envelopes, patient-reported.
/// Content mirrors the clinic's web form (term version 20/09/2026, rev. 2);
/// answers are stored raw, with no automatic clinical interpretation.
/// See docs/pre-consulta-e-pacientes.md.

const termoPreConsultaVersao = '20/09/2026, rev. 2';
const termosPreConsultaAceitos = {termoPreConsultaVersao};

const comorbidadesPreConsulta = [
  'Pressão alta (hipertensão)',
  'Diabetes tipo 2',
  'Pré-diabetes ou resistência à insulina',
  'Colesterol ou triglicérides altos',
  'Já teve infarto, AVC ou outro problema cardiovascular',
  'Problema nos rins',
  'Gordura no fígado (esteatose hepática)',
  'Ronco com pausas na respiração (apneia do sono)',
  'Ansiedade, depressão ou outro problema de humor',
  'Ácido úrico alto / gota',
  'Refluxo (azia frequente)',
  'Dor articular crônica (artrose)',
  'Problema de tireoide (hipo ou hipertireoidismo)',
];
const comorbidadeSop = 'Síndrome do ovário policístico (SOP)';
const historiaFamiliarPreConsulta = [
  'Problema cardíaco antes dos 55 anos (homem) ou 65 (mulher)',
  'Diabetes tipo 2',
  'Câncer antes dos 50 anos',
  'Problema nos rins',
];
const likert4 = [
  'Nunca',
  'Vários dias',
  'Mais da metade dos dias',
  'Quase todos os dias',
];
const phq2Itens = [
  'Pouco interesse ou prazer em fazer as coisas',
  'Se sentir para baixo, deprimida(o) ou sem perspectiva',
];
const gad2Itens = [
  'Se sentir nervosa(o), ansiosa(o) ou muito tensa(o)',
  'Não conseguir parar ou controlar as preocupações',
];
const alcoolOpcoes = [
  'Nunca',
  'Mensalmente ou menos',
  '2–4x/mês',
  '2–3x/semana',
  '4x/semana ou mais',
];
const tabagismoOpcoes = ['Nunca fumei', 'Já fumei, parei', 'Fumo atualmente'];
const restauradorOpcoes = ['Sim', 'Parcialmente', 'Não'];
const simNao = ['Sim', 'Não'];
const simNaoNaoSei = ['Sim', 'Não', 'Não sei'];
const cicloOpcoes = ['Regular', 'Irregular', 'Não menstruo'];
const itensReavaliacao = ['medidas', 'sono', 'humor'];

/// Plausible ranges for self-reported measures; outside them is a typo.
const faixasMedidas = {
  'peso': (20.0, 400.0),
  'altura': (80.0, 250.0),
  'cintura': (30.0, 300.0),
  'quadril': (30.0, 300.0),
};

/// Pre-consultation filled in the patient app before the first visit.
class PreConsulta {
  PreConsulta._(this.data);
  static const formato = 'plano-de-cuidado-pre-consulta';
  static const limiteBytes = 1024 * 1024;
  final Map<String, dynamic> data;

  String get id => data['id'] as String;
  DateTime get criadoEm => DateTime.parse(data['criadoEm'] as String);
  String get nomePaciente => data['paciente']['nome'] as String;
  String get nascimentoPaciente => data['paciente']['nascimento'] as String;
  Map<String, dynamic> get respostas =>
      data['respostas'] as Map<String, dynamic>;
  Map<String, dynamic> get medidas =>
      respostas['medidas'] as Map<String, dynamic>;
  double? get imc => calcularImc(medidas);
  double? get relacaoCinturaQuadril => calcularRcq(medidas);

  static PreConsulta criar(
    PerfilPaciente paciente,
    Map<String, dynamic> respostas, {
    required DateTime termoAceitoEm,
    DateTime? agora,
  }) {
    final now = agora ?? DateTime.now();
    return parse(
      jsonEncode({
        'formato': formato,
        'versao': 1,
        'id': novoIdEnvelope(),
        'criadoEm': now.toIso8601String(),
        'termo': {
          'versao': termoPreConsultaVersao,
          'aceitoEm': termoAceitoEm.toIso8601String(),
        },
        'paciente': paciente.toJson(),
        'respostas': respostas,
      }),
      agora: now,
    );
  }

  /// Empty answers in the exact shape the parser accepts.
  static Map<String, dynamic> respostasVazias() => {
    'ident': {
      'cpf': '',
      'sexo': null,
      'email': '',
      'nomeMae': '',
      'cep': '',
      'logradouro': '',
    },
    'saude': {
      'comorbidades': <String>[],
      'detalhes': <String, String>{},
      'outras': '',
      'cirurgias': '',
      'alergias': '',
      'historiaFamiliar': <String>[],
      'famDetalhes': <String, String>{},
    },
    'medidas': medidasVazias(),
    'alimentacao': {'emocional': null},
    'sono': sonoVazio(),
    'emocional': emocionalVazio(),
    'habitos': {'alcool': null, 'tabagismo': null, 'apoio': null},
    'hormonal': {'dum': null, 'ciclo': null, 'menopausa': null, 'hormonio': ''},
  };

  static PreConsulta parse(String source, {DateTime? agora}) {
    if (utf8.encode(source).length > limiteBytes) {
      throw const FormatException('A pré-consulta excede o limite de 1 MB.');
    }
    try {
      final d = jsonDecode(source);
      if (d is! Map<String, dynamic> || d['formato'] != formato) {
        throw const FormatException(
          'Selecione um arquivo de pré-consulta do paciente.',
        );
      }
      if (d['versao'] != 1) {
        throw const FormatException(
          'Versão de pré-consulta não suportada. Atualize o aplicativo.',
        );
      }
      _chaves(d, {
        'formato',
        'versao',
        'id',
        'criadoEm',
        'termo',
        'paciente',
        'respostas',
      });
      _id(d['id']);
      final criado = _instante(d['criadoEm'], agora);
      final termo = d['termo'] as Map<String, dynamic>;
      _chaves(termo, {'versao', 'aceitoEm'});
      if (!termosPreConsultaAceitos.contains(termo['versao'])) {
        throw const FormatException(
          'O termo de consentimento desta pré-consulta não é reconhecido.',
        );
      }
      if (_instante(termo['aceitoEm'], agora).isAfter(criado)) {
        throw const FormatException('Data de aceite do termo inválida.');
      }
      _paciente(d['paciente']);
      final r = d['respostas'] as Map<String, dynamic>;
      _chaves(r, {
        'ident',
        'saude',
        'medidas',
        'alimentacao',
        'sono',
        'emocional',
        'habitos',
        'hormonal',
      });
      final ident = r['ident'] as Map<String, dynamic>;
      _chaves(ident, {'cpf', 'sexo', 'email', 'nomeMae', 'cep', 'logradouro'});
      _opcao(ident['sexo'], const ['F', 'M']);
      final cpf = _texto(ident['cpf'], 14);
      if (cpf.isNotEmpty &&
          !RegExp(r'^\d{3}\.\d{3}\.\d{3}-\d{2}$').hasMatch(cpf)) {
        throw const FormatException('CPF em formato inválido.');
      }
      final cep = _texto(ident['cep'], 9);
      if (cep.isNotEmpty && !RegExp(r'^\d{5}-\d{3}$').hasMatch(cep)) {
        throw const FormatException('CEP em formato inválido.');
      }
      _texto(ident['email'], 200);
      _texto(ident['nomeMae'], 200);
      _texto(ident['logradouro'], 500);
      final feminino = ident['sexo'] == 'F';

      final saude = r['saude'] as Map<String, dynamic>;
      _chaves(saude, {
        'comorbidades',
        'detalhes',
        'outras',
        'cirurgias',
        'alergias',
        'historiaFamiliar',
        'famDetalhes',
      });
      _marcados(saude['comorbidades'], saude['detalhes'], [
        ...comorbidadesPreConsulta,
        if (feminino) comorbidadeSop,
      ]);
      _marcados(
        saude['historiaFamiliar'],
        saude['famDetalhes'],
        historiaFamiliarPreConsulta,
      );
      for (final k in ['outras', 'cirurgias', 'alergias']) {
        _texto(saude[k], 2000);
      }
      validarMedidas(r['medidas']);
      final alimentacao = r['alimentacao'] as Map<String, dynamic>;
      _chaves(alimentacao, {'emocional'});
      _inteiro(alimentacao['emocional'], 0, 10);
      validarSono(r['sono']);
      validarEmocional(r['emocional']);
      final habitos = r['habitos'] as Map<String, dynamic>;
      _chaves(habitos, {'alcool', 'tabagismo', 'apoio'});
      _inteiro(habitos['alcool'], 0, alcoolOpcoes.length - 1);
      _opcao(habitos['tabagismo'], tabagismoOpcoes);
      _inteiro(habitos['apoio'], 0, 10);
      final hormonal = r['hormonal'] as Map<String, dynamic>;
      _chaves(hormonal, {'dum', 'ciclo', 'menopausa', 'hormonio'});
      _opcao(hormonal['ciclo'], cicloOpcoes);
      _opcao(hormonal['menopausa'], simNaoNaoSei);
      final hormonio = _texto(hormonal['hormonio'], 500);
      if (hormonal['dum'] != null) {
        final dum = Plano.parseDia(hormonal['dum'] as String);
        if (dum.isAfter(criado) || dum.year < 1900) {
          throw const FormatException('Data da última menstruação inválida.');
        }
      }
      if (!feminino &&
          (hormonal['dum'] != null ||
              hormonal['ciclo'] != null ||
              hormonal['menopausa'] != null ||
              hormonio.isNotEmpty)) {
        throw const FormatException(
          'Saúde hormonal só é preenchida quando o sexo informado é feminino.',
        );
      }
      return PreConsulta._(d);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'O arquivo de pré-consulta está incompleto ou corrompido.',
      );
    }
  }
}

/// Short form the doctor requests per patient; answers only the chosen items.
class Reavaliacao {
  Reavaliacao._(this.data);
  static const formato = 'plano-de-cuidado-reavaliacao';
  static const limiteBytes = 256 * 1024;
  final Map<String, dynamic> data;

  String get id => data['id'] as String;
  DateTime get criadoEm => DateTime.parse(data['criadoEm'] as String);
  String get planoId => data['planoId'] as String;
  String get nomePaciente => data['paciente']['nome'] as String;
  String get nascimentoPaciente => data['paciente']['nascimento'] as String;
  List<String> get itens => (data['itens'] as List).cast<String>();
  Map<String, dynamic> get respostas =>
      data['respostas'] as Map<String, dynamic>;
  Map<String, dynamic>? get medidas =>
      respostas['medidas'] as Map<String, dynamic>?;
  double? get imc => medidas == null ? null : calcularImc(medidas!);
  double? get relacaoCinturaQuadril =>
      medidas == null ? null : calcularRcq(medidas!);

  /// Section of the answers each requested item fills.
  static const secaoDoItem = {
    'medidas': 'medidas',
    'sono': 'sono',
    'humor': 'emocional',
  };

  static Reavaliacao criar(
    PerfilPaciente paciente, {
    required String planoId,
    required List<String> itens,
    required Map<String, dynamic> respostas,
    DateTime? agora,
  }) {
    final now = agora ?? DateTime.now();
    return parse(
      jsonEncode({
        'formato': formato,
        'versao': 1,
        'id': novoIdEnvelope(),
        'criadoEm': now.toIso8601String(),
        'planoId': planoId,
        'paciente': paciente.toJson(),
        'itens': itens,
        'respostas': respostas,
      }),
      agora: now,
    );
  }

  static Reavaliacao parse(String source, {DateTime? agora}) {
    if (utf8.encode(source).length > limiteBytes) {
      throw const FormatException('A reavaliação excede o limite de 256 KB.');
    }
    try {
      final d = jsonDecode(source);
      if (d is! Map<String, dynamic> || d['formato'] != formato) {
        throw const FormatException(
          'Selecione um arquivo de reavaliação do paciente.',
        );
      }
      if (d['versao'] != 1) {
        throw const FormatException(
          'Versão de reavaliação não suportada. Atualize o aplicativo.',
        );
      }
      _chaves(d, {
        'formato',
        'versao',
        'id',
        'criadoEm',
        'planoId',
        'paciente',
        'itens',
        'respostas',
      });
      _id(d['id']);
      _instante(d['criadoEm'], agora);
      final planoId = d['planoId'];
      if (planoId is! String ||
          planoId.trim().isEmpty ||
          planoId.length > 100) {
        throw const FormatException('Plano da reavaliação inválido.');
      }
      _paciente(d['paciente']);
      final itens = (d['itens'] as List).cast<String>();
      validarItensReavaliacao(itens);
      final r = d['respostas'] as Map<String, dynamic>;
      _chaves(r, {for (final i in itens) secaoDoItem[i]!});
      if (itens.contains('medidas')) validarMedidas(r['medidas']);
      if (itens.contains('sono')) validarSono(r['sono']);
      if (itens.contains('humor')) validarEmocional(r['emocional']);
      return Reavaliacao._(d);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'O arquivo de reavaliação está incompleto ou corrompido.',
      );
    }
  }
}

Map<String, dynamic> medidasVazias() => {
  'peso': null,
  'altura': null,
  'cintura': null,
  'quadril': null,
};
Map<String, dynamic> sonoVazio() => {
  'horas': null,
  'restaurador': null,
  'acordaNoite': null,
  'acordaVezes': null,
  'acordaMotivo': '',
  'ronco': null,
  'pausas': null,
};
Map<String, dynamic> emocionalVazio() => {
  'phq2': [null, null],
  'gad2': [null, null],
};

/// Body mass index, one decimal; shown as a number only, never classified.
double? calcularImc(Map<String, dynamic> medidas) {
  final peso = medidas['peso'] as num?, altura = medidas['altura'] as num?;
  if (peso == null || altura == null) return null;
  final m = altura / 100;
  return (peso / (m * m) * 10).round() / 10;
}

/// Waist-to-hip ratio, two decimals; shown as a number only.
double? calcularRcq(Map<String, dynamic> medidas) {
  final cintura = medidas['cintura'] as num?;
  final quadril = medidas['quadril'] as num?;
  if (cintura == null || quadril == null) return null;
  return (cintura / quadril * 100).round() / 100;
}

void validarItensReavaliacao(List<String> itens) {
  if (itens.isEmpty ||
      itens.toSet().length != itens.length ||
      itens.any((i) => !itensReavaliacao.contains(i))) {
    throw const FormatException('Itens de reavaliação inválidos.');
  }
}

void validarMedidas(Object? raw) {
  final m = raw as Map<String, dynamic>;
  _chaves(m, faixasMedidas.keys.toSet());
  for (final e in faixasMedidas.entries) {
    final v = m[e.key];
    if (v == null) continue;
    if (v is! num || !v.isFinite || v < e.value.$1 || v > e.value.$2) {
      throw FormatException('Medida fora da faixa: ${e.key}.');
    }
  }
}

void validarSono(Object? raw) {
  final s = raw as Map<String, dynamic>;
  _chaves(s, {
    'horas',
    'restaurador',
    'acordaNoite',
    'acordaVezes',
    'acordaMotivo',
    'ronco',
    'pausas',
  });
  final horas = s['horas'];
  if (horas != null && (horas is! num || horas < 0 || horas > 24)) {
    throw const FormatException('Horas de sono inválidas.');
  }
  _opcao(s['restaurador'], restauradorOpcoes);
  _opcao(s['acordaNoite'], simNao);
  _inteiro(s['acordaVezes'], 0, 50);
  final motivo = _texto(s['acordaMotivo'], 1000);
  if (s['acordaNoite'] != 'Sim' &&
      (s['acordaVezes'] != null || motivo.isNotEmpty)) {
    throw const FormatException(
      'Detalhes de despertar só valem quando acorda durante a noite.',
    );
  }
  _opcao(s['ronco'], simNaoNaoSei);
  _opcao(s['pausas'], simNaoNaoSei);
}

void validarEmocional(Object? raw) {
  final e = raw as Map<String, dynamic>;
  _chaves(e, {'phq2', 'gad2'});
  for (final k in ['phq2', 'gad2']) {
    final itens = e[k] as List;
    if (itens.length != 2) {
      throw const FormatException('Escala de humor incompleta.');
    }
    for (final v in itens) {
      _inteiro(v, 0, likert4.length - 1);
    }
  }
}

String novoIdEnvelope() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

void _chaves(Map<String, dynamic> m, Set<String> esperadas) {
  if (m.length != esperadas.length || !m.keys.every(esperadas.contains)) {
    throw const FormatException('O arquivo contém campos fora do contrato.');
  }
}

void _id(Object? id) {
  if (id is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
    throw const FormatException('Identificador do arquivo inválido.');
  }
}

DateTime _instante(Object? raw, DateTime? agora) {
  final t = DateTime.parse(raw as String);
  // Small tolerance for clock differences between phones.
  if (t.isAfter((agora ?? DateTime.now()).add(const Duration(days: 1)))) {
    throw const FormatException('Data do arquivo no futuro.');
  }
  return t;
}

void _paciente(Object? raw) {
  final p = raw as Map<String, dynamic>;
  _chaves(p, {'nome', 'nascimento'});
  final perfil = PerfilPaciente.fromJson(p);
  if (PerfilPaciente.normalizarNome(perfil.nome).split(' ').length < 2) {
    throw const FormatException('Informe o nome completo do paciente.');
  }
}

String _texto(Object? v, int max) {
  if (v is! String || v.length > max) {
    throw const FormatException('Texto inválido ou longo demais.');
  }
  return v;
}

void _opcao(Object? v, List<String> opcoes) {
  if (v != null && !opcoes.contains(v)) {
    throw const FormatException('Resposta fora das opções.');
  }
}

void _inteiro(Object? v, int min, int max) {
  if (v != null && (v is! int || v < min || v > max)) {
    throw const FormatException('Valor fora da escala.');
  }
}

void _marcados(Object? lista, Object? detalhes, List<String> permitidos) {
  final itens = (lista as List).cast<String>();
  if (itens.toSet().length != itens.length ||
      itens.any((i) => !permitidos.contains(i))) {
    throw const FormatException('Item marcado fora da lista.');
  }
  final det = detalhes as Map<String, dynamic>;
  for (final e in det.entries) {
    if (!itens.contains(e.key)) {
      throw const FormatException('Detalhe de item não marcado.');
    }
    _texto(e.value, 1000);
  }
}
