part of 'app.dart';

/// Prescribed meals. Meals with foods from the bundled table become a
/// calculator: the patient trades a food for today and the grams are worked out
/// to keep the group's main macro; the day total is compared with the targets.
class RotinaPrescritaPage extends StatefulWidget {
  const RotinaPrescritaPage({
    super.key,
    required this.plano,
    this.preview = false,
  });
  final Plano plano;
  final bool preview;
  @override
  State<RotinaPrescritaPage> createState() => _RotinaPrescritaPageState();
}

class _RotinaPrescritaPageState extends State<RotinaPrescritaPage> {
  Map<String, Map<String, dynamic>> trocas = {};
  TabelaAlimentos? tabela;

  Plano get plano => widget.plano;
  bool get temAlimentos =>
      plano.refeicoesPrescritas.any((m) => m['alimentos'] != null);

  String get dia {
    final now = DateTime.now();
    final hoje = DateTime(now.year, now.month, now.day);
    return Plano.formatDia(
      hoje.isBefore(plano.inicio)
          ? plano.inicio
          : hoje.isAfter(plano.fim)
          ? plano.fim
          : hoje,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RotinaPrescritaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plano.id != plano.id) _load();
  }

  Future<void> _load() async {
    if (!temAlimentos) return;
    final t = await TabelaAlimentos.carregar();
    final salvas = widget.preview
        ? <String, Map<String, dynamic>>{}
        : await Armazenamento.instance.trocasAlimentos(plano.id, dia);
    if (mounted) {
      setState(() {
        tabela = t;
        trocas = salvas;
      });
    }
  }

  /// Today's foods of [meal]: the plan's, with the trades applied.
  List<(ItemAlimento, ItemAlimento?)> _hoje(Map<String, dynamic> meal) =>
      alimentosDoDia(meal, trocas);

  Future<void> _guardar(String chave, ItemAlimento? item) async {
    setState(() {
      if (item == null) {
        trocas.remove(chave);
      } else {
        trocas[chave] = item.toMap();
      }
    });
    if (!widget.preview) {
      await Armazenamento.instance.salvarTrocasAlimentos(plano.id, dia, trocas);
    }
  }

  Future<void> _trocar(
    String chave,
    ItemAlimento atual,
    ItemAlimento doPlano,
  ) async {
    final t = tabela;
    if (t == null) return;
    // Equivalence always starts from the plan's food, so trades never drift.
    final opcoes = t.trocasPara(doPlano);
    final escolhido = await showModalBottomSheet<ItemAlimento>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TrocaAlimentoSheet(doPlano: doPlano, opcoes: opcoes),
    );
    if (escolhido == null) return;
    await _guardar(
      chave,
      escolhido.alimento.id == doPlano.alimento.id ? null : escolhido,
    );
  }

  String _macros(Nutrientes n) =>
      '${_numeroMacro(n.kcal.round())} kcal · P ${_numeroMacro(n.proteina)} · C ${_numeroMacro(n.carboidrato)} · G ${_numeroMacro(n.gordura)}';

  Widget _metas(Map<String, double> metas) {
    final calcula = temAlimentos && tabela != null;
    final total = calcula
        ? somarAlimentos([
            for (final meal in plano.refeicoesPrescritas)
              for (final (item, _) in _hoje(meal)) item,
          ])
        : null;
    final semAlimentos = plano.refeicoesPrescritas
        .where((m) => m['alimentos'] == null)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metas do dia', style: Theme.of(context).textTheme.titleLarge),
            Text(
              total == null
                  ? 'Somando todas as refeições do dia, conforme a médica definiu.'
                  : 'Quanto o cardápio de hoje soma, contando as suas trocas.',
              style: const TextStyle(color: apoio),
            ),
            const SizedBox(height: 8),
            for (final e in _rotulosMacros.entries)
              if (metas[e.key] case final v?)
                Text(
                  total == null
                      ? '${e.value.replaceAll(RegExp(r' \(.*\)'), '')}: ${_numeroMacro(v)} ${e.key == 'kcal' ? 'kcal' : 'g'}'
                      : '${e.value.replaceAll(RegExp(r' \(.*\)'), '')}: ${_numeroMacro(_valor(total, e.key).round())} de ${_numeroMacro(v)} ${e.key == 'kcal' ? 'kcal' : 'g'}',
                  style: const TextStyle(fontSize: 18),
                ),
            if (total != null && semAlimentos > 0)
              Text(
                semAlimentos == 1
                    ? 'Uma refeição não tem alimentos definidos e não entra na soma.'
                    : '$semAlimentos refeições não têm alimentos definidos e não entram na soma.',
                style: const TextStyle(color: apoio),
              ),
          ],
        ),
      ),
    );
  }

  double _valor(Nutrientes n, String chave) => switch (chave) {
    'kcal' => n.kcal,
    'proteina' => n.proteina,
    'carboidrato' => n.carboidrato,
    'gordura' => n.gordura,
    _ => n.fibra,
  };

  Widget _alimentos(Map<String, dynamic> meal) {
    final itens = _hoje(meal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < itens.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(itens[i].$1.alimento.nome),
            subtitle: Text(
              '${_numeroMacro(itens[i].$1.gramas)} g · ${_macros(itens[i].$1.nutrientes)}'
              '${itens[i].$2 == null ? '' : '\nTrocado hoje. No plano: ${itens[i].$2!.alimento.nome}, ${_numeroMacro(itens[i].$2!.gramas)} g.'}'
              '${itens[i].$2 == null ? '' : switch (motivoMenosIndicada(itens[i].$1, itens[i].$2!)) {
                      null => '',
                      final m => '\nMenos indicada: $m. Há opções melhores no botão de troca.',
                    }}',
            ),
            trailing: tabela == null
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (itens[i].$2 != null)
                        IconButton(
                          tooltip: 'Voltar ao alimento do plano',
                          icon: const Icon(Icons.undo),
                          onPressed: () => _guardar('${meal['id']}|$i', null),
                        ),
                      IconButton(
                        tooltip: 'Trocar alimento',
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: () => _trocar(
                          '${meal['id']}|$i',
                          itens[i].$1,
                          itens[i].$2 ?? itens[i].$1,
                        ),
                      ),
                    ],
                  ),
          ),
        Text(
          'Total da refeição: ${_macros(somarAlimentos(itens.map((e) => e.$1)))}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Minha rotina alimentar',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(
        temAlimentos
            ? 'Prescrição conferida pela profissional. Registre cada refeição na aba Hoje. Se não quiser um alimento hoje, toque em trocar: o app calcula a quantidade do novo alimento.'
            : 'Prescrição conferida pela profissional. Registre cada refeição na aba Hoje. Não há cálculo de nutrientes ou troca automática de alimentos.',
      ),
      if (plano.metasMacro case final metas?) _metas(metas),
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
                if (meal['alimentos'] != null) ...[
                  _alimentos(meal),
                  const SizedBox(height: 8),
                  const Text(
                    'Orientação da médica',
                    style: TextStyle(color: apoio),
                  ),
                ],
                SelectableText(meal['descricao'] as String),
              ],
            ),
          ),
        ),
      if (temAlimentos)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Valores estimados pela $fonteAlimentos',
            style: TextStyle(color: apoio, fontSize: 13),
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

class _TrocaAlimentoSheet extends StatefulWidget {
  const _TrocaAlimentoSheet({required this.doPlano, required this.opcoes});
  final ItemAlimento doPlano;
  final List<ItemAlimento> opcoes;
  @override
  State<_TrocaAlimentoSheet> createState() => _TrocaAlimentoSheetState();
}

class _TrocaAlimentoSheetState extends State<_TrocaAlimentoSheet> {
  String busca = '';

  @override
  Widget build(BuildContext context) {
    final grupo = gruposAlimentos[widget.doPlano.alimento.grupo]!;
    final mantem = switch (grupo.chave) {
      'gramas' => 'Mesma quantidade em gramas.',
      'kcal' => 'Quantidades com as mesmas calorias.',
      'carboidrato' => 'Quantidades com o mesmo carboidrato.',
      'proteina' => 'Quantidades com a mesma proteína.',
      _ => 'Quantidades com a mesma gordura.',
    };
    final chave = PerfilPaciente.normalizarNome(busca);
    final achadas = widget.opcoes.where(
      (o) => PerfilPaciente.normalizarNome(o.alimento.nome).contains(chave),
    );
    final boas = [
      for (final o in achadas)
        if (motivoMenosIndicada(o, widget.doPlano) == null) o,
    ];
    final outras = [
      for (final o in achadas)
        if (motivoMenosIndicada(o, widget.doPlano) != null) o,
    ];
    // Plan food first, then good trades, then a labelled block of worse ones.
    final linhas = <Object>[
      if (busca.trim().isEmpty) widget.doPlano,
      ...boas,
      if (outras.isNotEmpty) 'Menos indicadas',
      ...outras,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trocar ${widget.doPlano.alimento.nome} (${_numeroMacro(widget.doPlano.gramas)} g)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${grupo.nome}. $mantem',
                  style: const TextStyle(color: apoio),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar alimento',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => busca = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: linhas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum alimento deste grupo com esse nome.'),
                  )
                : ListView.builder(
                    controller: scroll,
                    itemCount: linhas.length,
                    itemBuilder: (_, i) {
                      final linha = linhas[i];
                      if (linha is String) {
                        return const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            'Menos indicadas: mais calorias ou ultraprocessados',
                            style: TextStyle(
                              color: alerta,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }
                      final o = linha as ItemAlimento;
                      final doPlano = identical(o, widget.doPlano);
                      final motivo = doPlano
                          ? null
                          : motivoMenosIndicada(o, widget.doPlano);
                      return ListTile(
                        title: Text(o.alimento.nome),
                        subtitle: Text(
                          '${_numeroMacro(o.gramas)} g · ${_numeroMacro(o.nutrientes.kcal.round())} kcal'
                          '${doPlano ? ' · como está no plano' : ''}'
                          '${motivo == null ? '' : ' · $motivo'}',
                        ),
                        onTap: () => _escolher(o, motivo),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _escolher(ItemAlimento o, String? motivo) async {
    if (motivo != null) {
      final melhores = melhoresTrocas(widget.opcoes, widget.doPlano);
      final seguir = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Há opções melhores'),
          content: Text(
            '${o.alimento.nome}: $motivo em relação ao plano.'
            '${melhores.isEmpty ? '' : '\n\nMelhores trocas:\n${melhores.map((m) => '• ${m.alimento.nome}, ${_numeroMacro(m.gramas)} g').join('\n')}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Escolher outra'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Trocar mesmo assim'),
            ),
          ],
        ),
      );
      if (seguir != true || !mounted) return;
    }
    Navigator.pop(context, o);
  }
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

String _resumoMetasMacro(Map<dynamic, dynamic> m) =>
    '${_numeroMacro(m['kcal'] as num)} kcal · proteína ${_numeroMacro(m['proteina'] as num)} g · carboidrato ${_numeroMacro(m['carboidrato'] as num)} g · gordura ${_numeroMacro(m['gordura'] as num)} g${m['fibra'] == null ? '' : ' · fibra ${_numeroMacro(m['fibra'] as num)} g'}';

/// Structured routine and its daily targets. Returns the block, or null to
/// remove it, plus the targets; popping without saving returns nothing.
class EditorAlimentacaoPage extends StatefulWidget {
  const EditorAlimentacaoPage({
    super.key,
    required this.nome,
    this.inicial,
    this.refeicoesPdf = 0,
    this.pdf = false,
    this.metasIniciais,
  });
  final String nome;
  final Map<String, dynamic>? inicial;

  /// Prescribed meals read from the PDF, replaced by this routine on export.
  final int refeicoesPdf;

  /// PDF plans may carry daily targets without a structured routine.
  final bool pdf;
  final Map<String, dynamic>? metasIniciais;
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
    final m = widget.metasIniciais;
    if (widget.inicial == null && m != null) {
      for (final e in metas.entries) {
        final v = m[e.key];
        e.value.text = v is num ? _numeroMacro(v) : '';
      }
    }
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
    // In a PDF plan the targets typed by the physician win over the routine's.
    if (widget.pdf && novo == null) return;
    final meta = novo?['meta'] as Map?;
    for (final e in metas.entries) {
      final v = meta?[e.key];
      if (widget.pdf && e.value.text.trim().isNotEmpty) continue;
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
    final vazias = metas.values.every((c) => c.text.trim().isEmpty);
    if (d == null && (!widget.pdf || vazias)) {
      Navigator.pop(context, (alimentacao: null, metas: null));
      return;
    }
    final meta = <String, double>{};
    for (final e in metas.entries) {
      if (d == null && e.key == 'fibra' && e.value.text.trim().isEmpty) {
        continue;
      }
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
    if (d == null) {
      final erro = validarMetasMacro(meta);
      if (erro != null) {
        _message(context, 'Metas do dia: $erro');
        return;
      }
      Navigator.pop(context, (alimentacao: null, metas: meta));
      return;
    }
    final novo = copiarDados(d)..['meta'] = meta;
    try {
      AlimentacaoPlano.fromMap(novo);
    } on FormatException catch (e) {
      _message(context, e.message);
      return;
    }
    Navigator.pop(context, (alimentacao: novo, metas: meta));
  }

  List<Widget> _camposMetas({bool fibraOpcional = false}) => [
    for (final e in metas.entries) ...[
      TextField(
        controller: e.value,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: fibraOpcional && e.key == 'fibra'
              ? 'Fibra (g), opcional'
              : _rotulosMacros[e.key],
        ),
      ),
      const SizedBox(height: 12),
    ],
  ];

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
          Text(
            widget.pdf
                ? 'Metas de calorias e macros do dia. Sem rotina com opções, a paciente vê estas metas na aba Alimentação, junto das refeições do PDF. Deixe todos os campos vazios para não enviar metas.'
                : 'Rotina com opções e nutrientes por porção. A paciente vê a estimativa do dia contra as metas abaixo e pode trocar uma refeição por outra opção da lista.',
          ),
          if (widget.pdf) ...[
            const SizedBox(height: 16),
            Text(
              'Metas do dia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._camposMetas(fibraOpcional: modelo == null),
            const SizedBox(height: 8),
            Text(
              'Rotina com opções (opcional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          if (widget.refeicoesPdf > 0 && modelo != null) ...[
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
            if (!widget.pdf) ...[
              const SizedBox(height: 16),
              Text(
                'Metas do dia',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._camposMetas(),
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

/// Physician: foods and grams of one prescribed meal, editable after the PDF
/// import. Returns the new list, or null to remove the foods; popping without
/// applying returns nothing.
class EditorAlimentosRefeicaoPage extends StatefulWidget {
  const EditorAlimentosRefeicaoPage({
    super.key,
    required this.titulo,
    this.inicial,
  });
  final String titulo;
  final List<dynamic>? inicial;
  @override
  State<EditorAlimentosRefeicaoPage> createState() =>
      _EditorAlimentosRefeicaoPageState();
}

class _EditorAlimentosRefeicaoPageState
    extends State<EditorAlimentosRefeicaoPage> {
  final itens = <(Alimento, TextEditingController)>[];
  TabelaAlimentos? tabela;

  @override
  void initState() {
    super.initState();
    for (final i
        in widget.inicial == null
            ? const <ItemAlimento>[]
            : validarAlimentos(widget.inicial)) {
      itens.add((
        i.alimento,
        TextEditingController(text: _numeroMacro(i.gramas)),
      ));
    }
    TabelaAlimentos.carregar().then((t) {
      if (mounted) setState(() => tabela = t);
    });
  }

  @override
  void dispose() {
    for (final (_, c) in itens) {
      c.dispose();
    }
    super.dispose();
  }

  double? _gramas(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    final v = RegExp(r'^\d+(?:\.\d+)?$').hasMatch(t)
        ? double.tryParse(t)
        : null;
    return v != null && v >= 1 && v <= 2000 ? v : null;
  }

  Future<void> _adicionar() async {
    final t = tabela;
    if (t == null) return;
    final escolhido = await showModalBottomSheet<Alimento>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BuscaAlimentoSheet(
        tabela: t,
        usados: {for (final (a, _) in itens) a.id},
      ),
    );
    if (escolhido == null) return;
    setState(() => itens.add((escolhido, TextEditingController(text: '100'))));
  }

  void _aplicar() {
    if (itens.isEmpty) {
      Navigator.pop(context, (alimentos: null));
      return;
    }
    final lista = <Map<String, dynamic>>[];
    for (final (a, c) in itens) {
      final g = _gramas(c);
      if (g == null) {
        _message(context, 'Informe de 1 a 2000 g em ${a.nome}.');
        return;
      }
      lista.add(ItemAlimento(a, g).toMap());
    }
    try {
      validarAlimentos(lista);
    } on FormatException catch (e) {
      _message(context, e.message);
      return;
    }
    Navigator.pop(context, (alimentos: lista));
  }

  @override
  Widget build(BuildContext context) {
    final validos = [
      for (final (a, c) in itens)
        if (_gramas(c) case final g?) ItemAlimento(a, g),
    ];
    final total = somarAlimentos(validos);
    return Scaffold(
      appBar: AppBar(title: Text('Alimentos: ${widget.titulo}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'A paciente vê estes alimentos com as gramas e os nutrientes da tabela TACO, e pode trocar cada um por outro do mesmo grupo no dia. A prescrição em texto continua como orientação.',
          ),
          const SizedBox(height: 12),
          if (itens.isEmpty)
            const Text(
              'Nenhum alimento nesta refeição.',
              style: TextStyle(color: apoio),
            ),
          for (var n = 0; n < itens.length; n++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(itens[n].$1.nome),
                        Text(switch (_gramas(itens[n].$2)) {
                          final g? =>
                            '${_numeroMacro(ItemAlimento(itens[n].$1, g).nutrientes.kcal.round())} kcal',
                          null => 'Gramas inválidas',
                        }, style: const TextStyle(color: apoio)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: itens[n].$2,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Gramas de ${itens[n].$1.nome}',
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        hintText: 'g',
                        suffixText: 'g',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remover ${itens[n].$1.nome}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        setState(() => itens.removeAt(n).$2.dispose()),
                  ),
                ],
              ),
            ),
          if (validos.isNotEmpty)
            Text(
              'Total: ${_numeroMacro(total.kcal.round())} kcal · proteína ${_numeroMacro(total.proteina)} g · carboidrato ${_numeroMacro(total.carboidrato)} g · gordura ${_numeroMacro(total.gordura)} g',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: tabela == null || itens.length >= maxAlimentosRefeicao
                ? null
                : _adicionar,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar alimento'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _aplicar,
            icon: const Icon(Icons.check),
            label: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}

class _BuscaAlimentoSheet extends StatefulWidget {
  const _BuscaAlimentoSheet({required this.tabela, required this.usados});
  final TabelaAlimentos tabela;
  final Set<int> usados;
  @override
  State<_BuscaAlimentoSheet> createState() => _BuscaAlimentoSheetState();
}

class _BuscaAlimentoSheetState extends State<_BuscaAlimentoSheet> {
  String busca = '';

  @override
  Widget build(BuildContext context) {
    final chave = PerfilPaciente.normalizarNome(busca);
    final lista = chave.length < 2
        ? const <Alimento>[]
        : [
            for (final a in widget.tabela.alimentos)
              if (!widget.usados.contains(a.id) &&
                  PerfilPaciente.normalizarNome(a.nome).contains(chave))
                a,
          ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Buscar na tabela de alimentos',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => busca = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: lista.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(lista[i].nome),
                subtitle: Text(
                  '${gruposAlimentos[lista[i].grupo]!.nome} · ${_numeroMacro(lista[i].por100.kcal.round())} kcal em 100 g',
                ),
                onTap: () => Navigator.pop(context, lista[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
