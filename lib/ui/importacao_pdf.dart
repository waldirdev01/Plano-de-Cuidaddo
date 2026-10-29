part of 'app.dart';

/// Stage 1 stops at a professional draft, outside the .plano/patient workflow.
class ConferenciaPdfPage extends StatefulWidget {
  const ConferenciaPdfPage({super.key, required this.rascunho, this.arquivos});
  final RascunhoPdf rascunho;
  final ArquivosRascunhoPdf? arquivos;
  @override
  State<ConferenciaPdfPage> createState() => _ConferenciaPdfPageState();
}

class _ConferenciaPdfPageState extends State<ConferenciaPdfPage> {
  late final RascunhoPdf r;
  late final ArquivosRascunhoPdf arquivos;
  bool dirty = false, saving = false, saindo = false;
  @override
  void initState() {
    super.initState();
    r = RascunhoPdf(copiarDados(widget.rascunho.data));
    arquivos = widget.arquivos ?? ArquivosRascunhoPdf();
    // A newly imported document has not yet been persisted.
    dirty = widget.rascunho.data['salvo'] != true;
  }

  void _alterar(VoidCallback action, {bool confirmacao = false}) {
    setState(() {
      action();
      if (r.data['padraoPdf'] == PadraoPdf.versao) {
        PadraoPdf.atualizarItens(r.data);
      }
      dirty = true;
      r.data['estado'] = 'rascunho';
      if (!confirmacao) {
        for (final key in (r.data['confirmacoes'] as Map).keys) {
          r.data['confirmacoes'][key] = false;
        }
      }
    });
  }

  Future<bool> _salvar({bool concluir = false}) async {
    FocusScope.of(context).unfocus();
    if (concluir) {
      final errors = r.validarConferencia();
      if (errors.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ainda falta conferir'),
            content: SingleChildScrollView(
              child: Text(errors.map((e) => '• $e').join('\n\n')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Continuar conferindo'),
              ),
            ],
          ),
        );
        return false;
      }
    }
    setState(() => saving = true);
    final previous = r.estado;
    try {
      if (concluir) r.data['estado'] = 'conferido';
      r.data['criadoEm'] ??= r.data['atualizadoEm'];
      r.data['salvo'] = true;
      await arquivos.salvar(r);
      if (!mounted) return true;
      setState(() => dirty = false);
      _message(
        context,
        concluir
            ? 'Conferência salva. Você já pode visualizar e exportar o .plano.'
            : 'Rascunho salvo neste aparelho.',
      );
      return true;
    } catch (_) {
      r.data['estado'] = previous;
      if (mounted) {
        _message(
          context,
          'Não foi possível salvar. Mantenha a tela aberta e tente novamente.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _sair() async {
    if (saving || saindo) return;
    saindo = true;
    if (dirty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Guardar esta conferência?'),
          content: const Text(
            'Você pode salvar mesmo com pendências e continuar depois. Os planos do paciente não serão alterados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'continuar'),
              child: const Text('Continuar aqui'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'descartar'),
              child: const Text('Sair sem salvar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'salvar'),
              child: const Text('Salvar e sair'),
            ),
          ],
        ),
      );
      if (choice == null ||
          choice == 'continuar' ||
          (choice == 'salvar' && !await _salvar())) {
        saindo = false;
        return;
      }
    }
    if (!mounted) return;
    setState(() => dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  String _resumoTreino() {
    final t = r.data['treino'];
    if (t is! Map) return 'Não incluído. Toque para incluir.';
    final p = PrescricaoTreino.fromMap(t);
    return 'Incluído: ${nomesNivelTreino[p.nivel]} · ${objetivosTreino[p.objetivo]}';
  }

  Future<void> _editarAlimentos(Map<String, dynamic> meal) async {
    final resultado =
        await Navigator.push<({List<Map<String, dynamic>>? alimentos})>(
          context,
          MaterialPageRoute(
            builder: (_) => EditorAlimentosRefeicaoPage(
              titulo: meal['titulo'] as String,
              inicial: meal['alimentos'] as List?,
            ),
          ),
        );
    if (resultado == null ||
        jsonEncode(resultado.alimentos) == jsonEncode(meal['alimentos'])) {
      return;
    }
    _alterar(() {
      if (resultado.alimentos == null) {
        meal.remove('alimentos');
      } else {
        meal['alimentos'] = resultado.alimentos;
      }
    });
  }

  /// Day total of the foods read from the PDF meals, or null when none has foods.
  Nutrientes? _somaAlimentos() {
    final meals = r.lista('refeicoes').where((m) => m['alimentos'] != null);
    if (meals.isEmpty) return null;
    return somarAlimentos([
      for (final m in meals) ...validarAlimentos(m['alimentos']),
    ]);
  }

  String _resumoAlimentacao() {
    final a = r.data['alimentacao'];
    final metas = r.data['metasMacro'];
    if (a is! Map && metas is Map) {
      final soma = _somaAlimentos();
      return 'Metas do dia: ${_resumoMetasMacro(metas)}.'
          '${soma == null ? ' Sem rotina com opções.' : ' Os alimentos das refeições somam ${_numeroMacro(soma.kcal.round())} kcal · proteína ${_numeroMacro(soma.proteina.round())} g · carboidrato ${_numeroMacro(soma.carboidrato.round())} g · gordura ${_numeroMacro(soma.gordura.round())} g.'}';
    }
    if (a is! Map) {
      return 'Não incluída. Toque para incluir metas de calorias e macros.';
    }
    final m = AlimentacaoPlano.fromMap(a);
    return 'Incluída: ${_numeroMacro(m.meta.kcal)} kcal · proteína ${_numeroMacro(m.meta.proteina)} g. Substitui as refeições do PDF.';
  }

  Future<void> _editarAlimentacao() async {
    final atual = r.data['alimentacao'] as Map<String, dynamic>?;
    final metasAtuais = r.data['metasMacro'] as Map<String, dynamic>?;
    final resultado =
        await Navigator.push<
          ({Map<String, dynamic>? alimentacao, Map<String, double>? metas})
        >(
          context,
          MaterialPageRoute(
            builder: (_) => EditorAlimentacaoPage(
              nome: (r.campos['nome'] as String).isEmpty
                  ? 'Paciente a conferir'
                  : r.campos['nome'] as String,
              inicial: atual,
              refeicoesPdf: r.lista('refeicoes').length,
              pdf: true,
              metasIniciais: metasAtuais,
            ),
          ),
        );
    if (resultado == null) return;
    // With a routine its own targets are used; the PDF targets go away.
    final metas = resultado.alimentacao == null ? resultado.metas : null;
    if (jsonEncode(resultado.alimentacao) == jsonEncode(atual) &&
        jsonEncode(metas) == jsonEncode(metasAtuais)) {
      return;
    }
    _alterar(() {
      if (resultado.alimentacao == null) {
        r.data.remove('alimentacao');
      } else {
        r.data['alimentacao'] = resultado.alimentacao;
      }
      if (metas == null) {
        r.data.remove('metasMacro');
      } else {
        r.data['metasMacro'] = metas;
      }
    });
  }

  Future<void> _editarReavaliacao() async {
    final DateTime inicio, retorno;
    try {
      inicio = Plano.parseDia(r.campos['inicio'] as String);
      retorno = Plano.parseDia(r.campos['retorno'] as String);
      if (retorno.isBefore(inicio)) throw const FormatException('');
    } catch (_) {
      _message(
        context,
        'Confira o início dos registros e o retorno antes de pedir a reavaliação.',
      );
      return;
    }
    final atual = r.data['reavaliacao'] as Map<String, dynamic>?;
    final resultado =
        await Navigator.push<({Map<String, dynamic>? reavaliacao})>(
          context,
          MaterialPageRoute(
            builder: (_) => EditorReavaliacaoPage(
              nome: (r.campos['nome'] as String).isEmpty
                  ? 'Paciente a conferir'
                  : r.campos['nome'] as String,
              inicio: inicio,
              retorno: retorno,
              inicial: atual,
            ),
          ),
        );
    if (resultado == null ||
        jsonEncode(resultado.reavaliacao) == jsonEncode(atual)) {
      return;
    }
    _alterar(() {
      if (resultado.reavaliacao == null) {
        r.data.remove('reavaliacao');
      } else {
        r.data['reavaliacao'] = resultado.reavaliacao;
      }
    });
  }

  Future<void> _editarTreino() async {
    final atual = r.data['treino'] as Map<String, dynamic>?;
    final resultado = await Navigator.push<({Map<String, dynamic>? treino})>(
      context,
      MaterialPageRoute(
        builder: (_) => EditorTreinoPage.rascunho(
          nome: (r.campos['nome'] as String).isEmpty
              ? 'Paciente a conferir'
              : r.campos['nome'] as String,
          inicial: atual,
        ),
      ),
    );
    if (resultado == null ||
        jsonEncode(resultado.treino) == jsonEncode(atual)) {
      return;
    }
    _alterar(() {
      if (resultado.treino == null) {
        r.data.remove('treino');
      } else {
        r.data['treino'] = resultado.treino;
      }
    });
  }

  Future<void> _exportarConferido({bool previa = false}) async {
    if (dirty || r.estado != 'conferido') return;
    try {
      final db = Armazenamento.instance;
      final plano = planoDoPdfConferido(
        r,
        profissional: await db.config('profissional_nome') ?? '',
        registro: await db.config('profissional_registro') ?? '',
      );
      if (!mounted) return;
      if (previa) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PreviaPlanoPage(plano: plano)),
        );
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Conferir destinatário da exportação'),
          content: SingleChildScrollView(
            child: Text(
              '${plano.nomePaciente}\nNascimento: ${DateFormat('dd/MM/yyyy').format(Plano.parseDia(plano.nascimentoPaciente!))}\n\n'
              'Profissional: ${plano.nomeProfissional}\nRegistro: ${plano.data['profissional']['registro']}\n\n'
              'Registros: ${fmtDia.format(plano.inicio)} a ${fmtDia.format(plano.fim)}\nRetorno: ${fmtDia.format(plano.retorno)}\n\n'
              'O arquivo contém dados de saúde e o PDF original. Compartilhe somente com o paciente correto. A versão do paciente precisa estar atualizada para abrir o formato 4. Exportar não confirma envio nem recebimento.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Compartilhar .plano'),
            ),
          ],
        ),
      );
      if (accepted == true && mounted) await _exportarPlano(context, plano);
    } on FormatException catch (e) {
      if (mounted) _message(context, e.message);
    } catch (_) {
      if (mounted) {
        _message(
          context,
          'Não foi possível preparar o plano. A conferência salva foi preservada.',
        );
      }
    }
  }

  Widget _campo(
    Map<String, dynamic> map,
    String key,
    String label, {
    int lines = 1,
    bool data = false,
    String? ajuda,
  }) {
    var value = map[key] as String? ?? '';
    if (data) {
      try {
        value = DateFormat('dd/MM/yyyy').format(Plano.parseDia(value));
      } catch (_) {
        /* Keep partial input. */
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        key: ValueKey('${identityHashCode(map)}-$key'),
        initialValue: value,
        minLines: lines,
        maxLines: lines == 1 ? 1 : null,
        keyboardType: data
            ? TextInputType.datetime
            : lines > 1
            ? TextInputType.multiline
            : TextInputType.text,
        inputFormatters: data
            ? [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final text = _formatarDataDigitada(newValue.text);
                  return TextEditingValue(
                    text: text,
                    selection: TextSelection.collapsed(offset: text.length),
                  );
                }),
              ]
            : null,
        decoration: InputDecoration(
          labelText: label,
          helperText: ajuda,
          helperMaxLines: 5,
          alignLabelWithHint: lines > 1,
        ),
        onChanged: (text) => _alterar(() {
          var saved = text;
          if (data && text.length == 10) {
            final parts = text.split('/');
            if (parts.length == 3) {
              final iso = '${parts[2]}-${parts[1]}-${parts[0]}';
              try {
                Plano.parseDia(iso);
                saved = iso;
              } catch (_) {
                /* Validator reports it on completion. */
              }
            }
          }
          map[key] = saved;
        }),
      ),
    );
  }

  Widget _origem(String text) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text(
      'Consultar texto de origem',
      style: TextStyle(fontSize: 14),
    ),
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SelectableText(text),
      ),
    ],
  );

  Widget _bloco(String title, List<Widget> children, {bool aberto = false}) =>
      Card(
        child: ExpansionTile(
          initiallyExpanded: aberto,
          maintainState: true,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          childrenPadding: const EdgeInsets.all(16),
          children: children,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = r.campos;
    final padronizado = r.data['padraoPdf'] == PadraoPdf.versao;
    final checks = r.data['confirmacoes'] as Map;
    return PopScope(
      canPop: !dirty && !saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _sair();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Conferir PDF'),
          leading: IconButton(
            onPressed: saving ? null : _sair,
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: 'Consultar PDF original',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _PdfOriginalRascunhoPage(
                    bytes: base64Decode(r.data['pdf']['base64'] as String),
                  ),
                ),
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: saving,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Conferência da profissional',
                style: TextStyle(color: verde, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'A leitura não cria prescrição. Confira os dados com o PDF. Alterações ficam somente neste rascunho; o documento original não é reescrito.',
              ),
              const SizedBox(height: 8),
              Text(
                padronizado
                    ? 'Modelo PLANO-CUIDADO/1. Somente os campos identificados são importados. Textos livres não viram alarmes nem tarefas.'
                    : 'Rascunho do modelo antigo. Foi preservado, mas novas importações exigem PLANO-CUIDADO/1. Os avisos antigos não analisam qualquer ambiguidade.',
                style: const TextStyle(color: apoio),
              ),
              const SizedBox(height: 8),
              Text(
                '${r.data['pdf']['nome']} · ${(r.data['paginas'] as List).length} páginas',
                style: const TextStyle(color: apoio),
              ),
              const SizedBox(height: 8),
              Text(
                r.estado == 'conferido'
                    ? 'Conferência concluída e salva. Pronta para exportar ao paciente.'
                    : 'Rascunho: ainda não é um arquivo .plano para o paciente.',
                style: TextStyle(
                  color: r.estado == 'conferido' ? verde : alerta,
                ),
              ),
              const SizedBox(height: 12),
              _bloco('Paciente e datas', [
                _campo(
                  c,
                  'nome',
                  'Nome completo do paciente',
                  ajuda:
                      'Confira o nome completo; o PDF pode mostrar um nome abreviado.',
                ),
                _campo(
                  c,
                  'nascimento',
                  'Nascimento do paciente',
                  data: true,
                  ajuda:
                      'Não é preenchido a partir de outros pacientes ou do nome do arquivo.',
                ),
                _campo(c, 'consulta', 'Data da consulta', data: true),
                _campo(c, 'emissao', 'Data de emissão do PDF', data: true),
                _campo(c, 'inicio', 'Início dos registros', data: true),
                _campo(c, 'fim', 'Último dia de registro', data: true),
                _campo(c, 'retorno', 'Data do retorno', data: true),
                _campo(
                  c,
                  'horaRetorno',
                  'Horário do retorno',
                  ajuda:
                      'HH:MM. Retorno e fim dos registros são campos separados.',
                ),
                _origem(r.data['origens']['identidade'] as String),
                _origem(r.data['origens']['retorno'] as String),
              ], aberto: true),
              _bloco('Metas reconhecidas (${r.lista('metas').length})', [
                for (final meta in r.lista('metas')) ...[
                  _campo(meta, 'titulo', 'Título da meta'),
                  _campo(meta, 'descricao', 'Orientação da meta', lines: 3),
                  if (meta['tipo'] == 'contador') ...[
                    _campo(meta, 'alvo', 'Quantidade-alvo'),
                    _campo(meta, 'unidade', 'Unidade da contagem'),
                    if (padronizado)
                      _campo(
                        meta,
                        'distribuicao',
                        'Distribuição da quantidade',
                        lines: 2,
                        ajuda:
                            'HH:MM=quantidade; HH:MM=quantidade. A soma deve ser igual ao alvo. Use LIVRE para distribuir ao longo do dia sem horários fixos.',
                      ),
                  ],
                  if (meta['tipo'] == 'checklist' && padronizado)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        'Refeições obrigatórias: ${(meta['itens'] as String).isEmpty ? 'nenhuma; confira as condições das refeições' : meta['itens']}. As condicionais ficam separadas, com sua regra de dispensa.',
                      ),
                    ),
                  if (meta['tipo'] == 'checklist' && !padronizado)
                    _campo(
                      meta,
                      'itens',
                      'Itens para confirmar',
                      ajuda:
                          'Separados por vírgula. Confira o que é obrigatório e o que pode ser dispensado.',
                    ),
                  _campo(
                    meta,
                    'horarios',
                    'Horários propostos da meta',
                    ajuda:
                        'HH:MM separados por vírgula. Pode ficar vazio se não houver alarme. Não confundir quantidade de avisos com quantidade de copos.',
                  ),
                  const Divider(),
                ],
              ]),
              _bloco('Refeições reconhecidas (${r.lista('refeicoes').length})', [
                Text(
                  _somaAlimentos() == null
                      ? 'Texto da médica, sem calcular nutrientes ou inventar porções. Confira os horários e as condições de dispensa antes de exportar.'
                      : 'Texto da médica e alimentos lidos da linha Alimentos, com nutrientes da tabela TACO. A paciente pode trocar cada alimento por outro do mesmo grupo. Confira os horários e as condições de dispensa antes de exportar.',
                ),
                const SizedBox(height: 12),
                for (final meal in r.lista('refeicoes')) ...[
                  Text(
                    meal['titulo'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'No PDF: ${meal['referencia']}',
                    style: const TextStyle(color: apoio),
                  ),
                  _campo(
                    meal,
                    'horario',
                    'Horário de ${meal['titulo']}',
                    ajuda: 'HH:MM. Confirme antes de usar como lembrete.',
                  ),
                  if (padronizado) ...[
                    DropdownButtonFormField<String>(
                      initialValue: meal['regra'] as String,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Regra da refeição',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'obrigatoria',
                          child: Text('Obrigatória'),
                        ),
                        DropdownMenuItem(
                          value: 'condicional',
                          child: Text('Condicional'),
                        ),
                      ],
                      onChanged: (v) => _alterar(() => meal['regra'] = v),
                    ),
                    const SizedBox(height: 14),
                    _campo(
                      meal,
                      'condicao',
                      'Condição para dispensar',
                      lines: 2,
                      ajuda:
                          'Obrigatória: NAO SE APLICA. Condicional: informe a exceção autorizada pela médica.',
                    ),
                  ],
                  _campo(
                    meal,
                    'descricao',
                    'Prescrição de ${meal['titulo']}',
                    lines: 3,
                  ),
                  if (meal['alimentos'] != null) ...[
                    Text(
                      'Alimentos',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final i in validarAlimentos(meal['alimentos']))
                      Text(
                        '${i.alimento.nome}: ${_numeroMacro(i.gramas)} g · ${_numeroMacro(i.nutrientes.kcal.round())} kcal',
                      ),
                    Text(
                      'Total: ${_numeroMacro(somarAlimentos(validarAlimentos(meal['alimentos'])).kcal.round())} kcal.',
                      style: const TextStyle(color: apoio),
                    ),
                  ],
                  if (padronizado && r.data['alimentacao'] == null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: saving ? null : () => _editarAlimentos(meal),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(
                          meal['alimentos'] == null
                              ? 'Incluir alimentos de ${meal['titulo']}'
                              : 'Editar alimentos de ${meal['titulo']}',
                        ),
                      ),
                    ),
                  const Divider(),
                ],
                _campo(
                  c,
                  'link',
                  'Link pessoal do Monte seu prato',
                  lines: 2,
                  ajuda:
                      'Endereço completo do campo Link pessoal do PDF. Não foi aberto nem sincronizado com o site.',
                ),
              ]),
              _bloco('Envio e textos de referência', [
                DropdownButtonFormField<String>(
                  initialValue: c['envioDia'] == ''
                      ? null
                      : c['envioDia'] as String,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Dia do envio'),
                  items: [
                    for (var i = 0; i < _diasSemana.length; i++)
                      DropdownMenuItem(
                        value: '$i',
                        child: Text(_diasSemana[i]),
                      ),
                  ],
                  onChanged: (v) => _alterar(() => c['envioDia'] = v ?? ''),
                ),
                const SizedBox(height: 14),
                _campo(
                  c,
                  'envioHora',
                  'Horário-limite do envio',
                  ajuda:
                      'HH:MM. Nesta etapa não é agendada nenhuma notificação.',
                ),
                for (final section in r.lista('secoes'))
                  ExpansionTile(
                    title: Text(section['titulo'] as String),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(section['texto'] as String),
                      ),
                    ],
                  ),
              ]),
              _bloco(
                'Pendências para decisão (${r.lista('pendencias').length})',
                [
                  if (r.lista('pendencias').isEmpty)
                    const Text(
                      'Sem pendências adicionais de importação. Ao concluir, o aplicativo valida os campos do padrão. Ele não verifica contradições clínicas nos textos livres; a conferência continua obrigatória.',
                    ),
                  for (final issue in r.lista('pendencias')) ...[
                    Text(
                      issue['titulo'] as String,
                      style: const TextStyle(
                        color: alerta,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(issue['detalhe'] as String),
                    _origem(issue['origem'] as String),
                    _campo(
                      r.data['decisoes'] as Map<String, dynamic>,
                      issue['id'] as String,
                      'Decisão: ${issue['titulo']}',
                      lines: 2,
                      ajuda:
                          'Registre a regra aprovada e ajuste os campos correspondentes acima. O PDF original permanece intacto.',
                    ),
                  ],
                ],
                aberto: true,
              ),
              if (padronizado) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.restaurant_outlined),
                    title: const Text('Rotina alimentar e metas de macro'),
                    subtitle: Text(_resumoAlimentacao()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: saving ? null : _editarAlimentacao,
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_repeat_outlined),
                    title: const Text('Reavaliação'),
                    subtitle: Text(
                      _resumoPedidoReavaliacao(r.data['reavaliacao']),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: saving ? null : _editarReavaliacao,
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.fitness_center_outlined),
                    title: const Text('Treino'),
                    subtitle: Text(_resumoTreino()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: saving ? null : _editarTreino,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (final entry in {
                'identidade':
                    'Conferi o destinatário, o nome completo e o nascimento.',
                'periodo':
                    'Conferi o período, retorno, envio e horários propostos.',
                'conteudo':
                    'Conferi a fidelidade das metas, refeições e textos e registrei as decisões necessárias.',
              }.entries)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: checks[entry.key] == true,
                  title: Text(entry.value),
                  onChanged: (v) => _alterar(
                    () => checks[entry.key] = v == true,
                    confirmacao: true,
                  ),
                ),
              const Text(
                'Depois de alterar campos, confirme novamente os três itens. Rascunhos ficam somente neste aparelho e contêm dados de saúde.',
                style: TextStyle(color: apoio),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: saving ? null : () => _salvar(),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar rascunho com pendências'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: saving ? null : () => _salvar(concluir: true),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(saving ? 'Salvando…' : 'Concluir conferência'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed:
                    saving || dirty || r.estado != 'conferido' || !padronizado
                    ? null
                    : () => _exportarConferido(previa: true),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Prévia do paciente'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed:
                    saving || dirty || r.estado != 'conferido' || !padronizado
                    ? null
                    : () => _exportarConferido(),
                icon: const Icon(Icons.ios_share),
                label: const Text('Exportar .plano conferido'),
              ),
              const Text(
                'A exportação preserva os IDs para atualizar o mesmo acompanhamento sem apagar suas marcações. Uma alteração exige concluir a conferência novamente.',
                style: TextStyle(color: apoio),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfOriginalRascunhoPage extends StatefulWidget {
  const _PdfOriginalRascunhoPage({required this.bytes});
  final Uint8List bytes;
  @override
  State<_PdfOriginalRascunhoPage> createState() =>
      _PdfOriginalRascunhoPageState();
}

class _PdfOriginalRascunhoPageState extends State<_PdfOriginalRascunhoPage> {
  late final controller = PdfControllerPinch(
    document: PdfDocument.openData(widget.bytes),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PDF original')),
    body: PdfViewPinch(controller: controller),
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
