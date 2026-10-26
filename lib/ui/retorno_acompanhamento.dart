part of 'app.dart';

Future<void> _abrirExportacaoAcompanhamento(
  BuildContext context,
  Plano plano,
) async {
  try {
    await Armazenamento.instance.conferirDestinatario(plano);
    final registros = await Armazenamento.instance.registrosPeriodo(
      plano.id,
      plano.inicio,
      plano.fim,
    );
    final retorno = RetornoAcompanhamento.criar(plano, registros);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalheRetornoPage(retorno: retorno, exportar: true),
      ),
    );
  } on FormatException catch (e) {
    if (context.mounted) _message(context, e.message);
  } catch (_) {
    if (context.mounted) {
      _message(
        context,
        'Não foi possível preparar o acompanhamento. Os registros foram mantidos.',
      );
    }
  }
}

Future<void> _receberRetorno(
  BuildContext context,
  RetornoAcompanhamento retorno,
) async {
  final db = Armazenamento.instance;
  if (await db.papel() != 'profissional') {
    throw const FormatException(
      'Este arquivo é um acompanhamento para a médica, não uma prescrição. Troque para o modo profissional para abri-lo.',
    );
  }
  retorno.conferirProfissional(
    await db.config('profissional_nome') ?? '',
    await db.config('profissional_registro') ?? '',
  );
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Receber acompanhamento?'),
      content: SingleChildScrollView(
        child: Text(
          '${retorno.plano.nomePaciente}\nNascimento: ${DateFormat('dd/MM/yyyy').format(Plano.parseDia(retorno.plano.nascimentoPaciente!))}\n'
          '${fmtDia.format(retorno.plano.inicio)} a ${fmtDia.format(retorno.ate)}\n'
          'Destinatária: ${retorno.plano.nomeProfissional}\nRegistro: ${retorno.plano.data['profissional']['registro']}\n\n'
          'São informações declaradas pelo paciente, sem assinatura digital ou comprovação de execução. O arquivo será guardado separadamente; não altera a prescrição nem o cadastro do paciente.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Receber e visualizar'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final novo = await db.guardarRetorno(retorno);
  if (!context.mounted) return;
  if (!novo) {
    _message(
      context,
      'Este arquivo já foi recebido. Abrindo a cópia guardada.',
    );
  }
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DetalheRetornoPage(retorno: retorno)),
  );
}

class RetornosRecebidosPage extends StatefulWidget {
  const RetornosRecebidosPage({super.key});
  @override
  State<RetornosRecebidosPage> createState() => _RetornosRecebidosPageState();
}

class _RetornosRecebidosPageState extends State<RetornosRecebidosPage> {
  List<RetornoAcompanhamento> retornos = [];
  bool loading = true;
  String busca = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await Armazenamento.instance.retornosRecebidos();
      if (mounted) {
        setState(() {
          retornos = list;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
        _message(context, 'Não foi possível carregar os acompanhamentos.');
      }
    }
  }

  Future<void> _importar() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      if ((await files.single.length() ?? 0) >
          RetornoAcompanhamento.limiteBytes) {
        throw const FormatException('Selecione um acompanhamento de até 5 MB.');
      }
      final bytes = await files.single.readAsBytes();
      final r = RetornoAcompanhamento.parse(utf8.decode(bytes));
      if (!mounted) return;
      await _receberRetorno(context, r);
      await _load();
    } on FormatException catch (e) {
      if (mounted) _message(context, e.message);
    } catch (_) {
      if (mounted) {
        _message(
          context,
          'Não foi possível abrir o acompanhamento. Nada foi alterado.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = retornos
        .where(
          (r) =>
              r.plano.nomePaciente.toLowerCase().contains(busca.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Acompanhamentos recebidos')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: _importar,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Abrir acompanhamento .plano'),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar paciente',
                  ),
                  onChanged: (v) => setState(() => busca = v),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Cada arquivo é um retrato dos registros até sua exportação. Novos envios não substituem os anteriores.',
                  ),
                ),
                if (list.isEmpty)
                  const Text(
                    'Nenhum acompanhamento recebido para este perfil profissional.',
                  ),
                for (final r in list)
                  Card(
                    child: ListTile(
                      title: Text(r.plano.nomePaciente),
                      subtitle: Text(
                        '${fmtDia.format(r.plano.inicio)}–${fmtDia.format(r.ate)} · Exportado ${DateFormat('dd/MM/yyyy HH:mm').format(r.exportadoEm.toLocal())}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetalheRetornoPage(retorno: r),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class DetalheRetornoPage extends StatefulWidget {
  const DetalheRetornoPage({
    super.key,
    required this.retorno,
    this.exportar = false,
  });
  final RetornoAcompanhamento retorno;
  final bool exportar;
  @override
  State<DetalheRetornoPage> createState() => _DetalheRetornoPageState();
}

class _DetalheRetornoPageState extends State<DetalheRetornoPage> {
  bool busy = false;
  Future<void> _compartilhar() async {
    setState(() => busy = true);
    try {
      final r = widget.retorno;
      await Armazenamento.instance.conferirDestinatario(r.plano);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/acompanhamento-${r.id}.plano');
      await file.writeAsString(jsonEncode(r.data), flush: true);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Acompanhamento de ${r.plano.nomePaciente}',
          text:
              'Acompanhamento para ${r.plano.nomeProfissional}, até ${fmtDia.format(r.ate)}. Abrir no modo profissional do Plano de Cuidado atualizado.',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (!mounted || result.status == ShareResultStatus.dismissed) return;
      final enviado = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Você enviou à médica?'),
          content: const Text(
            'Salvar em Arquivos não envia à médica. Confirme somente se você já encaminhou o arquivo para ela. Isso registra sua declaração de envio, não o recebimento ou a leitura.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Só salvei / ainda não enviei'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Já enviei à médica'),
            ),
          ],
        ),
      );
      if (enviado == true) {
        await Armazenamento.instance.registrarEnvio(
          r.plano.id,
          DateTime.now(),
          r.plano.inicio,
          r.ate,
        );
        await Lembretes.instance.reagendar(
          await Armazenamento.instance.planoAtivo(),
          ativo: await Armazenamento.instance.config('lembretes') != 'nao',
        );
      }
    } catch (_) {
      if (mounted) {
        _message(
          context,
          'Não foi possível concluir o compartilhamento. Seus registros continuam salvos; você pode tentar novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.retorno;
    final p = r.plano;
    final dias = diasDoPlano(p.inicio, r.ate);
    final campos = p.camposRegistraveis;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.exportar
              ? 'Conferir acompanhamento'
              : 'Acompanhamento do paciente',
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dias.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  p.nomePaciente,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Nascimento: ${DateFormat('dd/MM/yyyy').format(Plano.parseDia(p.nascimentoPaciente!))}',
                ),
                Text(
                  'Profissional: ${p.nomeProfissional} · ${p.data['profissional']['registro']}',
                ),
                Text(
                  'Período: ${DateFormat('dd/MM/yyyy').format(p.inicio)} a ${DateFormat('dd/MM/yyyy').format(r.ate)}',
                ),
                Text(
                  'Exportado em ${DateFormat('dd/MM/yyyy HH:mm').format(r.exportadoEm.toLocal())}',
                ),
                Text(
                  '${r.quantidadeRegistros} registros informados. Toque em cada dia para consultar.',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Informações declaradas pelo paciente. Sem marcação = não confirmado; não comprova que não fez. Quantidades são valores registrados, não confirmação automática da meta. Este arquivo não tem assinatura digital nem comprovação de autenticidade.',
                  ),
                ),
                ExpansionTile(
                  title: const Text('Metas e refeições prescritas'),
                  children: [
                    for (final f in campos)
                      ListTile(
                        title: Text(f['titulo'] as String),
                        subtitle: Text(
                          [
                            if (f['tipo'] == 'contador')
                              'Meta: ${f['alvo']} ${f['unidade']}',
                            if (f['descricao'] is String)
                              f['descricao'] as String,
                            if (f['tipo'] == 'refeicao')
                              'Horário: ${f['horario']}',
                            if (f['tipo'] == 'refeicao' &&
                                f['regra'] == 'condicional')
                              'Dispensa: ${f['condicao']}',
                          ].join('\n'),
                        ),
                      ),
                  ],
                ),
                if (widget.exportar) ...[
                  const Text(
                    'O arquivo contém dados de saúde legíveis, sem senha. Confira o paciente e escolha a destinatária correta. Envie apenas este arquivo de acompanhamento; não é necessário mandar uma cópia de segurança.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: busy ? null : _compartilhar,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Compartilhar acompanhamento .plano'),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          }
          final dia = dias[i - 1];
          final valores = r.registros[Plano.formatDia(dia)] as Map? ?? const {};
          final treinoDia =
              r.registrosTreino[Plano.formatDia(dia)] as Map? ?? const {};
          return Card(
            child: ExpansionTile(
              key: ValueKey('retorno-dia-${Plano.formatDia(dia)}'),
              title: Text(DateFormat('dd/MM/yyyy').format(dia)),
              subtitle: Text(
                '${valores.values.where((v) => v != null).length} de ${campos.length} campos informados',
              ),
              children: [
                for (final f in campos)
                  ListTile(
                    title: Text(f['titulo'] as String),
                    subtitle: Text(_textoRegistroRetorno(valores[f['id']], f)),
                  ),
                if (treinoDia.isNotEmpty) ...[
                  const ListTile(
                    title: Text(
                      'Treino',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final e in treinoDia.entries)
                    ListTile(
                      title: Text(_tituloTreinoRetorno(e.key, e.value)),
                      subtitle: Text(_textoTreinoRetorno(e.key, e.value)),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

String _textoRegistroRetorno(dynamic valor, Map<String, dynamic> campo) {
  if (valor == null) return 'Não confirmado';
  return _display(valor, campo);
}

String _tituloTreinoRetorno(String id, dynamic v) => id == campoAerobicoTreino
    ? 'Aeróbico'
    : (v is Map ? v['nome'] as String : id);

String _textoTreinoRetorno(String id, dynamic v) {
  if (v is! Map) return 'Não confirmado';
  if (id == campoAerobicoTreino) {
    final min = v['min'];
    return v['feito'] == true
        ? 'Feito${min is num ? ', $min min' : ''}'
        : 'Não confirmado';
  }
  final r = RegistroExercicio.fromMap(v);
  final series = [
    for (var i = 0; i < r.series.length; i++)
      if (r.series[i].feita)
        '${i + 1}: ${r.series[i].reps ?? '–'} reps'
            '${r.series[i].kg != null ? ' × ${kgTexto(r.series[i].kg!)} kg' : ''}',
  ];
  if (series.isEmpty) return 'Nenhuma série confirmada';
  return [
    '${r.feitas} séries feitas',
    series.join(' · '),
    if (r.sobraram != null) 'Sobraram ${r.sobraram} repetições na última série',
  ].join('\n');
}
