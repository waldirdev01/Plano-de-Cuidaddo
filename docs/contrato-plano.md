# Contrato dos arquivos

Fonte executável: `Plano.parse`/`parseBytes` em `lib/core/plano.dart` e `AlimentacaoPlano.fromMap` em `lib/core/alimentacao.dart`. Este documento descreve o código atual; não é um schema formal.

## `.plano`

JSON UTF-8 com `formato: "plano-de-cuidado"` e `versao` inteira **1, 2 ou 3**. Versão maior é recusada pedindo atualização. PDF ou bytes inválidos são recusados antes de gravar.

| Campo | Regra atual |
| --- | --- |
| `id` | string não vazia; estável ao editar/reimportar, novo ao duplicar |
| `paciente` | `nome` não vazio; `nascimento` em `AAAA-MM-DD` para conferência |
| `profissional` | nome e registro não vazios |
| `inicio` | data civil `AAAA-MM-DD` |
| `retorno` | objeto com `data` obrigatória >= início; `hora` opcional HH:MM |
| `metas`, `camposDiarios` | listas de campos, ausência tratada como lista vazia |
| `secoes` | lista com título/texto; destaque opcional |
| `envioSemanal` | opcional: diaDaSemana 0=domingo até 6=sábado, ate HH:MM |
| `pdf` | opcional: nome e base64; bytes começam com `%PDF-` |
| `alimentacao` | opcional; validado pelo modelo alimentar |

`criadoEm` é escrito pelo editor, mas não recebe validação específica. IDs dos campos devem ser únicos entre metas/anotações. Tipos: checklist (`itens` strings), contador (`alvo` >= 0 e `unidade`), sim_nao, texto e escala (`min` <= `max`). Horários de lembretes em HH:MM.

V1 pode não ter nascimento; nesse caso importação pelo paciente solicita arquivo atualizado. V2 exige nascimento no parser. **V3 só valida nascimento quando presente**, uma inconsistência a corrigir; editor exige o campo e conferência do destinatário bloqueia ausência. Não depender da permissividade do parser.

**Outro ponto pendente:** `novoPlano`, duplicação e salvamento escrevem v3, mas `_exportarPlano` em `ui/profissional.dart` força v2, inclusive quando há alimentação. Parser atual aceita alimentação também sob v2. Não assumir que exports da interface são v3 até corrigir e testar esse caminho.

## Alimentação

Metas `kcal`, `proteina`, `carboidrato`, `gordura`, `fibra`: números finitos não negativos. Refeições têm ID/título/opções e horário opcional. Opções têm ID, nome, grupo, porção positiva/unidade, nutrientes e classificação textual da profissional. Valores de nutrientes são **da porção definida**, não automaticamente por 100 g.

`rotina.padrao` mapeia refeição para opção; `rotina.dias[AAAA-MM-DD]` sobrepõe o padrão para data específica. Substituições locais sobrepõem ambos. A soma usa somente opções válidas selecionadas; refeições sem seleção não entram no total. Não existe classificação nutricional automática nem geração de cardápio por IA.

Veja `rotina-alimentar-v3.md` e `exemplos/plano-alimentar-teste-v3.plano`. A validação de rotina diária e tipos opcionais ainda precisa ser endurecida (ver continuidade).

## Backup

`.plano-backup` é JSON com `formato: "plano-de-cuidado-backup"`, `versao: 1`, planos/registros/envios e config. Não confundir versão do backup com versão SQLite ou `.plano`. Restauração substitui o banco em transação e rejeita cadastro de outro paciente quando já há cadastro local.

Arquivos são legíveis e não criptografados. O anexo base64 não é proteção. Compatibilidade, migração e destinatário devem ser verificados antes de alterar o contrato.
