part of 'app.dart';

/// Prescription text only: no nutrient totals or substitutions are invented.
class RotinaPrescritaPage extends StatelessWidget {
  const RotinaPrescritaPage({super.key, required this.plano});
  final Plano plano;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Minha rotina alimentar',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'Prescrição conferida pela profissional. Registre cada refeição na aba Hoje. Não há cálculo de nutrientes ou troca automática de alimentos.',
      ),
      for (final meal in plano.refeicoesPrescritas)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${meal['horario']} · ${meal['titulo']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  meal['regra'] == 'condicional'
                      ? 'Condicional: ${meal['condicao']}'
                      : 'Refeição obrigatória',
                ),
                const SizedBox(height: 8),
                SelectableText(meal['descricao'] as String),
              ],
            ),
          ),
        ),
      if ((plano.data['linkMonteSeuPrato'] as String? ?? '').isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('Link pessoal do Monte seu prato'),
        SelectableText(plano.data['linkMonteSeuPrato'] as String),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: plano.data['linkMonteSeuPrato'] as String),
            );
            if (context.mounted) {
              _message(context, 'Link copiado. Cole no navegador para abrir.');
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copiar link pessoal'),
        ),
      ],
    ],
  );
}

class AlimentacaoPage extends StatefulWidget {
  const AlimentacaoPage({super.key, required this.plano, this.preview = false});
  final Plano? plano;
  final bool preview;

  @override
  State<AlimentacaoPage> createState() => _AlimentacaoPageState();
}

class _AlimentacaoPageState extends State<AlimentacaoPage> {
  DateTime? day;
  Map<String, String> selections = {};
  Map<String, bool> done = {};
  Nutrientes? total;
  bool loading = true;

  AlimentacaoPlano? get food => widget.plano?.alimentacao;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AlimentacaoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plano?.id != widget.plano?.id) _load();
  }

  Future<void> _load({DateTime? selected}) async {
    final p = widget.plano;
    final model = food;
    if (p == null || model == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = selected ?? day ?? today;
    final bounded = initial.isBefore(p.inicio)
        ? p.inicio
        : initial.isAfter(p.fim)
        ? p.fim
        : initial;
    if (mounted) setState(() => loading = true);
    final key = Plano.formatDia(bounded);
    final stored = await Armazenamento.instance.selecoesAlimentacao(p.id, key);
    final defaults = model.selecoesParaDia(key);
    final records = await Armazenamento.instance.registros(p.id, key);
    final merged = {...defaults, ...stored};
    final chosen = <String, String>{};
    for (final meal in model.refeicoes) {
      final id = merged[meal.id];
      if (id != null && meal.opcoes.any((option) => option.id == id)) {
        chosen[meal.id] = id;
      }
    }
    final marked = <String, bool>{
      for (final meal in model.refeicoes)
        meal.id: records['alimentacao_feita_${meal.id}'] == true,
    };
    if (mounted) {
      setState(() {
        day = bounded;
        selections = chosen;
        done = marked;
        total = model.total(chosen);
        loading = false;
      });
    }
  }

  Future<void> _chooseDay() async {
    final p = widget.plano;
    if (p == null || day == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: day!,
      firstDate: p.inicio,
      lastDate: p.fim,
      helpText: 'Escolha o dia da rotina alimentar',
    );
    if (picked != null) await _load(selected: picked);
  }

  Future<void> _change(RefeicaoAlimentar meal) async {
    final current = selections[meal.id];
    final picked = await showModalBottomSheet<OpcaoAlimentar>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  'Trocar ${meal.titulo.toLowerCase()}',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              RadioGroup<OpcaoAlimentar>(
                groupValue: meal.opcoes
                    .where((option) => option.id == current)
                    .firstOrNull,
                onChanged: (value) {
                  if (value != null) Navigator.pop(ctx, value);
                },
                child: Column(
                  children: meal.opcoes
                      .map(
                        (option) => ListTile(
                          leading: Radio<OpcaoAlimentar>(value: option),
                          title: Text(option.nome),
                          subtitle: Text(
                            '${option.qualidade} · ${formatNutriente(option.nutrientes.kcal)} kcal · ${formatNutriente(option.nutrientes.proteina)} g proteína',
                          ),
                          onTap: () => Navigator.pop(ctx, option),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || day == null || widget.plano == null) return;
    final updated = {...selections, meal.id: picked.id};
    if (!widget.preview) {
      await Armazenamento.instance.salvarSelecoesAlimentacao(
        widget.plano!.id,
        Plano.formatDia(day!),
        updated,
      );
    }
    if (mounted) {
      setState(() {
        selections = updated;
        total = food!.total(updated);
      });
    }
  }

  Future<void> _done(RefeicaoAlimentar meal, bool value) async {
    final p = widget.plano;
    final d = day;
    if (p == null || d == null || d.isAfter(DateTime.now())) return;
    setState(() => done[meal.id] = value);
    if (!widget.preview) {
      await Armazenamento.instance.salvarRegistro(
        p.id,
        Plano.formatDia(d),
        'alimentacao_feita_${meal.id}',
        value,
      );
    }
  }

  Future<void> _restore() async {
    final p = widget.plano;
    final d = day;
    if (p == null || d == null) return;
    if (!widget.preview) {
      await Armazenamento.instance.limparSelecoesAlimentacao(
        p.id,
        Plano.formatDia(d),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final model = food;
    if (model == null || widget.plano == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'A profissional ainda não incluiu uma rotina alimentar neste acompanhamento.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (loading || day == null || total == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final target = model.meta;
    final dateLabel = DateFormat('EEEE, d/MM', 'pt_BR').format(day!);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(model.titulo, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          widget.preview
              ? 'Prévia da rotina: as marcações não são salvas.'
              : 'Rotina pronta. Altere somente a refeição ou o dia que precisar.',
          style: const TextStyle(color: apoio, fontSize: 16),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _chooseDay,
          icon: const Icon(Icons.calendar_month),
          label: Text(toBeginningOfSentenceCase(dateLabel)!),
        ),
        const SizedBox(height: 12),
        _NutritionSummary(current: total!, target: target),
        const SizedBox(height: 16),
        ...model.refeicoes.map(
          (meal) => _MealCard(
            meal: meal,
            selected: selections[meal.id],
            completed: done[meal.id] ?? false,
            canComplete: !day!.isAfter(DateTime.now()),
            onChange: () => _change(meal),
            onCompleted: (value) => _done(meal, value),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _restore,
          icon: const Icon(Icons.restore),
          label: const Text('Restaurar a rotina padrão deste dia'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Os valores são referências do plano enviado pela profissional. A escolha de um alimento não altera as metas do acompanhamento.',
          style: TextStyle(color: apoio, fontSize: 13),
        ),
      ],
    );
  }
}

class _NutritionSummary extends StatelessWidget {
  const _NutritionSummary({required this.current, required this.target});
  final Nutrientes current;
  final Nutrientes target;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFF7F8F3),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estimativa do dia',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 8),
          _NutrientLine(
            label: 'Calorias',
            value: current.kcal,
            target: target.kcal,
            unit: 'kcal',
          ),
          _NutrientLine(
            label: 'Proteína',
            value: current.proteina,
            target: target.proteina,
            unit: 'g',
          ),
          _NutrientLine(
            label: 'Carboidrato',
            value: current.carboidrato,
            target: target.carboidrato,
            unit: 'g',
          ),
          _NutrientLine(
            label: 'Gordura',
            value: current.gordura,
            target: target.gordura,
            unit: 'g',
          ),
          _NutrientLine(
            label: 'Fibra',
            value: current.fibra,
            target: target.fibra,
            unit: 'g',
          ),
        ],
      ),
    ),
  );
}

class _NutrientLine extends StatelessWidget {
  const _NutrientLine({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
  });
  final String label;
  final double value;
  final double target;
  final String unit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '${formatNutriente(value)} / ${formatNutriente(target)} $unit',
            ),
          ],
        ),
        const SizedBox(height: 3),
        LinearProgressIndicator(value: percentual(value, target), minHeight: 7),
      ],
    ),
  );
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.selected,
    required this.completed,
    required this.canComplete,
    required this.onChange,
    required this.onCompleted,
  });
  final RefeicaoAlimentar meal;
  final String? selected;
  final bool completed;
  final bool canComplete;
  final VoidCallback onChange;
  final ValueChanged<bool> onCompleted;

  @override
  Widget build(BuildContext context) {
    final option = meal.opcoes.where((item) => item.id == selected).firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    meal.horario == null
                        ? meal.titulo
                        : '${meal.titulo} · ${meal.horario}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (canComplete)
                  Checkbox(
                    value: completed,
                    onChanged: (value) => onCompleted(value ?? false),
                  ),
              ],
            ),
            Text(
              option?.nome ?? 'Escolha uma opção',
              style: const TextStyle(fontSize: 16),
            ),
            if (option != null)
              Text(
                '${option.qualidade} · ${formatNutriente(option.nutrientes.kcal)} kcal · ${formatNutriente(option.nutrientes.proteina)} g proteína',
                style: const TextStyle(color: apoio),
              ),
            if (meal.instrucao != null)
              Text(meal.instrucao!, style: const TextStyle(color: apoio)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onChange,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Trocar refeição'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reads a calculator JSON: the `alimentacao` block alone or inside an object.
Future<Map<String, dynamic>?> _lerJsonAlimentacao() async {
  final result = await FilePicker.pickFiles(type: FileType.any);
  if (result.isEmpty) return null;
  final file = result.single;
  if (file.path == null) {
    throw const FormatException('Não foi possível ler o arquivo.');
  }
  final Object? raw;
  try {
    raw = jsonDecode(utf8.decode(await File(file.path!).readAsBytes()));
  } catch (_) {
    throw const FormatException(
      'O arquivo de alimentação não é um JSON válido.',
    );
  }
  if (raw is! Map) {
    throw const FormatException(
      'O arquivo de alimentação não é um JSON válido.',
    );
  }
  final block = raw['alimentacao'] is Map ? raw['alimentacao'] : raw;
  if (block is! Map) {
    throw const FormatException('Bloco de alimentação ausente.');
  }
  AlimentacaoPlano.fromMap(block);
  return copiarDados(Map<String, dynamic>.from(block));
}

const _rotulosMacros = {
  'kcal': 'Calorias (kcal)',
  'proteina': 'Proteína (g)',
  'carboidrato': 'Carboidrato (g)',
  'gordura': 'Gordura (g)',
  'fibra': 'Fibra (g)',
};

String _numeroMacro(num v) => v == v.roundToDouble()
    ? '${v.round()}'
    : v.toStringAsFixed(1).replaceAll('.', ',');

/// Structured routine and its daily targets. Returns the block, or null to
/// remove it; popping without saving returns nothing.
class EditorAlimentacaoPage extends StatefulWidget {
  const EditorAlimentacaoPage({
    super.key,
    required this.nome,
    this.inicial,
    this.refeicoesPdf = 0,
  });
  final String nome;
  final Map<String, dynamic>? inicial;

  /// Prescribed meals read from the PDF, replaced by this routine on export.
  final int refeicoesPdf;
  @override
  State<EditorAlimentacaoPage> createState() => _EditorAlimentacaoPageState();
}

class _EditorAlimentacaoPageState extends State<EditorAlimentacaoPage> {
  Map<String, dynamic>? dados;
  final metas = {
    for (final k in _rotulosMacros.keys) k: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _usar(widget.inicial == null ? null : copiarDados(widget.inicial!));
  }

  @override
  void dispose() {
    for (final c in metas.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _usar(Map<String, dynamic>? novo) {
    dados = novo;
    final meta = novo?['meta'] as Map?;
    for (final e in metas.entries) {
      final v = meta?[e.key];
      e.value.text = v is num ? _numeroMacro(v) : '';
    }
  }

  Future<void> _importar() async {
    try {
      final novo = await _lerJsonAlimentacao();
      if (novo == null) return;
      setState(() => _usar(novo));
      if (mounted) _message(context, 'Rotina alimentar importada.');
    } catch (e) {
      if (mounted) {
        _message(
          context,
          e is FormatException
              ? e.message
              : 'Não foi possível importar a alimentação.',
        );
      }
    }
  }

  void _salvar() {
    final d = dados;
    if (d == null) {
      Navigator.pop(context, (alimentacao: null));
      return;
    }
    final meta = <String, double>{};
    for (final e in metas.entries) {
      final t = e.value.text.trim().replaceAll(',', '.');
      final v = RegExp(r'^\d+(?:\.\d+)?$').hasMatch(t)
          ? double.tryParse(t)
          : null;
      if (v == null || !v.isFinite) {
        _message(
          context,
          'Informe ${_rotulosMacros[e.key]!.toLowerCase()} com um número.',
        );
        return;
      }
      meta[e.key] = v;
    }
    final novo = copiarDados(d)..['meta'] = meta;
    try {
      AlimentacaoPlano.fromMap(novo);
    } on FormatException catch (e) {
      _message(context, e.message);
      return;
    }
    Navigator.pop(context, (alimentacao: novo));
  }

  @override
  Widget build(BuildContext context) {
    final d = dados;
    final modelo = d == null ? null : AlimentacaoPlano.fromMap(d);
    final padrao = modelo?.total(modelo.selecoesParaDia(''));
    return Scaffold(
      appBar: AppBar(title: Text('Alimentação de ${widget.nome}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Rotina com opções e nutrientes por porção. A paciente vê a estimativa do dia contra as metas abaixo e pode trocar uma refeição por outra opção da lista.',
          ),
          if (widget.refeicoesPdf > 0) ...[
            const SizedBox(height: 12),
            Text(
              'No arquivo da paciente, esta rotina substitui as ${widget.refeicoesPdf} refeições lidas do PDF e a meta de refeições. O PDF original continua anexado ao plano.',
              style: const TextStyle(color: alerta),
            ),
          ],
          const SizedBox(height: 16),
          if (modelo == null)
            const Text(
              'Nenhuma rotina incluída.',
              style: TextStyle(color: apoio),
            )
          else ...[
            Text(modelo.titulo, style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${modelo.refeicoes.length} refeições · ${modelo.refeicoes.fold<int>(0, (n, m) => n + m.opcoes.length)} opções',
              style: const TextStyle(color: apoio),
            ),
            const SizedBox(height: 16),
            Text(
              'Metas do dia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final e in metas.entries) ...[
              TextField(
                controller: e.value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: _rotulosMacros[e.key]),
              ),
              const SizedBox(height: 12),
            ],
            if (padrao != null)
              Text(
                'A rotina padrão soma ${_numeroMacro(padrao.kcal)} kcal · proteína ${_numeroMacro(padrao.proteina)} g · carboidrato ${_numeroMacro(padrao.carboidrato)} g · gordura ${_numeroMacro(padrao.gordura)} g · fibra ${_numeroMacro(padrao.fibra)} g. Mudar as metas não altera as porções.',
                style: const TextStyle(color: apoio),
              ),
            TextButton.icon(
              onPressed: () => setState(() => _usar(null)),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remover rotina alimentar'),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _importar,
            icon: const Icon(Icons.file_open),
            label: Text(
              modelo == null
                  ? 'Importar JSON da calculadora'
                  : 'Trocar pelo JSON da calculadora',
            ),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                setState(() => _usar(AlimentacaoPlano.modeloTeste())),
            icon: const Icon(Icons.science_outlined),
            label: const Text('Carregar modelo de teste'),
          ),
          const Text(
            'O JSON pode ser gerado a partir do material revisado pela profissional. O modelo de teste serve apenas para experimentar o fluxo.',
            style: TextStyle(color: apoio, fontSize: 13),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _salvar,
            icon: const Icon(Icons.check),
            label: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}
