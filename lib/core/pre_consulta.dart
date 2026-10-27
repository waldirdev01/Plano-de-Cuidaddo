import 'dart:convert';
import 'dart:math';

import 'plano.dart';

/// Pre-consultation and follow-up reassessment envelopes, patient-reported.
/// Content mirrors the clinic's web form (term version 20/09/2026, rev. 2);
/// answers are stored raw, with no automatic clinical interpretation.
/// See docs/pre-consulta-e-pacientes.md.

const termoPreConsultaVersao = '20/09/2026, rev. 2';
const termosPreConsultaAceitos = {termoPreConsultaVersao};

/// Verbatim from the web form; the doctor chose to keep it for now even
/// though it describes WhatsApp/e-mail delivery (see the plan doc).
const termoPreConsultaParagrafos = [
  (
    'Quem é responsável. ',
    'Priscila Carvalho, médica (CRM-DF 36362), do Consultório Priscila Carvalho, é a responsável pelo tratamento dos seus dados neste formulário e no atendimento. Contato: prikroc@gmail.com.',
  ),
  (
    'O que este formulário pede. ',
    'Dados de identificação (nome, CPF, data de nascimento, sexo, e-mail, nome da mãe e endereço), informações de saúde (doenças, alergias, história da família, medidas, sono, humor, hábitos e saúde hormonal). Depois do formulário, o consultório poderá pedir, por mensagem, duas fotos do corpo (frente e perfil); enviá-las é opcional. São dados pessoais sensíveis, protegidos de forma especial pela Lei Geral de Proteção de Dados (LGPD, Lei nº 13.709/2018). Preencher é voluntário: você pode deixar em branco o que não quiser responder.',
  ),
  (
    'Para que serão usados. ',
    'Somente para abrir o seu prontuário, avaliar a sua saúde e conduzir a consulta e o acompanhamento. Se você enviar as fotos, elas serão usadas apenas para avaliar o seu corpo e acompanhar a sua evolução. As informações e as fotos não serão usadas em divulgação, redes sociais ou site, nem compartilhadas com terceiros para outras finalidades, salvo obrigação legal ou ordem judicial.',
  ),
  (
    'Como as informações chegam à médica. ',
    'O formulário não guarda o que você escreve em nenhum servidor: tudo fica neste aparelho até você enviar. Ao enviar, o resumo chega ao WhatsApp e/ou ao e-mail do consultório, que são serviços de terceiros com regras próprias. O WhatsApp do consultório é atendido por uma pessoa de apoio, que pode ler o resumo para organizar o atendimento, sem interpretar nem responder sobre o conteúdo, e que se compromete com o sigilo. O e-mail é acessado apenas pela médica. Se você enviar as fotos pelo WhatsApp, quem atende o consultório também poderá vê-las; se preferir, envie-as por e-mail, que só a médica acessa.',
  ),
  (
    'Sigilo e guarda. ',
    'Suas informações são protegidas pelo sigilo médico. O que for necessário ao seu atendimento é registrado no prontuário eletrônico, que a lei manda guardar por, no mínimo, 20 anos a partir do último registro.',
  ),
  (
    'Seus direitos. ',
    'Você pode pedir, a qualquer momento, confirmação de que tratamos os seus dados, acesso a eles, correção e informação sobre com quem foram compartilhados, e pode retirar a autorização para o uso das fotos. O que já estiver no prontuário precisa ser mantido durante o prazo legal. Fale com a médica pelo e-mail acima.',
  ),
  (
    'Atendimento por telemedicina. ',
    'A consulta é por videochamada, conforme a Resolução CFM nº 2.314/2022. Ela tem limites: não substitui o exame físico, e a médica pode indicar atendimento presencial ou outro serviço sempre que julgar necessário. Você pode recusar o atendimento por telemedicina.',
  ),
  (
    'Não é atendimento de urgência. ',
    'Em emergência, ligue 192 (SAMU); em crise emocional, 188 (CVV).',
  ),
  (
    'Ferramentas de apoio. ',
    'A médica pode usar ferramentas digitais de apoio (por exemplo, para calcular escalas e organizar as informações), cuidando para não expor os seus dados de identificação.',
  ),
  (
    'Aceite. ',
    'Ao marcar a caixa abaixo, declaro que li e entendi este termo, que preenchi o formulário com os meus dados e que concordo com o tratamento dos meus dados de saúde (e das fotos, se eu as enviar) nas condições acima e com o atendimento por telemedicina.',
  ),
];

/// Detail prompts shown when one of these items is ticked; like the web
/// form, other items have no detail box.
const detalheComorbidade = {
  'Problema nos rins': 'Que tipo de problema? Desde quando?',
  'Já teve infarto, AVC ou outro problema cardiovascular':
      'O que foi e em que ano?',
  'Ansiedade, depressão ou outro problema de humor': 'Qual? Desde quando?',
  'Problema de tireoide (hipo ou hipertireoidismo)': 'Qual? Desde quando?',
};
const detalheFamilia = {
  'Câncer antes dos 50 anos':
      'Que tipo de câncer? Quem teve (mãe, pai, irmã...) e com que idade?',
  'Problema nos rins': 'Que tipo de problema? Quem teve e com que idade?',
  'Problema cardíaco antes dos 55 anos (homem) ou 65 (mulher)':
      'O que foi (infarto, AVC...)? Quem teve e com que idade?',
};
const videoMedidasPreConsulta = 'https://youtu.be/nKkxE4-zBAE';

/// Clinic address named in the consent term; the e-mail button sends here.
const emailConsultorio = 'prikroc@gmail.com';

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
    'ident': <String, dynamic>{
      'cpf': '',
      'sexo': null,
      'email': '',
      'nomeMae': '',
      'cep': '',
      'logradouro': '',
    },
    'saude': <String, dynamic>{
      'comorbidades': <dynamic>[],
      'detalhes': <String, dynamic>{},
      'outras': '',
      'cirurgias': '',
      'alergias': '',
      'historiaFamiliar': <dynamic>[],
      'famDetalhes': <String, dynamic>{},
    },
    'medidas': medidasVazias(),
    'alimentacao': <String, dynamic>{'emocional': null},
    'sono': sonoVazio(),
    'emocional': emocionalVazio(),
    'habitos': <String, dynamic>{
      'alcool': null,
      'tabagismo': null,
      'apoio': null,
    },
    'hormonal': <String, dynamic>{
      'dum': null,
      'ciclo': null,
      'menopausa': null,
      'hormonio': '',
    },
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

/// Readable summary in the web form's wording, for the e-mail body and the
/// doctor's record. Lists answers only; no scores or classifications.
String resumoPreConsulta(PreConsulta p) {
  final r = p.respostas;
  final ident = r['ident'] as Map<String, dynamic>;
  final saude = r['saude'] as Map<String, dynamic>;
  final linhas = <String>[];
  void add(String s) => linhas.add(s);
  void secao(String titulo) => linhas.addAll(['', titulo]);
  String data(String iso) => iso.split('-').reversed.join('/');
  String ou(Object? v, String vazio) =>
      v == null || (v is String && v.trim().isEmpty) ? vazio : '$v';
  String numero(num v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toString().replaceAll('.', ',');
  String comDetalhes(List lista, Map detalhes) => lista
      .map((x) {
        final d = (detalhes[x] as String? ?? '').trim();
        return d.isEmpty ? '$x' : '$x ($d)';
      })
      .join('; ');

  add(
    'FORMULÁRIO DE PRÉ-CONSULTA — ${p.nomePaciente} — ${data(Plano.formatDia(p.criadoEm))}',
  );
  add(
    'Termo de consentimento (versão ${p.data['termo']['versao']}): aceito em ${data(Plano.formatDia(DateTime.parse(p.data['termo']['aceitoEm'] as String)))}.',
  );
  secao('IDENTIFICAÇÃO (para abertura de prontuário)');
  add('Nome: ${p.nomePaciente}');
  add('CPF: ${ou(ident['cpf'], '—')}');
  add('Nascimento: ${data(p.nascimentoPaciente)}');
  add('E-mail: ${ou(ident['email'], '—')}');
  add('Nome da mãe: ${ou(ident['nomeMae'], '—')}');
  final endereco = (ident['logradouro'] as String).trim();
  final cep = ident['cep'] as String;
  if (endereco.isNotEmpty || cep.isNotEmpty) {
    add(
      'Endereço: $endereco${endereco.isNotEmpty && cep.isNotEmpty ? ' — ' : ''}${cep.isEmpty ? '' : 'CEP $cep'}',
    );
  }
  if (ident['sexo'] != null) add('Sexo: ${ident['sexo']}');

  secao('ANTECEDENTES');
  final comorb = saude['comorbidades'] as List;
  add(
    comorb.isEmpty
        ? 'Nega comorbidades'
        : comDetalhes(comorb, saude['detalhes'] as Map),
  );
  if ((saude['outras'] as String).trim().isNotEmpty) {
    add('Outras: ${saude['outras']}');
  }
  if ((saude['cirurgias'] as String).trim().isNotEmpty) {
    add('Cirurgias: ${saude['cirurgias']}');
  }
  add('Alergias: ${ou(saude['alergias'], 'nenhuma referida')}');
  final fam = saude['historiaFamiliar'] as List;
  add(
    'História familiar: ${fam.isEmpty ? 'nenhuma referida' : comDetalhes(fam, saude['famDetalhes'] as Map)}',
  );

  secao('MEDIDAS (autorreferidas)');
  final m = p.medidas;
  final medidas = [
    for (final (k, u) in [
      ('peso', 'kg'),
      ('altura', 'cm'),
      ('cintura', 'cm'),
      ('quadril', 'cm'),
    ])
      if (m[k] != null) '$k ${numero(m[k] as num)}$u',
  ];
  add(medidas.isEmpty ? 'não preenchidas' : medidas.join(', '));
  if (p.imc != null) add('IMC: ${numero(p.imc!)}');
  if (p.relacaoCinturaQuadril != null) {
    add('Relação cintura-quadril: ${numero(p.relacaoCinturaQuadril!)}');
  }

  secao('HÁBITOS');
  final h = r['habitos'] as Map<String, dynamic>;
  final emocional = r['alimentacao']['emocional'];
  final habitos = [
    if (emocional != null) 'comer emocional $emocional/10',
    if (h['alcool'] != null)
      'álcool: ${alcoolOpcoes[h['alcool'] as int].toLowerCase()}',
    if (h['tabagismo'] != null)
      'cigarro: ${(h['tabagismo'] as String).toLowerCase()}',
    if (h['apoio'] != null)
      'apoio de família/pessoas próximas (0-10): ${h['apoio']}',
  ];
  add(habitos.isEmpty ? 'não respondido' : habitos.join(', '));

  secao('SONO');
  final s = r['sono'] as Map<String, dynamic>;
  final despertar = [
    if (s['acordaVezes'] != null) '${s['acordaVezes']}x por noite',
    if ((s['acordaMotivo'] as String).trim().isNotEmpty)
      'motivo: ${s['acordaMotivo']}',
  ];
  final sono = [
    if (s['horas'] != null) '${numero(s['horas'] as num)}h/noite',
    if (s['restaurador'] != null)
      'restaurador: ${(s['restaurador'] as String).toLowerCase()}',
    if (s['ronco'] != null) 'ronco: ${(s['ronco'] as String).toLowerCase()}',
    if (s['acordaNoite'] == 'Sim')
      'acorda à noite: sim${despertar.isEmpty ? '' : ' (${despertar.join('; ')})'}'
    else if (s['acordaNoite'] == 'Não')
      'acorda à noite: não',
    if (s['pausas'] != null)
      'pausas observadas: ${(s['pausas'] as String).toLowerCase()}',
  ];
  add(sono.isEmpty ? 'não respondido' : sono.join(', '));

  secao('HUMOR (últimas 2 semanas, respostas)');
  final e = r['emocional'] as Map<String, dynamic>;
  final humor = [
    for (final (chave, itens) in [('phq2', phq2Itens), ('gad2', gad2Itens)])
      for (var i = 0; i < itens.length; i++)
        if ((e[chave] as List)[i] != null)
          '${itens[i]}: ${likert4[(e[chave] as List)[i] as int]}',
  ];
  if (humor.isEmpty) {
    add('não respondido');
  } else {
    humor.forEach(add);
  }

  if (ident['sexo'] == 'F') {
    secao('SAÚDE HORMONAL');
    final hm = r['hormonal'] as Map<String, dynamic>;
    final hormonal = [
      if (hm['dum'] != null) 'DUM ${data(hm['dum'] as String)}',
      if (hm['ciclo'] != null) 'ciclo ${(hm['ciclo'] as String).toLowerCase()}',
      if (hm['menopausa'] != null)
        'menopausa: ${(hm['menopausa'] as String).toLowerCase()}',
      if ((hm['hormonio'] as String).trim().isNotEmpty)
        'hormônio/ACO: ${hm['hormonio']}',
    ];
    add(hormonal.isEmpty ? 'não respondido' : hormonal.join(', '));
  }
  return linhas.join('\n');
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

Map<String, dynamic> medidasVazias() => <String, dynamic>{
  'peso': null,
  'altura': null,
  'cintura': null,
  'quadril': null,
};
Map<String, dynamic> sonoVazio() => <String, dynamic>{
  'horas': null,
  'restaurador': null,
  'acordaNoite': null,
  'acordaVezes': null,
  'acordaMotivo': '',
  'ronco': null,
  'pausas': null,
};
Map<String, dynamic> emocionalVazio() => <String, dynamic>{
  'phq2': <dynamic>[null, null],
  'gad2': <dynamic>[null, null],
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
