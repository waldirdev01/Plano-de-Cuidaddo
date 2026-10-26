# Contrato dos arquivos

Fonte executável: `Plano.parse`/`parseBytes` em `lib/core/plano.dart` e `AlimentacaoPlano.fromMap` em `lib/core/alimentacao.dart`. Este documento descreve o código atual; não é um schema formal.

## `.plano`

JSON UTF-8 com `formato: "plano-de-cuidado"` e `versao` inteira **1, 2, 3 ou 4**. Versão maior é recusada pedindo atualização. PDF ou bytes inválidos são recusados antes de gravar. O formato 4 é a saída da conferência PDF; clientes anteriores que aceitam até 3 recusam esse arquivo em vez de ignorar sua semântica.

| Campo | Regra atual |
| --- | --- |
| `id` | string não vazia; estável ao editar/reimportar, novo ao duplicar |
| `paciente` | `nome` não vazio; `nascimento` em `AAAA-MM-DD` para conferência |
| `profissional` | nome e registro não vazios |
| `inicio` | data civil `AAAA-MM-DD` |
| `fim` | obrigatório em v4: último dia de registro, início <= fim <= retorno; versões antigas usam retorno como limite |
| `retorno` | objeto com `data` obrigatória >= início; `hora` opcional HH:MM |
| `metas`, `camposDiarios` | listas de campos, ausência tratada como lista vazia |
| `secoes` | lista com título/texto; destaque opcional |
| `envioSemanal` | opcional: diaDaSemana 0=domingo até 6=sábado, ate HH:MM |
| `pdf` | opcional: nome e base64; bytes começam com `%PDF-` |
| `alimentacao` | opcional; validado pelo modelo alimentar |
| `treino` | opcional; parâmetros clínicos do treino, ver [treino.md](treino.md) |

`criadoEm` é escrito pelo editor, mas não recebe validação específica. IDs dos campos devem ser únicos entre metas/anotações. Tipos: checklist (`itens` strings), contador (`alvo` >= 0 e `unidade`), sim_nao, texto e escala (`min` <= `max`). Horários de lembretes em HH:MM.

V1 pode não ter nascimento; nesse caso importação pelo paciente solicita arquivo atualizado. V2 exige nascimento no parser. **V3 só valida nascimento quando presente**, uma inconsistência a corrigir; editor exige o campo e conferência do destinatário bloqueia ausência. Não depender da permissividade do parser.

O editor manual continua criando v3. `_exportarPlano` agora preserva a versão recebida, sem forçar v2: a exportação real da interface manual é testada como v3 e a conferida como v4.

## Plano conferido v4

`planoDoPdfConferido` em `core/exportacao_pdf.dart` exige padrão PLANO-CUIDADO/1, estado conferido, validação e três confirmações, além de nome/registro profissional configurados. `id` é o do rascunho, e IDs das metas/refeições são mantidos. Reexportar não cria novo acompanhamento. Novo paciente/ciclo exige novo PDF; duplicação pelo editor manual é bloqueada para v4.

V4 exige nascimento, `fim` e `linkMonteSeuPrato` (string vazia quando não houver link). O link, quando presente, deve ser completo com https e fragmento #p=. `origemPdf` preserva padrão de entrada, consulta e emissão; `pdf` é o original, sem reescrita pelas correções da interface. Nome/registro identificam o perfil informado, **não uma assinatura digital ou autenticação da profissional**.

Metas de refeições usam tipo `refeicoes`, disponível somente em v4: título, orientação e lembretes são preservados, mas esse grupo não gera registro duplicado. Metas de contagem e confirmação diária conservam tipos `contador` e `sim_nao`. Contagem v4 preserva distribuição LIVRE ou parcelas HH:MM=quantidade, com soma validada contra o alvo, separada dos lembretes. `controleConfirmacao` permite distinguir ausência de registro na apresentação.

`refeicoesPrescritas` é uma lista de até oito itens com id, titulo, horario HH:MM, regra (`obrigatoria`/`condicional`), condicao e descricao da prescrição. IDs são únicos também em relação a metas/anotações; nomes de refeições não repetem. Condicional exige condição expressa; obrigatória usa NAO SE APLICA. Esse bloco não contém nutrientes ou equivalências e não pode coexistir com o bloco alimentar nutricional `alimentacao`.

O paciente registra por ID da refeição os valores `feito`, `nao_feito` ou `dispensado` (este último só é oferecido às condicionais). Ausência continua ausência, exibida como Não confirmado, não uma declaração de não execução. Na tabela, dias futuros mostram traço e não permitem edição. Reimportação preserva marcações, inclusive dispensa anterior quando a regra é alterada; a interface identifica esse caso como regra anterior.

Hoje, rotina, semana, imagem semanal e lembretes usam o período até `fim`. Retorno mantém data e aviso próprios. Refeições têm avisos no horário prescrito; quantidade de copos/distribuição não gera avisos implícitos. Prévia não grava marcações. SQLite e backup permanecem nas versões anteriores: o JSON do plano v4 cabe na estrutura existente e os registros usam as mesmas chaves.

## Alimentação

### Arquivo de devolução do paciente

Usa `.plano` para aproveitar o recebimento iOS existente, mas **não é uma prescrição**: `formato: plano-de-cuidado-acompanhamento`, `versao: 1`. Campos: `id` aleatório de 32 hexadecimais, `exportadoEm` ISO, `de` e `ate` civis, `plano` (snapshot validado v4) e `registros` (mapa AAAA-MM-DD → ID campo → valor). `de` é início do plano, `ate` está entre início e min(hoje,fim), nunca posterior ao dia declarado da exportação. Limite de 5 MB e 3661 dias. O parser de prescrição recusa este envelope e vice-versa; versões futuras exigem atualização.

Em `plano`, exportador remove PDF, seções clínicas livres e link pessoal. Mantém identidade/destinatária, IDs, regras e descrição das tarefas necessárias à leitura. V4 continua exigindo `linkMonteSeuPrato`, exportado vazio aqui. O cadastro do paciente é conferido antes de preparar e compartilhar. Recebedora exige modo profissional, nome e registro correspondentes ao envelope. São conferências de correspondência, **não autenticação ou assinatura**.

Valores: refeições `feito/nao_feito/dispensado`; confirmação booleano; contador número finito >=0; escala finita no intervalo; texto até 20 mil caracteres; checklist com itens existentes. `null`/ausência significa não confirmado; zero é valor informado, não ausência. Dispensa preservada em tarefa cuja regra mudou é exibida como regra anterior. Datas futuras/fora do período, campos desconhecidos e tipos inválidos são recusados ao receber. Exportação exclui registros fora do intervalo e campos já removidos do plano, sem apagar o histórico local. Não inclui horário de cada marcação, somente o estado final por dia e a data declarada de exportação.

Todo novo envio é cumulativo e tem novo ID. Arquivos anteriores permanecem; não há soma, sobrescrita ou comparação automática de versões. Reabrir o mesmo ID/conteúdo não duplica; mesmo ID com conteúdo divergente é recusado. Dados legíveis sem senha; compartilhar apenas com a destinatária correta. Não usar backup no lugar do arquivo de acompanhamento.

Metas `kcal`, `proteina`, `carboidrato`, `gordura`, `fibra`: números finitos não negativos. Refeições têm ID/título/opções e horário opcional. Opções têm ID, nome, grupo, porção positiva/unidade, nutrientes e classificação textual da profissional. Valores de nutrientes são **da porção definida**, não automaticamente por 100 g.

`rotina.padrao` mapeia refeição para opção; `rotina.dias[AAAA-MM-DD]` sobrepõe o padrão para data específica. Substituições locais sobrepõem ambos. A soma usa somente opções válidas selecionadas; refeições sem seleção não entram no total. Não existe classificação nutricional automática nem geração de cardápio por IA.

Veja `rotina-alimentar-v3.md` e `exemplos/plano-alimentar-teste-v3.plano`. A validação de rotina diária e tipos opcionais ainda precisa ser endurecida (ver continuidade).

## Backup

`.plano-backup` é JSON com `formato: "plano-de-cuidado-backup"`, `versao: 1`, planos/registros/envios e config. Não confundir versão do backup com versão SQLite ou `.plano`. Restauração substitui o banco em transação e rejeita cadastro de outro paciente quando já há cadastro local.

Arquivos são legíveis e não criptografados. O anexo base64 não é proteção. Compatibilidade, migração e destinatário devem ser verificados antes de alterar o contrato.
