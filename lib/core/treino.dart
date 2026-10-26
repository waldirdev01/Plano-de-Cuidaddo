import 'dart:math' as math;

/// Prescrição de treino por regras fixas, sem IA e sem rede.
///
/// O `.plano` guarda só os parâmetros clínicos (bloco `treino`). O app calcula
/// o programa de 4 semanas no aparelho, a partir do local, dos dias e do tempo
/// que o paciente escolhe. Mesma entrada, mesma saída.

const niveisTreino = {
  1: 'Iniciante: sedentária ou sem treino de força regular',
  2: 'Intermediário: treina força há 6 meses ou mais',
  3: 'Avançado: treina força há 2 anos ou mais, com técnica segura',
};
const nomesNivelTreino = {1: 'Iniciante', 2: 'Intermediário', 3: 'Avançado'};
const objetivosTreino = {
  'perda': 'Perda de gordura e de peso',
  'recomp': 'Ganho de massa muscular e recomposição corporal',
  'saude': 'Saúde geral e condicionamento',
  'manut': 'Manutenção após perda de peso',
};
const limitacoesTreino = {
  'j': 'Joelho',
  'o': 'Ombro',
  'l': 'Coluna lombar',
};
const locaisForcaTreino = {
  'c': 'Casa, sem equipamento',
  'h': 'Casa, com halteres e elásticos',
  'a': 'Academia',
};
const locaisAerobicoTreino = {
  'rua': 'Ao ar livre (rua ou parque)',
  'aparelho': 'Aparelho (esteira, bicicleta, elíptico)',
  'casa': 'Em casa, sem equipamento',
};
const diasDaSemanaTreino = [
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
  'Domingo',
];
const _titulosTipo = {'F': 'Corpo todo', 'U': 'Parte superior', 'L': 'Parte inferior'};
const _isometriaSeg = [
  [20, 25, 30, 30],
  [30, 35, 40, 40],
  [40, 45, 50, 60],
];

/// Bloco `treino` do `.plano`: o que a médica define. A triagem negativa e,
/// no pós-parto, a liberação são obrigatórias para o arquivo ser aceito.
class PrescricaoTreino {
  PrescricaoTreino({
    required this.nivel,
    required this.objetivo,
    this.limitacoes = const [],
    this.posParto = false,
  });

  final int nivel;
  final String objetivo;
  final List<String> limitacoes;
  final bool posParto;

  factory PrescricaoTreino.fromMap(Map<dynamic, dynamic> m) {
    validar(m);
    return PrescricaoTreino(
      nivel: m['nivel'] as int,
      objetivo: m['objetivo'] as String,
      limitacoes: [
        for (final x in (m['limitacoes'] as List? ?? const [])) x as String,
      ],
      posParto: m['posParto'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'nivel': nivel,
    'objetivo': objetivo,
    'limitacoes': limitacoes,
    'posParto': posParto,
    'triagemNegativa': true,
    if (posParto) 'liberacaoPosParto': true,
  };

  static void validar(Object? raw) {
    if (raw is! Map ||
        raw['nivel'] is! int ||
        !niveisTreino.containsKey(raw['nivel']) ||
        raw['objetivo'] is! String ||
        !objetivosTreino.containsKey(raw['objetivo'])) {
      throw const FormatException('O bloco de treino do plano está incompleto.');
    }
    final lim = raw['limitacoes'];
    if (lim != null &&
        (lim is! List ||
            lim.any((x) => x is! String || !limitacoesTreino.containsKey(x)) ||
            lim.toSet().length != lim.length)) {
      throw const FormatException('As limitações do treino são inválidas.');
    }
    if (raw['triagemNegativa'] != true) {
      throw const FormatException(
        'O treino exige triagem de segurança negativa confirmada pela profissional.',
      );
    }
    final pp = raw['posParto'];
    if (pp != null && pp is! bool) {
      throw const FormatException('O campo pós-parto do treino é inválido.');
    }
    if (pp == true && raw['liberacaoPosParto'] != true) {
      throw const FormatException(
        'Treino no pós-parto exige liberação confirmada pela profissional.',
      );
    }
  }
}

/// Escolhas do paciente. Não alteram a segurança, só a logística.
class EscolhasTreino {
  const EscolhasTreino({
    this.local = 'c',
    this.aerobico = 'rua',
    this.dias = 3,
    this.minutos = 45,
  });
  final String local, aerobico;
  final int dias, minutos;

  Map<String, dynamic> toMap() => {
    'local': local,
    'aerobico': aerobico,
    'dias': dias,
    'minutos': minutos,
  };

  factory EscolhasTreino.fromMap(Object? raw) {
    if (raw is! Map) return const EscolhasTreino();
    final local = raw['local'];
    final aero = raw['aerobico'];
    final dias = raw['dias'];
    final min = raw['minutos'];
    return EscolhasTreino(
      local: locaisForcaTreino.containsKey(local) ? local as String : 'c',
      aerobico: locaisAerobicoTreino.containsKey(aero) ? aero as String : 'rua',
      dias: dias is int && dias >= 2 && dias <= 6 ? dias : 3,
      minutos: min is int && const [20, 30, 45, 60].contains(min) ? min : 45,
    );
  }
}

class Variante {
  const Variante(
    this.nome,
    this.dica,
    this.locais,
    this.nivelMin,
    this.nivelMax, {
    this.unilateral = false,
    this.isometria,
    this.evitar = const [],
    this.exigir,
    this.preferir,
  });
  final String nome, dica, locais;
  final int nivelMin, nivelMax;
  final bool unilateral;
  final String? isometria;
  final List<String> evitar;
  final List<String>? exigir;
  final List<String>? preferir;
}

class Padrao {
  const Padrao(this.tipo, this.papel, this.variantes);
  final String tipo, papel;
  final List<Variante> variantes;
}

final Map<String, Padrao> _banco = {
  "SQUAT": Padrao("lower", "main", [
    Variante("Agachamento parcial (amplitude sem dor)", "Desça só até onde não houver dor no joelho.", "cha", 1, 3, exigir: ["j"]),
    Variante("Leg press com amplitude curta", "Amplitude curta, sem dor.", "a", 1, 3, exigir: ["j"]),
    Variante("Agachamento livre ou no Smith", "Desça até as coxas ficarem paralelas ao chão, coluna firme.", "a", 2, 3, evitar: ["j"]),
    Variante("Hack squat", "Pés na largura dos ombros, desça com controle.", "a", 3, 3, evitar: ["j"]),
    Variante("Leg press 45°", "Não deixe o quadril descolar do banco ao descer.", "a", 1, 3, evitar: ["j"]),
    Variante("Agachamento com pausa de 2 s", "Pare 2 segundos embaixo, joelhos na direção dos pés.", "c", 2, 3, evitar: ["j"]),
    Variante("Sentar e levantar da cadeira", "Levante sem usar as mãos, desça devagar.", "c", 1, 1, evitar: ["j"]),
    Variante("Agachamento goblet com halter", "Halter junto ao peito, cotovelos para baixo.", "h", 1, 3, evitar: ["j"]),
  ]),
  "HINGE": Padrao("lower", "main", [
    Variante("Stiff com halteres ou barra", "Quadril para trás, coluna neutra, sinta o posterior da coxa.", "a", 2, 3, evitar: ["l"]),
    Variante("Stiff com halteres leves", "Quadril para trás, coluna neutra.", "a", 1, 1, evitar: ["l"]),
    Variante("Stiff com halteres", "Quadril para trás, coluna neutra, sinta o posterior da coxa.", "h", 1, 3, evitar: ["l"]),
    Variante("Mesa flexora", "Suba e desça devagar, sem tirar o quadril do banco.", "a", 1, 3),
    Variante("Ponte de glúteos com carga", "Halter sobre o quadril, suba apertando o glúteo.", "ha", 1, 3),
    Variante("Ponte de glúteos unilateral", "Uma perna por vez, quadril nivelado.", "c", 2, 3, unilateral: true),
    Variante("Stiff unilateral com peso do corpo", "Apoie uma perna, incline o tronco, braços à frente.", "c", 3, 3, unilateral: true, evitar: ["l"]),
    Variante("Ponte de glúteos", "Pés firmes no chão, suba o quadril e aperte o glúteo no topo.", "c", 1, 2),
  ]),
  "UNI": Padrao("lower", "main", [
    Variante("Elevação pélvica unilateral", "Uma perna por vez, quadril nivelado.", "cha", 1, 3, unilateral: true, exigir: ["j"]),
    Variante("Agachamento búlgaro com halteres", "Pé de trás no banco, tronco firme.", "ha", 3, 3, unilateral: true, evitar: ["j"]),
    Variante("Agachamento búlgaro (pé de trás no sofá)", "Tronco firme, joelho da frente alinhado ao pé.", "c", 3, 3, unilateral: true, evitar: ["j"]),
    Variante("Avanço com halteres (passo para trás)", "Dê um passo para trás e desça controlando o tronco.", "ha", 2, 3, unilateral: true, evitar: ["j"]),
    Variante("Afundo alternado (sem peso)", "Passo para trás, joelho da frente alinhado ao pé.", "c", 1, 2, unilateral: true, evitar: ["j"]),
    Variante("Subida no degrau (step-up)", "Suba empurrando com a perna de cima, desça devagar.", "cha", 1, 3, unilateral: true, evitar: ["j"]),
  ]),
  "PUSHH": Padrao("push", "main", [
    Variante("Supino reto com halteres ou barra", "Escápulas firmes no banco, desça até o peito.", "a", 2, 3, evitar: ["o"]),
    Variante("Supino em máquina", "Ombros para trás e para baixo, empurre sem travar o cotovelo.", "a", 1, 3),
    Variante("Flexão com pés elevados", "Pés no sofá, corpo em linha reta.", "ch", 3, 3, evitar: ["o"]),
    Variante("Flexão no chão", "Corpo em linha reta, cotovelos a 45°.", "ch", 2, 3),
    Variante("Supino no chão com halteres", "Cotovelos tocam o chão, empurre para cima.", "h", 1, 3),
    Variante("Flexão com joelhos apoiados", "Corpo em linha do joelho à cabeça.", "ch", 1, 2),
    Variante("Flexão inclinada (mãos na bancada ou sofá)", "Quanto mais alto o apoio, mais leve.", "ch", 1, 1),
  ]),
  "PUSHV": Padrao("push", "main", [
    Variante("Desenvolvimento com halteres sentado", "Empurre para cima sem arquear a lombar.", "a", 2, 3, evitar: ["o"]),
    Variante("Desenvolvimento em máquina", "Empurre sem arquear a lombar.", "a", 1, 3, evitar: ["o"]),
    Variante("Desenvolvimento com halteres", "Empurre para cima sem arquear a lombar.", "h", 1, 3, evitar: ["o"]),
    Variante("Flexão pike (quadril alto)", "Mãos no chão, quadril para cima, desça a cabeça entre as mãos.", "c", 3, 3, evitar: ["o"]),
    Variante("Elevação lateral com garrafas de água", "Suba até a altura dos ombros, sem balançar.", "c", 1, 2, evitar: ["o"]),
  ]),
  "PULLH": Padrao("pull", "main", [
    Variante("Remada sentada em máquina ou cabo", "Puxe os cotovelos para trás, peito aberto.", "a", 1, 3),
    Variante("Remada curvada com barra", "Tronco firme, puxe até o abdômen.", "a", 3, 3, evitar: ["l"]),
    Variante("Remada unilateral com halter", "Apoie a mão no banco, puxe o cotovelo junto ao corpo.", "ha", 1, 3, unilateral: true),
    Variante("Remada com elástico sentada", "Puxe os cotovelos para trás, sem encolher os ombros.", "h", 1, 3),
    Variante("Remada invertida na mesa firme", "Deite sob uma mesa estável e puxe o peito até a borda.", "c", 2, 3),
    Variante("Remada curvada com mochila (apoio no sofá)", "Apoie a mão no sofá, puxe o cotovelo junto ao corpo.", "c", 1, 3, unilateral: true),
  ]),
  "PULLV": Padrao("pull", "main", [
    Variante("Barra fixa (com ajuda, se precisar)", "Puxe o peito em direção à barra.", "a", 3, 3),
    Variante("Puxada na frente (pulley)", "Puxe a barra até a altura do queixo, peito aberto.", "a", 1, 3),
    Variante("Puxada com elástico fixado no alto", "Puxe os cotovelos para baixo e para trás.", "h", 1, 3),
    Variante("Extensão de costas em Y (deitada de bruços)", "Braços em Y, suba o peito poucos centímetros.", "c", 1, 3, evitar: ["l"]),
  ]),
  "COREA": Padrao("core", "core", [
    Variante("Prancha inclinada (mãos na bancada ou sofá)", "Costelas fechadas, sem arquear a lombar.", "cha", 1, 3, isometria: "iso", preferir: ["p"]),
    Variante("Dead bug (inseto morto)", "Lombar no chão, mova braço e perna opostos devagar.", "cha", 1, 3, isometria: "dyn", preferir: ["p"]),
    Variante("Prancha", "Corpo em linha reta, abdômen firme, respiração normal.", "cha", 2, 3, isometria: "iso", evitar: ["p"]),
    Variante("Prancha sobre os joelhos", "Corpo em linha do joelho à cabeça.", "cha", 1, 1, isometria: "iso", evitar: ["p"]),
  ]),
  "COREB": Padrao("core", "core", [
    Variante("Bird-dog", "Estenda braço e perna opostos sem girar o quadril.", "cha", 1, 3, unilateral: true, isometria: "dyn", preferir: ["l", "p"]),
    Variante("Prancha lateral", "Cotovelo sob o ombro, quadril alto.", "cha", 2, 3, unilateral: true, isometria: "iso", evitar: ["p"]),
    Variante("Prancha lateral sobre os joelhos", "Cotovelo sob o ombro, quadril alto.", "cha", 1, 1, unilateral: true, isometria: "iso", evitar: ["p"]),
  ]),
  "COREC": Padrao("core", "core", [
    Variante("Pallof press com elástico", "Segure o elástico no peito e resista à rotação.", "ha", 2, 3, unilateral: true, isometria: "dyn"),
    Variante("Bird-dog", "Estenda braço e perna opostos sem girar o quadril.", "cha", 1, 3, unilateral: true, isometria: "dyn"),
    Variante("Dead bug (inseto morto)", "Lombar no chão, mova braço e perna opostos devagar.", "cha", 1, 3, isometria: "dyn"),
  ]),
  "CALF": Padrao("calf", "acc", [
    Variante("Elevação de panturrilha em pé (degrau)", "Suba na ponta dos pés, desça devagar.", "c", 1, 3),
    Variante("Elevação de panturrilha com halteres", "Suba na ponta dos pés, desça devagar.", "h", 1, 3),
    Variante("Panturrilha em pé (máquina ou degrau)", "Amplitude completa, pausa no topo.", "a", 1, 3),
  ]),
  "HAMCURL": Padrao("lower", "acc", [
    Variante("Mesa flexora", "Suba e desça devagar, sem tirar o quadril do banco.", "a", 1, 3),
    Variante("Flexão de joelhos deslizando (toalha no chão)", "Deitada, quadril alto, puxe os calcanhares.", "ch", 2, 3),
  ]),
  "LATR": Padrao("push", "acc", [
    Variante("Elevação lateral com halteres", "Suba até a altura dos ombros, sem balançar.", "ha", 1, 3, evitar: ["o"]),
    Variante("Elevação lateral com garrafas de água", "Suba até a altura dos ombros, sem balançar.", "c", 1, 3, evitar: ["o"]),
  ]),
  "BICEPS": Padrao("pull", "acc", [
    Variante("Rosca direta com halteres", "Cotovelos colados ao corpo.", "ha", 1, 3),
    Variante("Rosca com garrafas ou mochila", "Cotovelos colados ao corpo.", "c", 1, 3),
  ]),
  "TRICEPS": Padrao("push", "acc", [
    Variante("Tríceps na polia (corda)", "Cotovelos colados ao corpo.", "a", 1, 3),
    Variante("Tríceps francês com halter", "Cotovelos apontados para cima.", "h", 1, 3, evitar: ["o"]),
    Variante("Flexão fechada (mãos juntas)", "Cotovelos junto ao corpo.", "c", 2, 3, evitar: ["o"]),
  ]),
};

final Map<String, Map<String, List<String>>> _modelos = {
  "F": {
    "A": ["SQUAT", "PUSHH", "PULLH", "COREA", "HINGE", "PUSHV", "PULLV"],
    "B": ["HINGE", "PUSHV", "PULLV", "COREB", "UNI", "PUSHH", "PULLH"],
    "C": ["UNI", "PUSHH", "PULLH", "COREC", "SQUAT"],
  },
  "U": {
    "A": ["PUSHH", "PULLH", "PUSHV", "COREA", "PULLV", "LATR", "TRICEPS", "BICEPS"],
    "B": ["PULLV", "PUSHV", "PULLH", "COREC", "PUSHH", "TRICEPS", "BICEPS"],
  },
  "L": {
    "A": ["SQUAT", "HINGE", "UNI", "COREA", "CALF", "HAMCURL"],
    "B": ["HINGE", "SQUAT", "UNI", "COREB", "HAMCURL", "CALF"],
  },
};

final Map<String, List<List<Object>>> _agendas = {
  "2-2": [[1, "F"], [4, "F"]],
  "3-3": [[0, "F"], [2, "F"], [4, "F"]],
  "3-2": [[0, "F"], [2, "X"], [4, "F"]],
  "4-4": [[0, "U"], [1, "L"], [3, "U"], [4, "L"]],
  "4-3": [[0, "F"], [1, "X"], [3, "F"], [5, "F"]],
  "4-2": [[0, "F"], [1, "X"], [3, "F"], [5, "X"]],
  "5-4": [[0, "U"], [1, "L"], [2, "X"], [4, "U"], [5, "L"]],
  "5-3": [[0, "F"], [1, "X"], [3, "F"], [4, "X"], [5, "F"]],
  "5-2": [[0, "F"], [1, "X"], [3, "F"], [4, "X"], [5, "X"]],
  "6-4": [[0, "U"], [1, "L"], [2, "X"], [3, "U"], [4, "L"], [5, "X"]],
  "6-3": [[0, "F"], [1, "X"], [2, "F"], [3, "X"], [4, "F"], [5, "X"]],
  "6-2": [[0, "F"], [1, "X"], [2, "X"], [3, "F"], [4, "X"], [5, "X"]],
};

const List<List<String>> _esforcoPorNivel = [["3–4", "3–4", "3", "2–3"], ["3–4", "3", "2–3", "2"], ["3", "2–3", "2", "1–2"]];

// ---------------------------------------------------------------------------
// Saída do motor

class SemanaItem {
  const SemanaItem(this.series, this.texto);
  final int series;
  final String texto;
}

class ItemTreino {
  const ItemTreino({
    required this.rotulo,
    required this.nome,
    required this.dica,
    required this.unilateral,
    required this.papel,
    required this.semanas,
    required this.pausa,
    required this.emPar,
  });
  final String rotulo, nome, dica, papel, pausa;
  final bool unilateral, emPar;
  final List<SemanaItem> semanas;

  /// Identificador estável do exercício para os registros do paciente.
  String get chave => chaveExercicio(nome);
}

class AeroIntervalado {
  const AeroIntervalado({
    required this.series,
    required this.forteMin,
    required this.leveMin,
    required this.esforco,
    required this.modalidade,
  });
  final int series;
  final double forteMin, leveMin;
  final String esforco, modalidade;
}

class DiaTreino {
  const DiaTreino({
    required this.indice,
    required this.tipo,
    required this.titulo,
    this.itens = const [],
    this.estimativaMin = 0,
    this.emPares = false,
    this.minutos = const [],
    this.modalidade = '',
    this.intervalado = const [],
  });

  /// 0 = segunda ... 6 = domingo.
  final int indice;

  /// 'S' força, 'C' aeróbico, 'R' descanso ativo.
  final String tipo;
  final String titulo;
  final List<ItemTreino> itens;
  final int estimativaMin;
  final bool emPares;
  final List<int> minutos;
  final String modalidade;
  final List<AeroIntervalado?> intervalado;

  String get nome => diasDaSemanaTreino[indice];
}

class ProgramaTreino {
  const ProgramaTreino({
    required this.dias,
    required this.aeroPorSemana,
    required this.metaPorSemana,
    required this.esforco,
  });
  final List<DiaTreino> dias;
  final List<int> aeroPorSemana, metaPorSemana;
  final List<String> esforco;
}

String chaveExercicio(String nome) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final b = StringBuffer();
  for (final r in nome.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    b.write(i >= 0 ? para[i] : c);
  }
  final s = b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return s.replaceAll(RegExp(r'^_+|_+$'), '');
}

// ---------------------------------------------------------------------------
// Motor

class _Ctx {
  _Ctx(this.n, this.o, this.dias, this.minutos, this.local, this.aero, this.lim, this.pp);
  final int n, dias, minutos;
  final String o, local, aero;
  final List<String> lim;
  final bool pp;
}

class _Cand {
  _Cand(this.v, this.papel, this.tipo);
  final Variante v;
  final String papel, tipo;
}

bool _temAlgum(List<String> a, List<String> b) => a.any(b.contains);

List<Variante> _pickNivel(String pat, _Ctx c, int nivel) => [
  for (final v in _banco[pat]!.variantes)
    if (v.locais.contains(c.local) &&
        nivel >= v.nivelMin &&
        nivel <= v.nivelMax &&
        !_temAlgum(v.evitar, c.lim) &&
        (v.exigir == null || _temAlgum(v.exigir!, c.lim)))
      v,
];

Variante? _pick(String pat, _Ctx c, int occ) {
  var vs = <Variante>[];
  for (var nivel = c.n; nivel >= 1 && vs.isEmpty; nivel--) {
    vs = _pickNivel(pat, c, nivel);
  }
  if (vs.isEmpty) return null;
  bool prefere(Variante v) {
    final k = v.exigir ?? v.preferir;
    return k != null && _temAlgum(k, c.lim);
  }

  final ordenadas = [
    ...vs.where(prefere),
    ...vs.where((v) => !prefere(v)),
  ];
  return ordenadas[occ % ordenadas.length];
}

class _Serie {
  const _Serie(this.series, this.texto);
  final int series;
  final String texto;
}

_Serie _sch(_Cand e, int n, String o, int w, int cut, double rf) {
  final u = e.v.unilateral;
  final iso = e.v.isometria == 'iso';
  if (e.papel == 'core') {
    final sets = (n == 1 || rf < 1) ? 2 : 3;
    if (iso) {
      return _Serie(sets, '${_isometriaSeg[n - 1][w]} s${u ? ' por lado' : ''}');
    }
    return _Serie(sets, '8–10${u ? ' por lado' : ''}');
  }
  if (e.papel == 'acc') {
    return _Serie(math.max(2, (n == 1 ? 2 : 3) - cut), '12–15');
  }
  final base = <List<int>>[
    [2, 2, 3, 3],
    [3, 3, 3, 3],
    o == 'recomp' ? [3, 3, 4, 4] : [3, 3, 3, 3],
  ][n - 1][w];
  final sets = math.max(2, base - cut);
  final txt = u
      ? '8–10 por lado'
      : (n == 1 ? '10–12' : (n == 3 && o == 'recomp' ? '6–10' : '8–12'));
  return _Serie(sets, txt);
}

double _tSet(_Cand e, int n, double rf) {
  if (e.v.isometria == 'iso') {
    const h = [0, 30, 40, 50];
    return (h[n] + 8) / 60 * (e.v.unilateral ? 2 : 1);
  }
  return e.v.unilateral ? (rf < 1 ? 1.0 : 1.4) : 0.75;
}

double _restMin(_Cand e, int n, double rf) {
  if (e.papel == 'main') {
    return rf * (n == 1 ? 1.25 : (n == 2 ? 1.5 : 1.75));
  }
  return rf * 0.8;
}

List<List<_Cand>> _pairUp(List<_Cand> list, bool pairMode) {
  final taken = List<bool>.filled(list.length, false);
  final groups = <List<_Cand>>[];
  for (var i = 0; i < list.length; i++) {
    if (taken[i]) continue;
    final a = list[i];
    taken[i] = true;
    var pareado = false;
    if (pairMode && !a.v.unilateral) {
      for (var j = i + 1; j < list.length; j++) {
        final b = list[j];
        if (taken[j] ||
            b.v.unilateral ||
            b.papel != 'main' ||
            a.papel != 'main' ||
            (a.tipo != 'push' && a.tipo != 'pull') ||
            (b.tipo != 'push' && b.tipo != 'pull') ||
            b.tipo == a.tipo) {
          continue;
        }
        taken[j] = true;
        groups.add([a, b]);
        pareado = true;
        break;
      }
    }
    if (!pareado) groups.add([a]);
  }
  return groups;
}

int _groupSets(List<_Cand> g, int n, String o, int cut, double rf) =>
    g.map((e) => _sch(e, n, o, 3, cut, rf).series).reduce(math.max);

double _totalMin(List<_Cand> list, int n, String o, int cut, bool pairMode, double rf) {
  var tot = 0.0;
  for (final g in _pairUp(list, pairMode)) {
    final s = _groupSets(g, n, o, cut, rf);
    if (g.length == 2) {
      tot += s * (_tSet(g[0], n, rf) + _tSet(g[1], n, rf) + 1.25) + 0.5;
    } else {
      tot += s * (_tSet(g[0], n, rf) + _restMin(g[0], n, rf)) + 0.5;
    }
  }
  return tot;
}

DiaTreino _strengthDay(String tipo, String letra, int indice, _Ctx c, Map<String, int> used) {
  final n = c.n, o = c.o, t = c.minutos;
  final tav = t - 5;
  final pairMode = t <= 30;
  final rf = t <= 30 ? 0.7 : 1.0;
  final pats = [
    for (final p in _modelos[tipo]![letra]!)
      if (_banco[p]!.papel != 'acc' || o == 'recomp' || n == 3) p,
  ];
  final cands = <_Cand>[];
  for (final p in pats) {
    var occ = used[p] ?? 0;
    var v = _pick(p, c, occ);
    var tries = 0;
    while (v != null &&
        tries < 4 &&
        cands.any((x) => x.v.nome == v!.nome)) {
      occ++;
      tries++;
      v = _pick(p, c, occ);
    }
    if (v != null && cands.any((x) => x.v.nome == v!.nome)) v = null;
    if (v != null) {
      used[p] = occ + 1;
      cands.add(_Cand(v, _banco[p]!.papel, _banco[p]!.tipo));
    }
  }
  var chosen = <_Cand>[];
  int cut;
  for (cut = 0; cut <= 2; cut++) {
    chosen = [];
    for (var k = 0; k < cands.length && chosen.length < 7; k++) {
      final trial = [...chosen, cands[k]];
      if (_totalMin(trial, n, o, cut, pairMode, rf) <= tav) chosen = trial;
    }
    if (chosen.length >= (tav >= 25 ? 4 : 3)) break;
  }
  cut = math.min(cut, 2);
  final itens = <ItemTreino>[];
  var gi = 0;
  for (final g in _pairUp(chosen, pairMode)) {
    final letraG = String.fromCharCode(65 + gi);
    gi++;
    for (var idx = 0; idx < g.length; idx++) {
      final e = g[idx];
      final semanas = [
        for (var w = 0; w < 4; w++)
          () {
            final r = _sch(e, n, o, w, cut, rf);
            return SemanaItem(r.series, r.texto);
          }(),
      ];
      final par = g.length == 2;
      final pausa = par
          ? (idx == 1 ? '60–90 s depois do par' : 'sem pausa, vá direto ao próximo')
          : (e.papel == 'main'
                ? (t <= 30
                      ? '60 s'
                      : (n == 1 ? '60–90 s' : (n == 2 ? '90 s' : '90 s a 2 min')))
                : '45–60 s');
      itens.add(
        ItemTreino(
          rotulo: par ? '$letraG${idx + 1}' : '$gi',
          nome: e.v.nome,
          dica: e.v.dica,
          unilateral: e.v.unilateral,
          papel: e.papel,
          semanas: semanas,
          pausa: pausa,
          emPar: par,
        ),
      );
    }
  }
  return DiaTreino(
    indice: indice,
    tipo: 'S',
    titulo: '${_titulosTipo[tipo]} $letra',
    itens: itens,
    estimativaMin: (5 + _totalMin(chosen, n, o, cut, pairMode, rf)).round(),
    emPares: pairMode,
  );
}

({int k, double w, double r, String eff})? _hiitCfg(_Ctx c, int w) {
  final n = c.n;
  if (c.pp || n == 1) return null;
  final imp = c.lim.contains('j');
  if (c.aero == 'casa' && imp) return null;
  double forte, leve;
  String eff;
  int cap;
  if (n == 2) {
    if (w < 2) return null;
    forte = 2;
    leve = 2;
    eff = '7 de 10';
    cap = const [0, 0, 4, 5][w];
  } else {
    if (w < 1) return null;
    forte = 1;
    leve = 1.5;
    eff = '8 a 9 de 10';
    cap = const [0, 4, 6, 7][w];
  }
  final k = math.min(cap, ((c.minutos - 10) / (forte + leve)).floor());
  if (k < 3) return null;
  return (k: k, w: forte, r: leve, eff: eff);
}

String _modTxt(_Ctx c) {
  final imp = c.lim.contains('j') || c.pp;
  if (c.aero == 'rua') {
    return (c.n == 1 || imp)
        ? 'Caminhada em ritmo firme.'
        : 'Caminhada rápida ou trote leve, se você já corre.';
  }
  if (c.aero == 'aparelho') return 'Esteira, bicicleta ergométrica ou elíptico.';
  return 'Marcha no lugar, subida e descida de degrau, dança ou caminhada pela casa.';
}

String _hiitMod(_Ctx c) {
  final imp = c.lim.contains('j') || c.pp;
  if (c.aero == 'rua') {
    return imp
        ? 'caminhada rápida em subida'
        : 'caminhada rápida em subida, ou corrida se você já corre';
  }
  if (c.aero == 'aparelho') return 'bicicleta, esteira com inclinação ou elíptico';
  return 'subida de degrau acelerada ou marcha acelerada';
}

/// Monta o programa de 4 semanas. Determinístico.
ProgramaTreino montarTreino(PrescricaoTreino p, EscolhasTreino e) {
  final n = p.nivel, o = p.objetivo;
  final lim = [...p.limitacoes];
  if (p.posParto && !lim.contains('p')) lim.add('p');
  final c = _Ctx(n, o, e.dias, e.minutos, e.local, e.aerobico, lim, p.posParto);
  const forcaPorObjetivo = {
    'perda': [2, 3, 3],
    'recomp': [3, 3, 4],
    'saude': [2, 3, 3],
    'manut': [2, 3, 3],
  };
  const aeroPorObjetivo = {
    'perda': [3, 3, 3],
    'recomp': [1, 2, 2],
    'saude': [3, 3, 3],
    'manut': [3, 3, 3],
  };
  final d = e.dias;
  final s = math.min(d, forcaPorObjetivo[o]![n - 1]);
  final nCardio = math.min(d - s, aeroPorObjetivo[o]![n - 1]);
  final slots = <List<Object>>[
    for (final x in _agendas['$d-$s']!) <Object>[x[0] as int, x[1] as String],
  ];
  if (n == 3 && s == 3) {
    const seq = ['L', 'U', 'F'];
    var q = 0;
    for (final x in slots) {
      if (x[1] == 'F') x[1] = seq[q++];
    }
  }
  var ultimoCardio = -1;
  var cont = 0;
  for (var idx = 0; idx < slots.length; idx++) {
    if (slots[idx][1] == 'X' && cont < nCardio) {
      ultimoCardio = idx;
      cont++;
    }
  }
  final ramp = (n == 1 || p.posParto) ? [15, 20, 25, 30] : [e.minutos, e.minutos, e.minutos, e.minutos];
  final dur = [for (final m in ramp) math.min(e.minutos, m)];
  final cnt = {'F': 0, 'U': 0, 'L': 0};
  final used = <String, int>{};
  final dias = <DiaTreino>[];
  cont = 0;
  for (var idx = 0; idx < slots.length; idx++) {
    final di = slots[idx][0] as int;
    final t = slots[idx][1] as String;
    if (t == 'X') {
      if (cont < nCardio) {
        cont++;
        final hiitSlot = idx == ultimoCardio && nCardio >= 2;
        dias.add(
          DiaTreino(
            indice: di,
            tipo: 'C',
            titulo: 'Aeróbico',
            minutos: dur,
            modalidade: _modTxt(c),
            intervalado: [
              for (var w = 0; w < 4; w++)
                () {
                  final h = hiitSlot ? _hiitCfg(c, w) : null;
                  if (h == null) return null;
                  return AeroIntervalado(
                    series: h.k,
                    forteMin: h.w,
                    leveMin: h.r,
                    esforco: h.eff,
                    modalidade: _hiitMod(c),
                  );
                }(),
            ],
          ),
        );
      } else {
        dias.add(DiaTreino(indice: di, tipo: 'R', titulo: 'Descanso ativo'));
      }
    } else {
      final letra = const ['A', 'B', 'C'][cnt[t]!];
      cnt[t] = cnt[t]! + 1;
      dias.add(_strengthDay(t, letra, di, c, used));
    }
  }
  dias.sort((a, b) => a.indice.compareTo(b.indice));
  final aero = [
    for (var w = 0; w < 4; w++)
      dias.where((x) => x.tipo == 'C').fold<int>(0, (a, x) => a + x.minutos[w]),
  ];
  final rampT = (n == 1 || p.posParto) ? [0.6, 0.75, 0.9, 1.0] : [1.0, 1.0, 1.0, 1.0];
  return ProgramaTreino(
    dias: dias,
    aeroPorSemana: aero,
    metaPorSemana: [for (final r in rampT) (150 * r).round()],
    esforco: _esforcoPorNivel[n - 1],
  );
}

// ---------------------------------------------------------------------------
// Registro do paciente

class SerieRegistro {
  SerieRegistro({this.feita = false, this.reps, this.kg});
  bool feita;
  int? reps;
  double? kg;

  Map<String, dynamic> toMap() => {'f': feita, 'r': reps, 'k': kg};

  static SerieRegistro fromMap(Map<dynamic, dynamic> m) => SerieRegistro(
    feita: m['f'] == true,
    reps: m['r'] is num ? (m['r'] as num).toInt() : null,
    kg: m['k'] is num ? (m['k'] as num).toDouble() : null,
  );
}

class RegistroExercicio {
  RegistroExercicio({required this.nome, List<SerieRegistro>? series, this.sobraram})
    : series = series ?? [];
  final String nome;
  final List<SerieRegistro> series;
  int? sobraram;

  Map<String, dynamic> toMap() => {
    'nome': nome,
    'series': [for (final s in series) s.toMap()],
    if (sobraram != null) 'sobraram': sobraram,
  };

  static RegistroExercicio fromMap(Object? raw) {
    if (!registroExercicioValido(raw)) {
      return RegistroExercicio(nome: '');
    }
    final m = raw as Map;
    return RegistroExercicio(
      nome: m['nome'] as String,
      series: [
        for (final s in m['series'] as List) SerieRegistro.fromMap(s as Map),
      ],
      sobraram: m['sobraram'] is num ? (m['sobraram'] as num).toInt() : null,
    );
  }

  int get feitas => series.where((s) => s.feita).length;
}

/// Forma esperada de um registro de exercício (também usada na devolução).
bool registroExercicioValido(Object? v) {
  if (v is! Map ||
      v['nome'] is! String ||
      (v['nome'] as String).isEmpty ||
      (v['nome'] as String).length > 120 ||
      v['series'] is! List ||
      (v['series'] as List).length > 12) {
    return false;
  }
  final so = v['sobraram'];
  if (so != null && (so is! int || so < 0 || so > 10)) return false;
  for (final s in v['series'] as List) {
    if (s is! Map || s['f'] is! bool) return false;
    final r = s['r'], k = s['k'];
    if (r != null && (r is! num || !r.isFinite || r < 0 || r > 1000)) {
      return false;
    }
    if (k != null && (k is! num || !k.isFinite || k < 0 || k > 1000)) {
      return false;
    }
  }
  return true;
}

bool registroAerobicoValido(Object? v) =>
    v is Map &&
    v['feito'] is bool &&
    (v['min'] == null ||
        (v['min'] is num && (v['min'] as num).isFinite && v['min'] >= 0 && v['min'] <= 1000));

bool campoDeTreino(String id) => id.startsWith('trn_');
const campoAerobicoTreino = 'trn_aerobico';

bool registroTreinoValido(String id, Object? v) =>
    v == null ||
    (id == campoAerobicoTreino
        ? registroAerobicoValido(v)
        : campoDeTreino(id) && id.length <= 140 && registroExercicioValido(v));

/// Faixa de repetições do texto do plano ("8–12", "10–12 por lado", "40 s").
({int baixo, int alto, bool tempo}) faixaDeTexto(String txt) {
  final m = RegExp(r'(\d+)–(\d+)').firstMatch(txt);
  if (m != null) {
    return (baixo: int.parse(m.group(1)!), alto: int.parse(m.group(2)!), tempo: false);
  }
  final t = RegExp(r'(\d+) s').firstMatch(txt);
  if (t != null) {
    final v = int.parse(t.group(1)!);
    return (baixo: (v * 0.8).round(), alto: v, tempo: true);
  }
  return (baixo: 8, alto: 12, tempo: false);
}

class SugestaoCarga {
  const SugestaoCarga(this.direcao, this.kg, this.mensagem);

  /// 'sobe', 'desce', 'mantem' ou 'nenhuma'.
  final String direcao;
  final double? kg;
  final String mensagem;
}

String kgTexto(double kg) {
  final s = kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);
  return s.replaceAll('.', ',');
}

double _meio(double x) => (x * 2).round() / 2;

/// Sugere a carga da próxima vez, pelas repetições e pelo esforço registrados.
/// Regras fixas: sobe se todas as séries chegaram ao topo da faixa; desce se
/// alguma ficou abaixo da faixa ou se foi até a falha.
SugestaoCarga? sugerirCarga(RegistroExercicio rec, int seriesPlanejadas, String faixa) {
  final r = faixaDeTexto(faixa);
  final feitas = rec.series.where((s) => s.feita).toList();
  if (feitas.isEmpty) return null;
  final reps = [for (final s in feitas) s.reps ?? r.alto];
  final abaixo = reps.any((x) => x < r.baixo);
  final topo = feitas.length >= seriesPlanejadas && reps.every((x) => x >= r.alto);
  final comCarga = feitas.where((s) => s.kg != null && s.kg! > 0).toList();
  final base = comCarga.isEmpty ? null : comCarga.last.kg;
  final falha = rec.sobraram == 0;
  if (falha || abaixo) {
    double? kg;
    if (base != null) {
      kg = math.min(base - 0.5, _meio(base * 0.925));
      if (kg < 0) kg = 0;
    }
    final por = falha ? 'Você foi até a falha.' : 'Repetições abaixo da faixa.';
    return SugestaoCarga(
      'desce',
      kg,
      kg != null
          ? '$por Na próxima vez, diminua para ${kgTexto(kg)} kg.'
          : '$por Na próxima vez, use uma variação mais fácil ou reduza o esforço.',
    );
  }
  if (topo) {
    double? kg;
    if (base != null) kg = math.max(base + 0.5, _meio(base * 1.035));
    return SugestaoCarga(
      'sobe',
      kg,
      kg != null
          ? 'Todas as séries no topo da faixa. Na próxima vez, suba para ${kgTexto(kg)} kg.'
          : 'Todas as séries no topo da faixa. Na próxima vez, aumente as repetições, desça em 3 s ou use a variação mais difícil.',
    );
  }
  if (feitas.length >= seriesPlanejadas) {
    return SugestaoCarga(
      'mantem',
      base,
      'Mantenha a carga e tente chegar a ${r.alto}${r.tempo ? ' s' : ' repetições'} em todas as séries.',
    );
  }
  return const SugestaoCarga('nenhuma', null, '');
}

/// Semana do programa (0 a 3) para uma data, contada do início do plano.
int semanaDoPrograma(DateTime inicio, DateTime dia) {
  final a = DateTime(inicio.year, inicio.month, inicio.day);
  final b = DateTime(dia.year, dia.month, dia.day);
  final dias = b.difference(a).inDays;
  if (dias <= 0) return 0;
  return math.min(3, dias ~/ 7);
}
