part of 'app.dart';

/// Aba Treino do paciente: programa de 4 semanas (calculado no aparelho a
/// partir do bloco `treino` do plano) e registro do que foi feito.
class TreinoPage extends StatefulWidget {
  const TreinoPage({super.key, required this.plano});
  final Plano plano;
  @override
  State<TreinoPage> createState() => _TreinoPageState();
}

class _TreinoPageState extends State<TreinoPage> {
  EscolhasTreino esc = const EscolhasTreino();
  ProgramaTreino? programa;
  bool pronto = false;
  int aba = 0;

  String get _chave => 'treino_escolhas_${widget.plano.id}';
  PrescricaoTreino get _presc => widget.plano.treino!;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didUpdateWidget(covariant TreinoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plano.id != widget.plano.id) {
      pronto = false;
      _carregar();
    }
  }

  Future<void> _carregar() async {
    var e = const EscolhasTreino();
    try {
      final raw = await Armazenamento.instance.config(_chave);
      if (raw != null) e = EscolhasTreino.fromMap(jsonDecode(raw));
    } catch (_) {
      // Escolhas ilegíveis voltam ao padrão; o plano não é afetado.
    }
    if (!mounted) return;
    setState(() {
      esc = e;
      programa = montarTreino(_presc, e);
      pronto = true;
    });
  }

  Future<void> _mudar(EscolhasTreino e) async {
    setState(() {
      esc = e;
      programa = montarTreino(_presc, e);
    });
    await Armazenamento.instance.setConfig(_chave, jsonEncode(e.toMap()));
  }

  @override
  Widget build(BuildContext context) {
    if (!pronto || programa == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Meu treino')),
              ButtonSegment(value: 1, label: Text('Registrar')),
            ],
            selected: {aba},
            onSelectionChanged: (s) => setState(() => aba = s.first),
          ),
        ),
        Expanded(
          child: aba == 0
              ? _ProgramaTreinoView(
                  presc: _presc,
                  esc: esc,
                  programa: programa!,
                  onChange: _mudar,
                )
              : _RegistroTreinoView(
                  key: ValueKey('${widget.plano.id}-${esc.toMap()}'),
                  plano: widget.plano,
                  programa: programa!,
                ),
        ),
      ],
    );
  }
}

Widget _dropTreino<T>(
  String rotulo,
  T valor,
  Map<T, String> itens,
  ValueChanged<T> aoMudar,
) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: DropdownButtonFormField<T>(
    key: ValueKey('$rotulo-$valor'),
    initialValue: valor,
    isExpanded: true,
    decoration: InputDecoration(labelText: rotulo),
    items: [
      for (final e in itens.entries)
        DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
    ],
    onChanged: (v) {
      if (v != null) aoMudar(v);
    },
  ),
);

String _fmtMin(double m) {
  final inteiro = m.floor();
  final seg = ((m - inteiro) * 60).round();
  if (seg == 0) return '$inteiro min';
  return inteiro == 0 ? '$seg s' : '$inteiro min $seg s';
}

class _ProgramaTreinoView extends StatelessWidget {
  const _ProgramaTreinoView({
    required this.presc,
    required this.esc,
    required this.programa,
    required this.onChange,
  });
  final PrescricaoTreino presc;
  final EscolhasTreino esc;
  final ProgramaTreino programa;
  final ValueChanged<EscolhasTreino> onChange;

  EscolhasTreino _copia({
    String? local,
    String? aerobico,
    int? dias,
    int? minutos,
  }) => EscolhasTreino(
    local: local ?? esc.local,
    aerobico: aerobico ?? esc.aerobico,
    dias: dias ?? esc.dias,
    minutos: minutos ?? esc.minutos,
  );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final resumo = [
      nomesNivelTreino[presc.nivel]!,
      objetivosTreino[presc.objetivo]!,
      if (presc.limitacoes.isNotEmpty)
        'Adaptado para: ${presc.limitacoes.map((x) => limitacoesTreino[x]!.toLowerCase()).join(', ')}',
      if (presc.posParto) 'Adaptado para o pós-parto',
    ].join(' · ');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Meu treino', style: tema.headlineSmall),
        const SizedBox(height: 4),
        Text(resumo),
        const SizedBox(height: 4),
        const Text(
          'Programa de 4 semanas. A semana 1 começa na data de início do plano.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Escolha como vai treinar', style: tema.titleMedium),
                const SizedBox(height: 12),
                _dropTreino<String>(
                  'Onde faz o treino de força',
                  esc.local,
                  locaisForcaTreino,
                  (v) => onChange(_copia(local: v)),
                ),
                _dropTreino<String>(
                  'Onde faz o aeróbico',
                  esc.aerobico,
                  locaisAerobicoTreino,
                  (v) => onChange(_copia(aerobico: v)),
                ),
                _dropTreino<int>(
                  'Dias de treino por semana',
                  esc.dias,
                  const {
                    2: '2 dias',
                    3: '3 dias',
                    4: '4 dias',
                    5: '5 dias',
                    6: '6 dias',
                  },
                  (v) => onChange(_copia(dias: v)),
                ),
                _dropTreino<int>(
                  'Tempo por sessão',
                  esc.minutos,
                  const {
                    20: '20 minutos',
                    30: '30 minutos',
                    45: '45 minutos',
                    60: '60 minutos',
                  },
                  (v) => onChange(_copia(minutos: v)),
                ),
              ],
            ),
          ),
        ),
        const _TituloTreino('Como medir o esforço'),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Força: pare cada série deixando algumas repetições na reserva. Se a tabela diz esforço 3, você pararia com 3 repetições sobrando. Nunca leve a série até não conseguir mais.',
                ),
                SizedBox(height: 8),
                Text(
                  'Aeróbico moderado: esforço 4 a 5 de 10. Você consegue conversar, mas não cantar.',
                ),
                SizedBox(height: 8),
                Text(
                  'Aquecimento (5 min): caminhada leve ou marcha no lugar, círculos de ombros, quadris e joelhos. Depois, 1 a 2 séries leves do primeiro exercício.',
                ),
              ],
            ),
          ),
        ),
        const _TituloTreino('Sua semana'),
        for (final d in programa.dias)
          _DiaTreinoCard(dia: d, programa: programa),
        const _TituloTreino('Aeróbico da semana'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var w = 0; w < 4; w++)
                  Text(
                    'Semana ${w + 1}: ${programa.aeroPorSemana[w]} min nos treinos · meta ${programa.metaPorSemana[w]} min',
                  ),
                const SizedBox(height: 8),
                Text(
                  'Complete o que faltar para a meta com caminhadas de 10 a 15 min ao longo da semana. A meta para adultos é de 150 a 300 min por semana de atividade aeróbica moderada (OMS).${presc.objetivo == 'perda' || presc.objetivo == 'manut' ? ' Quando estiver confortável, aumente aos poucos rumo a 200 a 300 min.' : ''}',
                ),
              ],
            ),
          ),
        ),
        const _TituloTreino('Como progredir'),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quando fizer o topo das repetições em todas as séries, com técnica boa e no esforço indicado, aumente a carga em cerca de 2 a 5% na sessão seguinte.',
                ),
                SizedBox(height: 8),
                Text(
                  'Sem carga: aumente as repetições, desça em 3 segundos ou passe para a variação mais difícil.',
                ),
                SizedBox(height: 8),
                Text(
                  'Espere 48 a 72 horas antes de treinar o mesmo grupo muscular de novo.',
                ),
              ],
            ),
          ),
        ),
        if (presc.posParto) ...[
          const _TituloTreino('Cuidados no pós-parto'),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solte o ar durante o esforço. Não prenda a respiração.',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sem abdominais tradicionais e sem impacto (pular, correr).',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Faça os exercícios do assoalho pélvico todos os dias: contraia como se segurasse o xixi por 3 segundos e relaxe.',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Pare e procure atendimento se houver perda de urina, peso ou pressão na pelve, dor, abaulamento na barriga ou aumento do sangramento.',
                  ),
                ],
              ),
            ),
          ),
        ],
        const _TituloTreino('Quando parar'),
        const Card(
          color: Color(0xFFFFF1EE),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Pare o treino e procure atendimento se tiver dor no peito, falta de ar desproporcional, tontura, desmaio, palpitação ou dor articular aguda. Dor que piora durante o exercício: pare esse exercício.',
              style: TextStyle(color: alerta, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Este é um exemplo inicial e genérico. O ideal é acompanhamento de um profissional de educação física assim que for viável.',
        ),
        const SizedBox(height: 12),
        const EmergencyNotice(),
      ],
    );
  }
}

class _TituloTreino extends StatelessWidget {
  const _TituloTreino(this.texto);
  final String texto;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(texto, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _DiaTreinoCard extends StatelessWidget {
  const _DiaTreinoCard({required this.dia, required this.programa});
  final DiaTreino dia;
  final ProgramaTreino programa;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    if (dia.tipo == 'R') {
      return Card(
        child: ListTile(
          title: Text('${dia.nome} · Descanso ativo'),
          subtitle: const Text(
            'Caminhada leve de 20 a 30 min e alongamento, ou descanso total.',
          ),
        ),
      );
    }
    if (dia.tipo == 'C') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${dia.nome} · Aeróbico', style: tema.titleMedium),
              const SizedBox(height: 8),
              for (var w = 0; w < 4; w++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(_textoAero(dia, w)),
                ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${dia.nome} · ${dia.titulo}', style: tema.titleMedium),
            Text('Cerca de ${dia.estimativaMin} min'),
            const SizedBox(height: 8),
            for (final it in dia.itens) ...[
              Text(
                '${it.rotulo}. ${it.nome}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(it.dica, style: const TextStyle(color: apoio)),
              for (var w = 0; w < 4; w++)
                Text(
                  'Semana ${w + 1}: ${it.semanas[w].series}×${it.semanas[w].texto} · sobrar ${programa.esforco[w]}',
                ),
              Text('Pausa: ${it.pausa}', style: const TextStyle(color: apoio)),
              const SizedBox(height: 10),
            ],
            if (dia.itens.any((i) => i.emPar))
              const Text(
                'Exercícios com a mesma letra (A1 e A2) são feitos em sequência, sem pausa. Descanse só depois do par. Se o aparelho estiver ocupado, faça um de cada vez.',
              ),
            if (dia.itens.any((i) => i.unilateral))
              const Text(
                '"Por lado": faça um lado, depois o outro, e descanse.',
              ),
          ],
        ),
      ),
    );
  }
}

String _textoAero(DiaTreino d, int w) {
  final h = d.intervalado[w];
  if (h != null) {
    return 'Semana ${w + 1}: 5 min de aquecimento, ${h.series} × (${_fmtMin(h.forteMin)} forte, esforço ${h.esforco}, e ${_fmtMin(h.leveMin)} leve), 5 min de volta à calma. Use ${h.modalidade}.';
  }
  return 'Semana ${w + 1}: ${d.minutos[w]} min contínuos, esforço 4 a 5 de 10. ${d.modalidade}';
}

// ---------------------------------------------------------------------------
// Registro

class _RegistroTreinoView extends StatefulWidget {
  const _RegistroTreinoView({
    super.key,
    required this.plano,
    required this.programa,
  });
  final Plano plano;
  final ProgramaTreino programa;
  @override
  State<_RegistroTreinoView> createState() => _RegistroTreinoViewState();
}

class _RegistroTreinoViewState extends State<_RegistroTreinoView> {
  late DateTime data;
  int? indiceDia;
  bool carregando = true;
  int versao = 0;
  final Map<String, RegistroExercicio> registros = {};
  final Map<String, RegistroExercicio> anteriores = {};
  Map<String, dynamic>? aero;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    var d = DateTime(hoje.year, hoje.month, hoje.day);
    if (d.isBefore(widget.plano.inicio)) d = widget.plano.inicio;
    if (d.isAfter(widget.plano.fim)) d = widget.plano.fim;
    data = d;
    _escolherDiaPadrao();
    _carregar();
  }

  List<DiaTreino> get _treinaveis =>
      widget.programa.dias.where((d) => d.tipo != 'R').toList();

  void _escolherDiaPadrao() {
    final lista = _treinaveis;
    if (lista.isEmpty) {
      indiceDia = null;
      return;
    }
    final seg = data.weekday - 1;
    indiceDia = lista.any((d) => d.indice == seg) ? seg : lista.first.indice;
  }

  DiaTreino? get _dia {
    for (final d in _treinaveis) {
      if (d.indice == indiceDia) return d;
    }
    return null;
  }

  int get _semana => semanaDoPrograma(widget.plano.inicio, data);
  String get _dataTexto => Plano.formatDia(data);

  Future<void> _carregar() async {
    if (mounted && !carregando) setState(() => carregando = true);
    final db = Armazenamento.instance;
    final dia = _dia;
    final salvos = await db.registros(widget.plano.id, _dataTexto);
    final historico = data.isAfter(widget.plano.inicio)
        ? await db.registrosPeriodo(
            widget.plano.id,
            widget.plano.inicio,
            data.subtract(const Duration(days: 1)),
          )
        : <String, Map<String, dynamic>>{};
    final datas = historico.keys.toList()..sort();
    anteriores.clear();
    for (final dt in datas) {
      for (final e in historico[dt]!.entries) {
        if (!campoDeTreino(e.key) || e.key == campoAerobicoTreino) continue;
        if (!registroExercicioValido(e.value)) continue;
        anteriores[e.key] = RegistroExercicio.fromMap(e.value);
      }
    }
    registros.clear();
    aero = null;
    if (dia != null && dia.tipo == 'S') {
      final semana = _semana;
      for (final it in dia.itens) {
        final id = 'trn_${it.chave}';
        final planejadas = it.semanas[semana].series;
        final salvo = salvos[id];
        if (salvo != null && registroExercicioValido(salvo)) {
          final r = RegistroExercicio.fromMap(salvo);
          while (r.series.length < planejadas) {
            r.series.add(SerieRegistro(reps: _topo(it, semana)));
          }
          registros[id] = r;
        } else {
          registros[id] = _preencher(it, semana, id);
        }
      }
    } else if (dia != null && dia.tipo == 'C') {
      final salvo = salvos[campoAerobicoTreino];
      aero = (salvo != null && registroAerobicoValido(salvo))
          ? Map<String, dynamic>.from(salvo as Map)
          : {'feito': false, 'min': dia.minutos[_semana]};
    }
    if (!mounted) return;
    setState(() {
      carregando = false;
      versao++;
    });
  }

  int _topo(ItemTreino it, int semana) =>
      faixaDeTexto(it.semanas[semana].texto).alto;

  /// Valores já preenchidos: repetições no topo da faixa e a carga da última
  /// vez (ou a sugerida pela regra). A paciente só altera o que for diferente.
  RegistroExercicio _preencher(ItemTreino it, int semana, String id) {
    final planejadas = it.semanas[semana].series;
    double? kg;
    final ant = anteriores[id];
    if (ant != null) {
      final comCarga = ant.series
          .where((s) => s.kg != null && s.kg! > 0)
          .toList();
      if (comCarga.isNotEmpty) kg = comCarga.last.kg;
      final s = sugerirCarga(ant, planejadas, it.semanas[semana].texto);
      if (s != null &&
          (s.direcao == 'sobe' || s.direcao == 'desce') &&
          s.kg != null) {
        kg = s.kg;
      }
    }
    return RegistroExercicio(
      nome: it.nome,
      series: [
        for (var i = 0; i < planejadas; i++)
          SerieRegistro(reps: _topo(it, semana), kg: kg),
      ],
    );
  }

  Future<void> _gravar(String id, RegistroExercicio r) async {
    await Armazenamento.instance.salvarRegistro(
      widget.plano.id,
      _dataTexto,
      id,
      r.toMap(),
    );
  }

  Future<void> _gravarAero() async {
    await Armazenamento.instance.salvarRegistro(
      widget.plano.id,
      _dataTexto,
      campoAerobicoTreino,
      aero,
    );
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final limite = DateTime(hoje.year, hoje.month, hoje.day);
    final ultimo = limite.isBefore(widget.plano.fim)
        ? limite
        : widget.plano.fim;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: data.isAfter(ultimo) ? ultimo : data,
      firstDate: widget.plano.inicio,
      lastDate: ultimo,
    );
    if (escolhida == null || !mounted) return;
    setState(() {
      data = DateTime(escolhida.year, escolhida.month, escolhida.day);
      _escolherDiaPadrao();
    });
    await _carregar();
  }

  Future<void> _marcarTudo(DiaTreino dia) async {
    final semana = _semana;
    final todas = dia.itens.every((it) {
      final r = registros['trn_${it.chave}'];
      return r != null && r.series.every((s) => s.feita);
    });
    for (final it in dia.itens) {
      final id = 'trn_${it.chave}';
      final r = registros[id];
      if (r == null) continue;
      for (final s in r.series) {
        s.feita = !todas;
        s.reps ??= _topo(it, semana);
      }
      await _gravar(id, r);
    }
    if (mounted) setState(() => versao++);
  }

  @override
  Widget build(BuildContext context) {
    final dia = _dia;
    final tema = Theme.of(context).textTheme;
    final treinaveis = _treinaveis;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Registrar treino', style: tema.headlineSmall),
        const SizedBox(height: 4),
        const Text(
          'Os valores já vêm preenchidos com o plano. Marque cada série quando terminar e altere só o que for diferente. Seus registros ficam neste aparelho e vão para a médica no arquivo de acompanhamento.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(data),
                ),
                subtitle: Text('Semana ${_semana + 1} do programa'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _escolherData,
              ),
              if (treinaveis.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('dia-$_dataTexto-$indiceDia'),
                    initialValue: indiceDia,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Treino do dia',
                    ),
                    items: [
                      for (final d in treinaveis)
                        DropdownMenuItem<int>(
                          value: d.indice,
                          child: Text('${d.nome} · ${d.titulo}'),
                        ),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => indiceDia = v);
                      await _carregar();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (carregando)
          const Center(child: CircularProgressIndicator())
        else if (dia == null)
          const Text('Não há treino para registrar.')
        else if (dia.tipo == 'C')
          _cardAero(dia)
        else ...[
          for (final it in dia.itens) _cardExercicio(it),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _marcarTudo(dia),
            icon: const Icon(Icons.done_all),
            label: Text(
              dia.itens.every((it) {
                    final r = registros['trn_${it.chave}'];
                    return r != null && r.series.every((s) => s.feita);
                  })
                  ? 'Desmarcar treino'
                  : 'Marcar treino todo feito',
            ),
          ),
        ],
        const SizedBox(height: 16),
        const EmergencyNotice(),
      ],
    );
  }

  Widget _cardAero(DiaTreino dia) {
    final a = aero!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${dia.nome} · Aeróbico',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(_textoAero(dia, _semana)),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: a['feito'] == true,
              title: const Text('Feito'),
              onChanged: (v) async {
                setState(() => a['feito'] = v == true);
                await _gravarAero();
              },
            ),
            TextFormField(
              key: ValueKey('aero-$_dataTexto-$versao'),
              initialValue: '${a['min'] ?? ''}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minutos feitos'),
              onChanged: (t) async {
                a['min'] = int.tryParse(t.trim());
                await _gravarAero();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardExercicio(ItemTreino it) {
    final id = 'trn_${it.chave}';
    final r = registros[id];
    if (r == null) return const SizedBox.shrink();
    final semana = _semana;
    final plan = it.semanas[semana];
    final sug = sugerirCarga(r, plan.series, plan.texto);
    final iso = faixaDeTexto(plan.texto).tempo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${it.rotulo}. ${it.nome}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Meta: ${plan.series}×${plan.texto} · sobrar ${widget.programa.esforco[semana]}',
              style: const TextStyle(color: apoio),
            ),
            for (var i = 0; i < r.series.length; i++)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: r.series[i].feita,
                      title: Text('Série ${i + 1}'),
                      onChanged: (v) async {
                        setState(() => r.series[i].feita = v == true);
                        await _gravar(id, r);
                      },
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      key: ValueKey('r-$_dataTexto-$id-$i-$versao'),
                      initialValue: r.series[i].reps?.toString() ?? '',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: iso ? 'seg' : 'reps',
                      ),
                      onChanged: (t) async {
                        r.series[i].reps = int.tryParse(t.trim());
                        await _gravar(id, r);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      key: ValueKey('k-$_dataTexto-$id-$i-$versao'),
                      initialValue: r.series[i].kg == null
                          ? ''
                          : kgTexto(r.series[i].kg!),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'kg'),
                      onChanged: (t) async {
                        r.series[i].kg = double.tryParse(
                          t.trim().replaceAll(',', '.'),
                        );
                        await _gravar(id, r);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              key: ValueKey('s-$_dataTexto-$id-$versao'),
              initialValue: r.sobraram,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Repetições que sobraram na última série',
              ),
              items: const [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Como no plano'),
                ),
                DropdownMenuItem<int?>(
                  value: 0,
                  child: Text('0 (fui até a falha)'),
                ),
                DropdownMenuItem<int?>(value: 1, child: Text('1')),
                DropdownMenuItem<int?>(value: 2, child: Text('2')),
                DropdownMenuItem<int?>(value: 3, child: Text('3')),
                DropdownMenuItem<int?>(value: 4, child: Text('4 ou mais')),
              ],
              onChanged: (v) async {
                setState(() => r.sobraram = v);
                await _gravar(id, r);
              },
            ),
            if (sug != null && sug.mensagem.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  sug.mensagem,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: sug.direcao == 'desce' ? alerta : verde,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profissional

/// Define o bloco `treino` do plano. Só os parâmetros clínicos ficam no
/// arquivo; local, dias e tempo são escolhidos pelo paciente.
///
/// Com [plano], salva o plano manual. Sem ele (rascunho de PDF), não grava:
/// devolve `(treino: bloco ou null)` para a conferência aplicar a alteração.
class EditorTreinoPage extends StatefulWidget {
  const EditorTreinoPage({super.key, required Plano this.plano})
    : nome = null,
      inicial = null;
  const EditorTreinoPage.rascunho({
    super.key,
    required String this.nome,
    this.inicial,
  }) : plano = null;
  final Plano? plano;
  final String? nome;
  final Map<String, dynamic>? inicial;
  @override
  State<EditorTreinoPage> createState() => _EditorTreinoPageState();
}

class _EditorTreinoPageState extends State<EditorTreinoPage> {
  bool ativo = false, posParto = false, triagem = false, liberacao = false;
  bool salvando = false;
  int nivel = 1;
  String objetivo = 'perda';
  final Set<String> limitacoes = {};

  @override
  void initState() {
    super.initState();
    final t = widget.plano?.data['treino'] ?? widget.inicial;
    if (t is Map) {
      try {
        final p = PrescricaoTreino.fromMap(t);
        ativo = true;
        nivel = p.nivel;
        objetivo = p.objetivo;
        limitacoes.addAll(p.limitacoes);
        posParto = p.posParto;
        triagem = true;
        liberacao = p.posParto;
      } on FormatException {
        ativo = false;
      }
    }
  }

  PrescricaoTreino _montar() => PrescricaoTreino(
    nivel: nivel,
    objetivo: objetivo,
    limitacoes: limitacoes.toList()..sort(),
    posParto: posParto,
  );

  Future<void> _salvar() async {
    if (ativo && !triagem) {
      _message(context, 'Confirme a triagem de segurança negativa.');
      return;
    }
    if (ativo && posParto && !liberacao) {
      _message(
        context,
        'Confirme a liberação da paciente para exercício no pós-parto.',
      );
      return;
    }
    final plano = widget.plano;
    if (plano == null) {
      Navigator.pop(context, (treino: ativo ? _montar().toMap() : null));
      return;
    }
    setState(() => salvando = true);
    try {
      final dados = copiarDados(plano.data);
      if (ativo) {
        dados['treino'] = _montar().toMap();
      } else {
        dados.remove('treino');
      }
      final novo = Plano.parse(jsonEncode(dados));
      await Armazenamento.instance.salvarCriado(novo);
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (e) {
      if (mounted) _message(context, e.message);
    } catch (_) {
      if (mounted) {
        _message(
          context,
          'Não foi possível salvar. O plano anterior continua neste aparelho.',
        );
      }
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Treino de ${widget.plano?.nomePaciente ?? widget.nome}'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Incluir treino neste plano'),
          subtitle: const Text(
            'O paciente recebe uma aba Treino com o programa de 4 semanas e o registro das séries.',
          ),
          value: ativo,
          onChanged: (v) => setState(() => ativo = v),
        ),
        if (ativo) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: ValueKey('nivel-$nivel'),
            initialValue: nivel,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nível de treino'),
            items: [
              for (final e in niveisTreino.entries)
                DropdownMenuItem<int>(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => nivel = v ?? nivel),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('objetivo-$objetivo'),
            initialValue: objetivo,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Objetivo'),
            items: [
              for (final e in objetivosTreino.entries)
                DropdownMenuItem<String>(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => objetivo = v ?? objetivo),
          ),
          const SizedBox(height: 12),
          Text(
            'Limitações articulares leves (sem dor aguda)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final e in limitacoesTreino.entries)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(e.value),
              value: limitacoes.contains(e.key),
              onChanged: (v) => setState(() {
                if (v == true) {
                  limitacoes.add(e.key);
                } else {
                  limitacoes.remove(e.key);
                }
              }),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pós-parto ou amamentando'),
            value: posParto,
            onChanged: (v) => setState(() {
              posParto = v;
              if (!v) liberacao = false;
            }),
          ),
          if (posParto)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Avaliei e liberei a paciente para exercício no pós-parto',
              ),
              value: liberacao,
              onChanged: (v) => setState(() => liberacao = v == true),
            ),
          const Divider(height: 32),
          Card(
            color: const Color(0xFFFFF1EE),
            child: CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Triagem de segurança negativa: sem dor no peito, falta de ar desproporcional ao esforço, desmaio, palpitação, problema ortopédico atual não avaliado ou outra contraindicação conhecida.',
              ),
              value: triagem,
              onChanged: (v) => setState(() => triagem = v == true),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PreviaTreinoPage(presc: _montar()),
              ),
            ),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Pré-visualizar o treino'),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: salvando ? null : _salvar,
          child: Text(
            salvando
                ? 'Salvando...'
                : widget.plano == null
                ? 'Aplicar na conferência'
                : 'Salvar',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.plano == null
              ? 'A alteração desfaz as confirmações. Conclua a conferência novamente antes de exportar.'
              : 'Depois de salvar, use Exportar no cartão do plano para enviar o arquivo atualizado ao paciente.',
        ),
      ],
    ),
  );
}

class PreviaTreinoPage extends StatefulWidget {
  const PreviaTreinoPage({super.key, required this.presc});
  final PrescricaoTreino presc;
  @override
  State<PreviaTreinoPage> createState() => _PreviaTreinoPageState();
}

class _PreviaTreinoPageState extends State<PreviaTreinoPage> {
  EscolhasTreino esc = const EscolhasTreino();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Prévia do treino')),
    body: _ProgramaTreinoView(
      presc: widget.presc,
      esc: esc,
      programa: montarTreino(widget.presc, esc),
      onChange: (e) => setState(() => esc = e),
    ),
  );
}
