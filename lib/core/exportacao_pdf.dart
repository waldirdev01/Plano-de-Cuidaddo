import 'dart:convert';

import 'edicao_plano.dart';
import 'importacao_pdf.dart';
import 'padrao_pdf.dart';
import 'plano.dart';

/// A reviewed draft becomes a patient document only through this conversion.
/// Stable draft/field IDs are retained on every export and reimport.
Plano planoDoPdfConferido(
  RascunhoPdf r, {
  required String profissional,
  required String registro,
}) {
  if (r.data['padraoPdf'] != PadraoPdf.versao) {
    throw const FormatException(
      'Use um rascunho do modelo PLANO-CUIDADO/1 para exportar.',
    );
  }
  if (r.estado != 'conferido' || r.validarConferencia().isNotEmpty) {
    throw const FormatException(
      'Conclua e salve a conferência antes de exportar. Se houve alteração, confira novamente.',
    );
  }
  if (profissional.trim().isEmpty || registro.trim().isEmpty) {
    throw const FormatException(
      'Complete o nome e o registro no perfil profissional antes de exportar.',
    );
  }
  final c = r.campos;
  final metas = <Map<String, dynamic>>[
    for (final m in r.lista('metas'))
      {
        'id': m['id'],
        'titulo': m['titulo'],
        'descricao': m['descricao'],
        'controleConfirmacao': true,
        'tipo': m['tipo'] == 'checklist' ? 'refeicoes' : m['tipo'],
        'lembretes': (m['horarios'] as String).trim().isEmpty
            ? <String>[]
            : (m['horarios'] as String)
                  .split(',')
                  .map((s) => s.trim())
                  .toList(),
        if (m['tipo'] == 'contador') ...{
          'alvo': num.parse((m['alvo'] as String).replaceAll(',', '.')),
          'unidade': m['unidade'],
          'distribuicao': m['distribuicao'],
        },
      },
  ];
  final dados = <String, dynamic>{
    'formato': 'plano-de-cuidado',
    'versao': 4,
    'id': r.id,
    'criadoEm': r.data['criadoEm'] ?? r.data['atualizadoEm'],
    'profissional': {'nome': profissional.trim(), 'registro': registro.trim()},
    'paciente': {'nome': c['nome'], 'nascimento': c['nascimento']},
    'inicio': c['inicio'],
    'fim': c['fim'],
    'retorno': {'data': c['retorno'], 'hora': c['horaRetorno']},
    'envioSemanal': {
      'diaDaSemana': int.parse(c['envioDia'] as String),
      'ate': c['envioHora'],
    },
    'metas': metas,
    'camposDiarios': <Map<String, dynamic>>[],
    'refeicoesPrescritas': [
      for (final m in r.lista('refeicoes'))
        {
          'id': m['id'],
          'titulo': m['titulo'],
          'horario': m['horario'],
          'regra': m['regra'],
          'condicao': m['condicao'],
          'descricao': m['descricao'],
        },
    ],
    'linkMonteSeuPrato': c['link'],
    'secoes': copiarDados({'s': r.lista('secoes')})['s'],
    'pdf': copiarDados(r.data['pdf'] as Map<String, dynamic>),
    'origemPdf': {
      'padrao': PadraoPdf.versao,
      'consulta': c['consulta'],
      'emissao': c['emissao'],
    },
  };
  return Plano.parse(jsonEncode(dados));
}
