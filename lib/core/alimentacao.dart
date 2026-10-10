import 'dart:math' as math;

class Nutrientes {
  const Nutrientes({
    required this.kcal,
    required this.proteina,
    required this.carboidrato,
    required this.gordura,
    required this.fibra,
  });

  final double kcal;
  final double proteina;
  final double carboidrato;
  final double gordura;
  final double fibra;

  factory Nutrientes.fromMap(Map<dynamic, dynamic> map, {String prefix = ''}) {
    double number(String key) {
      final value = map[key];
      if (value is! num || value < 0 || !value.isFinite) {
        throw FormatException('${prefix}nutriente "$key" inválido.');
      }
      return value.toDouble();
    }

    return Nutrientes(
      kcal: number('kcal'),
      proteina: number('proteina'),
      carboidrato: number('carboidrato'),
      gordura: number('gordura'),
      fibra: number('fibra'),
    );
  }

  Map<String, double> toJson() => {
    'kcal': kcal,
    'proteina': proteina,
    'carboidrato': carboidrato,
    'gordura': gordura,
    'fibra': fibra,
  };

  Nutrientes operator +(Nutrientes other) => Nutrientes(
    kcal: kcal + other.kcal,
    proteina: proteina + other.proteina,
    carboidrato: carboidrato + other.carboidrato,
    gordura: gordura + other.gordura,
    fibra: fibra + other.fibra,
  );

  double difference(double Function(Nutrientes) pick, Nutrientes target) =>
      pick(target) - pick(this);
}

class OpcaoAlimentar {
  const OpcaoAlimentar({
    required this.id,
    required this.nome,
    required this.grupo,
    required this.qualidade,
    required this.quantidade,
    required this.unidade,
    required this.nutrientes,
    this.imagem,
    this.observacao,
  });

  final String id;
  final String nome;
  final String grupo;
  final String qualidade;
  final double quantidade;
  final String unidade;
  final Nutrientes nutrientes;
  final String? imagem;
  final String? observacao;

  factory OpcaoAlimentar.fromMap(Map<dynamic, dynamic> raw) {
    String text(String key, {bool required = true}) {
      final value = raw[key];
      if (value is! String || (required && value.trim().isEmpty)) {
        throw FormatException('A opção alimentar está sem "$key".');
      }
      return value.trim();
    }

    final quantidade =
        raw['quantidade'] ?? (raw['porcao'] as Map?)?['quantidade'];
    final unidade = raw['unidade'] ?? (raw['porcao'] as Map?)?['unidade'];
    if (quantidade is! num ||
        quantidade <= 0 ||
        !quantidade.isFinite ||
        unidade is! String ||
        unidade.trim().isEmpty) {
      throw const FormatException('A porção da opção alimentar está inválida.');
    }
    final nutrientes = raw['nutrientes'];
    if (nutrientes is! Map) {
      throw const FormatException('A opção alimentar está sem nutrientes.');
    }
    return OpcaoAlimentar(
      id: text('id'),
      nome: text('nome'),
      grupo: text('grupo'),
      qualidade: (raw['qualidade'] as String?)?.trim().isNotEmpty == true
          ? (raw['qualidade'] as String).trim()
          : 'opção',
      quantidade: quantidade.toDouble(),
      unidade: unidade.trim(),
      nutrientes: Nutrientes.fromMap(nutrientes),
      imagem: raw['imagem'] as String?,
      observacao: raw['observacao'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'grupo': grupo,
    'qualidade': qualidade,
    'quantidade': quantidade,
    'unidade': unidade,
    'nutrientes': nutrientes.toJson(),
    if (imagem != null) 'imagem': imagem,
    if (observacao != null) 'observacao': observacao,
  };
}

class RefeicaoAlimentar {
  const RefeicaoAlimentar({
    required this.id,
    required this.titulo,
    required this.opcoes,
    this.instrucao,
    this.horario,
  });

  final String id;
  final String titulo;
  final List<OpcaoAlimentar> opcoes;
  final String? instrucao;
  final String? horario;

  factory RefeicaoAlimentar.fromMap(Map<dynamic, dynamic> raw) {
    final id = raw['id'];
    final titulo = raw['titulo'];
    final list = raw['opcoes'];
    if (id is! String ||
        id.trim().isEmpty ||
        titulo is! String ||
        titulo.trim().isEmpty ||
        list is! List ||
        list.isEmpty) {
      throw const FormatException('Uma refeição alimentar está incompleta.');
    }
    final opcoes = list.map((item) {
      if (item is! Map) {
        throw const FormatException('Uma opção alimentar está inválida.');
      }
      return OpcaoAlimentar.fromMap(item);
    }).toList();
    final ids = opcoes.map((item) => item.id).toSet();
    if (ids.length != opcoes.length) {
      throw const FormatException('Uma refeição contém opções repetidas.');
    }
    final horario = raw['horario'];
    if (horario != null &&
        (horario is! String ||
            !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(horario))) {
      throw const FormatException('O horário da refeição é inválido.');
    }
    return RefeicaoAlimentar(
      id: id.trim(),
      titulo: titulo.trim(),
      opcoes: opcoes,
      instrucao: raw['instrucao'] as String?,
      horario: (horario as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    if (instrucao != null) 'instrucao': instrucao,
    if (horario != null) 'horario': horario,
    'opcoes': opcoes.map((item) => item.toJson()).toList(),
  };
}

/// Rotina recebida da profissional; nutrientes pertencem à porção da opção.
/// Substituições locais por plano/data ficam no Armazenamento, fora deste JSON.
class AlimentacaoPlano {
  AlimentacaoPlano._({
    required this.data,
    required this.meta,
    required this.refeicoes,
  });

  final Map<String, dynamic> data;
  final Nutrientes meta;
  final List<RefeicaoAlimentar> refeicoes;

  String get titulo => (data['titulo'] as String?)?.trim().isNotEmpty == true
      ? data['titulo'] as String
      : 'Plano alimentar';

  String get modo => data['modo'] as String? ?? 'rotina_mensal';

  static AlimentacaoPlano fromMap(Map<dynamic, dynamic> raw) {
    final title = raw['titulo'];
    if (title != null && title is! String) {
      throw const FormatException('O título da alimentação é inválido.');
    }
    final metaRaw = raw['meta'];
    if (metaRaw is! Map) {
      throw const FormatException('O plano alimentar está sem metas.');
    }
    final mealRaw = raw['refeicoes'];
    if (mealRaw is! List || mealRaw.isEmpty) {
      throw const FormatException('O plano alimentar está sem refeições.');
    }
    final meals = mealRaw.map((item) {
      if (item is! Map) throw const FormatException('Uma refeição é inválida.');
      return RefeicaoAlimentar.fromMap(item);
    }).toList();
    final mealIds = meals.map((meal) => meal.id).toSet();
    if (mealIds.length != meals.length) {
      throw const FormatException(
        'O plano alimentar contém refeições repetidas.',
      );
    }
    final defaults = <String, String>{};
    final rotina = raw['rotina'];
    if (rotina is Map && rotina['padrao'] is Map) {
      (rotina['padrao'] as Map).forEach((key, value) {
        if (key is String && value is String) defaults[key] = value;
      });
    }
    for (final meal in meals) {
      final choice = defaults[meal.id];
      if (choice != null && !meal.opcoes.any((option) => option.id == choice)) {
        throw const FormatException(
          'A rotina aponta para uma opção inexistente.',
        );
      }
    }
    return AlimentacaoPlano._(
      data: Map<String, dynamic>.from(raw),
      meta: Nutrientes.fromMap(metaRaw),
      refeicoes: meals,
    );
  }

  Map<String, String> selecoesParaDia(String date) {
    final result = <String, String>{};
    final rotina = data['rotina'];
    if (rotina is Map && rotina['padrao'] is Map) {
      (rotina['padrao'] as Map).forEach((key, value) {
        if (key is String && value is String) result[key] = value;
      });
    }
    if (rotina is Map && rotina['dias'] is Map) {
      final override = (rotina['dias'] as Map)[date];
      if (override is Map) {
        override.forEach((key, value) {
          if (key is String && value is String) result[key] = value;
        });
      }
    }
    return result;
  }

  RefeicaoAlimentar? refeicao(String id) =>
      refeicoes.where((item) => item.id == id).firstOrNull;

  OpcaoAlimentar? opcao(String mealId, String optionId) {
    final meal = refeicao(mealId);
    if (meal == null) return null;
    return meal.opcoes.where((item) => item.id == optionId).firstOrNull;
  }

  Nutrientes total(Map<String, String> selections) {
    var total = const Nutrientes(
      kcal: 0,
      proteina: 0,
      carboidrato: 0,
      gordura: 0,
      fibra: 0,
    );
    for (final meal in refeicoes) {
      final option = opcao(meal.id, selections[meal.id] ?? '');
      if (option != null) total += option.nutrientes;
    }
    return total;
  }

  static Map<String, dynamic> modeloTeste() => {
    'titulo': 'Rotina alimentar de teste',
    'modo': 'rotina_mensal',
    'meta': {
      'kcal': 1800,
      'proteina': 120,
      'carboidrato': 210,
      'gordura': 60,
      'fibra': 25,
    },
    'rotina': {
      'padrao': {
        'cafe': 'cafe_ovo',
        'almoco': 'almoco_frango',
        'jantar': 'jantar_peixe',
      },
      'dias': <String, dynamic>{},
    },
    'refeicoes': [
      {
        'id': 'cafe',
        'titulo': 'Café da manhã',
        'horario': '07:30',
        'opcoes': [
          {
            'id': 'cafe_ovo',
            'nome': 'Ovo, fruta e aveia',
            'grupo': 'proteína',
            'qualidade': 'preferencial',
            'quantidade': 1,
            'unidade': 'porção',
            'nutrientes': {
              'kcal': 420,
              'proteina': 24,
              'carboidrato': 48,
              'gordura': 15,
              'fibra': 8,
            },
          },
          {
            'id': 'cafe_iogurte',
            'nome': 'Iogurte natural, fruta e aveia',
            'grupo': 'proteína',
            'qualidade': 'boa alternativa',
            'quantidade': 1,
            'unidade': 'porção',
            'nutrientes': {
              'kcal': 390,
              'proteina': 22,
              'carboidrato': 52,
              'gordura': 11,
              'fibra': 7,
            },
          },
        ],
      },
      {
        'id': 'almoco',
        'titulo': 'Almoço',
        'horario': '12:30',
        'opcoes': [
          {
            'id': 'almoco_frango',
            'nome': 'Frango, arroz, feijão e legumes',
            'grupo': 'prato principal',
            'qualidade': 'preferencial',
            'quantidade': 1,
            'unidade': 'porção',
            'nutrientes': {
              'kcal': 620,
              'proteina': 44,
              'carboidrato': 74,
              'gordura': 16,
              'fibra': 12,
            },
          },
          {
            'id': 'almoco_carne',
            'nome': 'Carne, batata, feijão e salada',
            'grupo': 'prato principal',
            'qualidade': 'alternativa',
            'quantidade': 1,
            'unidade': 'porção',
            'nutrientes': {
              'kcal': 650,
              'proteina': 40,
              'carboidrato': 70,
              'gordura': 21,
              'fibra': 10,
            },
          },
        ],
      },
      {
        'id': 'jantar',
        'titulo': 'Jantar',
        'horario': '19:30',
        'opcoes': [
          {
            'id': 'jantar_peixe',
            'nome': 'Peixe, mandioca e legumes',
            'grupo': 'prato principal',
            'qualidade': 'preferencial',
            'quantidade': 1,
            'unidade': 'porção',
            'nutrientes': {
              'kcal': 560,
              'proteina': 38,
              'carboidrato': 62,
              'gordura': 17,
              'fibra': 9,
            },
          },
          {
            'id': 'jantar_omelete',
            'nome': 'Omelete, arroz e salada',
            'grupo': 'prato principal',
            'qualidade': 'alternativa',
            'quantidade': 1,
            'unidade': 'porção',
            'nutrientes': {
              'kcal': 510,
              'proteina': 34,
              'carboidrato': 55,
              'gordura': 17,
              'fibra': 8,
            },
          },
        ],
      },
    ],
  };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String formatNutriente(double value) => value.round().toString();
double percentual(double value, double target) =>
    target <= 0 ? 0 : (value / target).clamp(0, 1).toDouble();
double diferencaAbsoluta(double value, double target) =>
    math.max(0, target - value);
