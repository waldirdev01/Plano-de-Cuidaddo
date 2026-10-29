import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'alimentacao.dart';
import 'plano.dart';

/// Swap groups: a trade keeps the group's main macro (or the grams, for
/// low-calorie foods), like a printed equivalence list.
const gruposAlimentos = <String, ({String nome, String chave})>{
  'carboidrato': (nome: 'Carboidratos', chave: 'carboidrato'),
  'leguminosa': (nome: 'Leguminosas', chave: 'carboidrato'),
  'fruta': (nome: 'Frutas', chave: 'carboidrato'),
  'proteina': (nome: 'Proteínas', chave: 'proteina'),
  'laticinio': (nome: 'Leite e derivados', chave: 'proteina'),
  'gordura': (nome: 'Gorduras', chave: 'gordura'),
  'doce': (nome: 'Doces', chave: 'kcal'),
  'bebida': (nome: 'Bebidas', chave: 'kcal'),
  'preparado': (nome: 'Pratos prontos', chave: 'kcal'),
  'livre': (nome: 'Verduras e baixa caloria', chave: 'gramas'),
};

const fonteAlimentos =
    'TACO - Tabela Brasileira de Composição de Alimentos, 4ª edição (NEPA/UNICAMP, 2011); leite líquido e pasta de amendoim: USDA FoodData Central.';

String _chaveNome(String nome) =>
    PerfilPaciente.normalizarNome(nome).replaceAll(RegExp(r'\s*,\s*'), ', ');

/// Composition per 100 g.
class Alimento {
  const Alimento({
    required this.id,
    required this.nome,
    required this.grupo,
    required this.por100,
  });
  final int id;
  final String nome;
  final String grupo;
  final Nutrientes por100;

  double valor(String chave) => switch (chave) {
    'kcal' => por100.kcal,
    'proteina' => por100.proteina,
    'carboidrato' => por100.carboidrato,
    'gordura' => por100.gordura,
    _ => por100.fibra,
  };
}

/// A food and its grams in a meal. Carries its own composition so a plan keeps
/// working even if the bundled table changes.
class ItemAlimento {
  const ItemAlimento(this.alimento, this.gramas);
  final Alimento alimento;
  final double gramas;

  Nutrientes get nutrientes {
    final f = gramas / 100;
    final p = alimento.por100;
    return Nutrientes(
      kcal: p.kcal * f,
      proteina: p.proteina * f,
      carboidrato: p.carboidrato * f,
      gordura: p.gordura * f,
      fibra: p.fibra * f,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': alimento.id,
    'nome': alimento.nome,
    'grupo': alimento.grupo,
    'gramas': gramas,
    'por100': alimento.por100.toJson(),
  };

  static ItemAlimento fromMap(Object? raw) {
    if (raw is! Map ||
        raw.keys.toSet().difference({
          'id',
          'nome',
          'grupo',
          'gramas',
          'por100',
        }).isNotEmpty) {
      throw const FormatException('Um alimento da refeição está inválido.');
    }
    final id = raw['id'];
    final nome = raw['nome'];
    final grupo = raw['grupo'];
    final gramas = raw['gramas'];
    final por100 = raw['por100'];
    if (id is! int ||
        nome is! String ||
        nome.trim().isEmpty ||
        !gruposAlimentos.containsKey(grupo) ||
        gramas is! num ||
        !gramas.isFinite ||
        gramas < 1 ||
        gramas > 2000 ||
        por100 is! Map) {
      throw const FormatException('Um alimento da refeição está inválido.');
    }
    return ItemAlimento(
      Alimento(
        id: id,
        nome: nome,
        grupo: grupo as String,
        por100: Nutrientes.fromMap(por100, prefix: 'Alimento: '),
      ),
      gramas.toDouble(),
    );
  }
}

const maxAlimentosRefeicao = 15;

/// Validates the `alimentos` list of a prescribed meal.
List<ItemAlimento> validarAlimentos(Object? raw) {
  if (raw is! List || raw.isEmpty || raw.length > maxAlimentosRefeicao) {
    throw const FormatException('Cada refeição aceita de 1 a 15 alimentos.');
  }
  final itens = raw.map(ItemAlimento.fromMap).toList();
  if (itens.map((i) => i.alimento.id).toSet().length != itens.length) {
    throw const FormatException('Não repita o mesmo alimento na refeição.');
  }
  return itens;
}

Nutrientes somarAlimentos(Iterable<ItemAlimento> itens) => itens.fold(
  const Nutrientes(kcal: 0, proteina: 0, carboidrato: 0, gordura: 0, fibra: 0),
  (t, i) => t + i.nutrientes,
);

class TabelaAlimentos {
  TabelaAlimentos._(this.alimentos)
    : _porNome = {for (final a in alimentos) _chaveNome(a.nome): a};
  final List<Alimento> alimentos;
  final Map<String, Alimento> _porNome;

  /// Loaded once from the app bundle; tests set it from the asset file.
  static TabelaAlimentos? padrao;

  static Future<TabelaAlimentos> carregar() async =>
      padrao ??= TabelaAlimentos.deJson(
        await rootBundle.loadString('assets/alimentos/taco.json'),
      );

  factory TabelaAlimentos.deJson(String texto) {
    final raw = jsonDecode(texto) as Map<String, dynamic>;
    return TabelaAlimentos._([
      for (final r in raw['alimentos'] as List)
        Alimento(
          id: r[0] as int,
          nome: r[1] as String,
          grupo: r[2] as String,
          por100: Nutrientes(
            kcal: (r[3] as num).toDouble(),
            proteina: (r[4] as num).toDouble(),
            carboidrato: (r[5] as num).toDouble(),
            gordura: (r[6] as num).toDouble(),
            fibra: (r[7] as num).toDouble(),
          ),
        ),
    ]);
  }

  Alimento? porNome(String nome) => _porNome[_chaveNome(nome)];

  /// Closest names by shared words, to help fix a name typed in the PDF.
  List<String> parecidos(String nome, {int limite = 3}) {
    final palavras = _chaveNome(
      nome,
    ).split(RegExp(r'[\s,/]+')).where((p) => p.length > 2).toSet();
    final notas = <(int, Alimento)>[
      for (final a in alimentos)
        (
          _chaveNome(
            a.nome,
          ).split(RegExp(r'[\s,/]+')).where(palavras.contains).length,
          a,
        ),
    ]..sort((x, y) => y.$1.compareTo(x.$1));
    return [
      for (final (n, a) in notas.take(limite))
        if (n > 0) a.nome,
    ];
  }

  /// Foods of the same group with the grams that keep the group's main macro.
  /// A cooked food is not traded for a raw one (arroz cozido for arroz cru).
  List<ItemAlimento> trocasPara(ItemAlimento item) {
    final semCru =
        const {'carboidrato', 'leguminosa', 'proteina'}.contains(
          item.alimento.grupo,
        ) &&
        !_cru(item.alimento.nome);
    return [
      for (final a in alimentos)
        if (a.grupo == item.alimento.grupo &&
            a.id != item.alimento.id &&
            !(semCru && _cru(a.nome)))
          if (gramasEquivalentes(item, a) case final g?) ItemAlimento(a, g),
    ]..sort((x, y) => x.alimento.nome.compareTo(y.alimento.nome));
  }

  static bool _cru(String nome) =>
      RegExp(r',\s*crua?s?\b', caseSensitive: false).hasMatch(nome);

  /// Parses the PDF line "Arroz, tipo 1, cozido 100 g; Feijão, carioca, cozido 80 g".
  List<ItemAlimento> lerLinhaPdf(String texto) {
    final itens = <ItemAlimento>[];
    for (final parte in texto.split(';')) {
      final p = parte.trim();
      if (p.isEmpty) continue;
      final m = RegExp(
        r'^(.+?)\s+(\d+(?:[.,]\d+)?)\s*g$',
        caseSensitive: false,
      ).firstMatch(p);
      if (m == null) {
        throw FormatException(
          'Alimentos: "$p" precisa terminar com a quantidade em gramas, por exemplo "Arroz, tipo 1, cozido 100 g".',
        );
      }
      final alimento = porNome(m.group(1)!);
      if (alimento == null) {
        final sugestoes = parecidos(m.group(1)!);
        throw FormatException(
          'Alimento fora da tabela do app: "${m.group(1)}". '
          '${sugestoes.isEmpty ? 'Use um nome da lista de alimentos.' : 'Parecidos: ${sugestoes.join('; ')}.'}',
        );
      }
      final gramas = double.parse(m.group(2)!.replaceAll(',', '.'));
      if (gramas < 1 || gramas > 2000) {
        throw FormatException(
          'Alimentos: use de 1 a 2000 g em ${alimento.nome}.',
        );
      }
      itens.add(ItemAlimento(alimento, gramas));
    }
    validarAlimentos([for (final i in itens) i.toMap()]);
    return itens;
  }
}

/// Grams of [para] that match [de] in the group's main macro, rounded to 5 g.
/// Null when [para] has too little of it to be a sensible trade.
double? gramasEquivalentes(ItemAlimento de, Alimento para) {
  final chave = gruposAlimentos[de.alimento.grupo]!.chave;
  if (chave == 'gramas') return de.gramas;
  final porGrama = para.valor(chave) / 100;
  if (porGrama < (chave == 'kcal' ? 0.1 : 0.01)) return null;
  final alvo = de.alimento.valor(chave) * de.gramas / 100;
  final g = ((alvo / porGrama) / 5).round() * 5.0;
  return g < 5 || g > 1000 ? null : g;
}

final _ultraprocessado = RegExp(
  r'biscoito|bolo|chips|frit[oa]|recheado|wafer|industrializad|salgadinho|'
  r'sorvete|chocolate|calda|empanad|nuggets|salsicha|lingui[cç]a|mortadela|'
  r'presunto|bacon|salame|hamb[uú]rguer|refrigerante|achocolatado|'
  r'margarina|maionese|chantilly',
  caseSensitive: false,
);

/// Why [opcao] is a worse trade for [doPlano], or null when it is fine:
/// ultra-processed, or a quarter more calories for the same main macro.
String? motivoMenosIndicada(ItemAlimento opcao, ItemAlimento doPlano) {
  if (_ultraprocessado.hasMatch(opcao.alimento.nome) &&
      !_ultraprocessado.hasMatch(doPlano.alimento.nome)) {
    return 'ultraprocessado ou frito';
  }
  final kcal = doPlano.nutrientes.kcal;
  if (opcao.nutrientes.kcal > kcal * 1.25 + 10) {
    return '${(opcao.nutrientes.kcal - kcal).round()} kcal a mais';
  }
  return null;
}

/// Up to [limite] good trades, more fibre and fewer calories first.
List<ItemAlimento> melhoresTrocas(
  List<ItemAlimento> opcoes,
  ItemAlimento doPlano, {
  int limite = 3,
}) =>
    (opcoes.where((o) => motivoMenosIndicada(o, doPlano) == null).toList()
          ..sort((a, b) {
            final f = b.nutrientes.fibra.compareTo(a.nutrientes.fibra);
            return f != 0 ? f : a.nutrientes.kcal.compareTo(b.nutrientes.kcal);
          }))
        .take(limite)
        .toList();

/// The day's foods of a prescribed [meal]: the plan's, with the patient's
/// [trocas] (keyed `refeicao|posicao`) applied. The flag marks a trade.
List<(ItemAlimento item, ItemAlimento? doPlano)> alimentosDoDia(
  Map<String, dynamic> meal,
  Map<String, Map<String, dynamic>> trocas,
) {
  if (meal['alimentos'] == null) return const [];
  final base = validarAlimentos(meal['alimentos']);
  return [
    for (var i = 0; i < base.length; i++)
      if (trocas['${meal['id']}|$i'] case final t?)
        (ItemAlimento.fromMap(t), base[i])
      else
        (base[i], null),
  ];
}
