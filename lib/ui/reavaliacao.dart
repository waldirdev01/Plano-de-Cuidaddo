part of 'app.dart';

/// Physician side: which items the patient updates and on which days.
/// Returns the request map, or null to remove it; popping returns nothing.
class EditorReavaliacaoPage extends StatefulWidget {
  const EditorReavaliacaoPage({
    super.key,
    required this.nome,
    required this.inicio,
    required this.retorno,
    this.inicial,
  });
  final String nome;
  final DateTime inicio, retorno;
  final Map<String, dynamic>? inicial;
  @override
  State<EditorReavaliacaoPage> createState() => _EditorReavaliacaoPageState();
}

class _EditorReavaliacaoPageState extends State<EditorReavaliacaoPage> {
  bool ativo = false;
  final itens = <String>{};
  final datas = <DateTime>[];

  @override
  void initState() {
    super.initState();
    final m = widget.inicial;
    if (m == null) return;
    ativo = true;
    itens.addAll((m['itens'] as List).cast<String>());
    // Dates outside a changed plan period stay listed so they can be removed.
    datas.addAll((m['datas'] as List).cast<String>().map(Plano.parseDia));
  }

  bool _foraDoPeriodo(DateTime d) =>
      d.isBefore(widget.inicio) || d.isAfter(widget.retorno);

  /// Every two weeks from the start, before the return visit.
  void _sugerir() => setState(() {
    datas.clear();
    for (
      var d = widget.inicio.add(const Duration(days: 14));
      d.isBefore(widget.retorno) && datas.length < PedidoReavaliacao.maxDatas;
      d = d.add(const Duration(days: 14))
    ) {
      datas.add(d);
    }
    if (datas.isEmpty) datas.add(widget.retorno);
  });

  Future<void> _adicionar() async {
    if (datas.length >= PedidoReavaliacao.maxDatas) {
      _message(context, 'Use no máximo 12 datas.');
      return;
    }
    final hoje = DateTime.now();
    final inicial = hoje.isBefore(widget.inicio)
        ? widget.inicio
        : hoje.isAfter(widget.retorno)
        ? widget.retorno
        : DateTime(hoje.year, hoje.month, hoje.day);
    final d = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: widget.inicio,
      lastDate: widget.retorno,
    );
    if (d == null) return;
    if (datas.any((x) => Plano.diasEntre(x, d) == 0)) {
      if (mounted) _message(context, 'Esta data já está na lista.');
      return;
    }
    setState(() => datas.add(d));
  }

  void _aplicar() {
    if (!ativo) {
      Navigator.pop(context, (reavaliacao: null));
      return;
    }
    final ordenadas = [...datas]..sort();
    final m = {
      'itens': [
        for (final i in itensReavaliacao)
          if (itens.contains(i)) i,
      ],
      'datas': ordenadas.map(Plano.formatDia).toList(),
    };
    try {
      if ((m['itens'] as List).isEmpty) {
        throw const FormatException('Marque ao menos um item para atualizar.');
      }
      if (ordenadas.isEmpty) {
        throw const FormatException('Inclua ao menos uma data.');
      }
      PedidoReavaliacao.fromMap(
        m,
        inicio: widget.inicio,
        retorno: widget.retorno,
      );
    } on FormatException catch (e) {
      _message(context, e.message);
      return;
    }
    Navigator.pop(context, (reavaliacao: m));
  }

  @override
  Widget build(BuildContext context) {
    final ordenadas = [...datas]..sort();
    return Scaffold(
      appBar: AppBar(title: Text('Reavaliação de ${widget.nome}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pedir reavaliação a esta paciente'),
            subtitle: const Text(
              'A paciente vê um cartão "Reavaliação" no app e recebe um lembrete às 9h de cada data. Ela responde e envia o arquivo, que entra na ficha.',
            ),
            value: ativo,
            onChanged: (v) => setState(() => ativo = v),
          ),
          if (ativo) ...[
            const SizedBox(height: 8),
            Text(
              'O que atualizar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final i in itensReavaliacao)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(PedidoReavaliacao.nomesItens[i]!),
                value: itens.contains(i),
                onChanged: (v) =>
                    setState(() => v == true ? itens.add(i) : itens.remove(i)),
              ),
            const SizedBox(height: 8),
            Text('Datas', style: Theme.of(context).textTheme.titleMedium),
            Text(
              'Entre ${DateFormat('dd/MM/yyyy').format(widget.inicio)} e ${DateFormat('dd/MM/yyyy').format(widget.retorno)}, até 12 datas.',
              style: const TextStyle(color: apoio),
            ),
            for (final d in ordenadas)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(DateFormat('dd/MM/yyyy').format(d)),
                subtitle: _foraDoPeriodo(d)
                    ? const Text(
                        'Fora do período do plano',
                        style: TextStyle(color: alerta),
                      )
                    : null,
                trailing: IconButton(
                  tooltip: 'Remover data',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => datas.remove(d)),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _adicionar,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar data'),
            ),
            OutlinedButton.icon(
              onPressed: _sugerir,
              icon: const Icon(Icons.auto_fix_high_outlined),
              label: const Text('Sugerir a cada 2 semanas'),
            ),
          ],
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

String _resumoPedidoReavaliacao(Object? raw) {
  if (raw is! Map) return 'Não pedida. Toque para pedir.';
  final itens = (raw['itens'] as List)
      .map((i) => PedidoReavaliacao.nomeCurto(i as String).split(' ').last)
      .join(', ');
  final datas = (raw['datas'] as List)
      .map((d) => DateFormat('dd/MM').format(Plano.parseDia(d as String)))
      .join(', ');
  return 'Pedida: $itens · $datas';
}

/// Patient side, on Hoje: shown only when the plan carries a request.
class _CartaoReavaliacao extends StatefulWidget {
  const _CartaoReavaliacao({
    super.key,
    required this.plano,
    required this.preview,
  });
  final Plano plano;
  final bool preview;
  @override
  State<_CartaoReavaliacao> createState() => _CartaoReavaliacaoState();
}

class _CartaoReavaliacaoState extends State<_CartaoReavaliacao> {
  DateTime? enviada;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.preview) return;
    final v = await Armazenamento.instance.config(
      chaveReavaliacaoEnviada(widget.plano.id),
    );
    if (mounted) setState(() => enviada = v == null ? null : DateTime.parse(v));
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.plano.reavaliacao!;
    final now = DateTime.now();
    final hoje = DateTime(now.year, now.month, now.day);
    final datas = pedido.datas.map(Plano.parseDia).toList();
    final proxima = datas.where((d) => !d.isBefore(hoje)).firstOrNull;
    final ultimoEnvio = enviada == null
        ? null
        : DateTime(enviada!.year, enviada!.month, enviada!.day);
    // Due when a requested day has arrived and nothing was sent since it.
    final pendente = datas.any(
      (d) =>
          !d.isAfter(hoje) && (ultimoEnvio == null || ultimoEnvio.isBefore(d)),
    );
    return Card(
      color: pendente ? const Color(0xFFFFF1EE) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reavaliação', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'A médica pediu para você atualizar ${pedido.itens.map(PedidoReavaliacao.nomeCurto).join(', ')}.',
            ),
            Text(
              pendente
                  ? 'Já está no dia. Responda e envie à médica.'
                  : proxima == null
                  ? 'Não há mais datas neste plano.'
                  : 'Próxima data: ${DateFormat('dd/MM/yyyy').format(proxima)}.',
              style: TextStyle(color: pendente ? alerta : apoio),
            ),
            if (enviada != null)
              Text(
                'Última enviada em ${DateFormat('dd/MM/yyyy').format(enviada!)}.',
                style: const TextStyle(color: apoio),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: widget.preview
                  ? null
                  : () async {
                      await _abrirReavaliacao(context, widget.plano);
                      await _load();
                    },
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Fazer a reavaliação'),
            ),
          ],
        ),
      ),
    );
  }
}
