part of 'app.dart';

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
        : initial.isAfter(p.retorno)
        ? p.retorno
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
      lastDate: p.retorno,
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
