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
| `metasMacro` | opcional, só v4 e sem `alimentacao`; `{kcal, proteina, carboidrato, gordura, fibra?}` vindas do PDF, ver `padrao-pdf-v1.md` |
| `reavaliacao` | opcional; `{itens, datas}` pedido pela médica, ver "Pré-consulta e reavaliação" |

`criadoEm` é escrito pelo editor, mas não recebe validação específica. IDs dos campos devem ser únicos entre metas/anotações. Tipos: checklist (`itens` strings), contador (`alvo` >= 0 e `unidade`), sim_nao, texto e escala (`min` <= `max`). Horários de lembretes em HH:MM.

V1 pode não ter nascimento; nesse caso importação pelo paciente solicita arquivo atualizado. V2 exige nascimento no parser. **V3 só valida nascimento quando presente**, uma inconsistência a corrigir; editor exige o campo e conferência do destinatário bloqueia ausência. Não depender da permissividade do parser.

O editor manual continua criando v3. `_exportarPlano` agora preserva a versão recebida, sem forçar v2: a exportação real da interface manual é testada como v3 e a conferida como v4.

## Plano conferido v4

`planoDoPdfConferido` em `core/exportacao_pdf.dart` exige padrão PLANO-CUIDADO/1, estado conferido, validação e três confirmações, além de nome/registro profissional configurados. `id` é o do rascunho, e IDs das metas/refeições são mantidos. Reexportar não cria novo acompanhamento. Novo paciente/ciclo exige novo PDF; duplicação pelo editor manual é bloqueada para v4.

V4 exige nascimento, `fim` e `linkMonteSeuPrato` (string vazia quando não houver link). O link, quando presente, deve ser completo com https e fragmento #p=. `origemPdf` preserva padrão de entrada, consulta e emissão; `pdf` é o original, sem reescrita pelas correções da interface. Nome/registro identificam o perfil informado, **não uma assinatura digital ou autenticação da profissional**.

Metas de refeições usam tipo `refeicoes`, disponível somente em v4: título, orientação e lembretes são preservados, mas esse grupo não gera registro duplicado. Metas de contagem e confirmação diária conservam tipos `contador` e `sim_nao`. Contagem v4 preserva distribuição LIVRE ou parcelas HH:MM=quantidade, com soma validada contra o alvo, separada dos lembretes. `controleConfirmacao` permite distinguir ausência de registro na apresentação.

`refeicoesPrescritas` é uma lista de até oito itens com id, titulo, horario HH:MM, regra (`obrigatoria`/`condicional`), condicao e descricao da prescrição. IDs são únicos também em relação a metas/anotações; nomes de refeições não repetem. Condicional exige condição expressa; obrigatória usa NAO SE APLICA. Esse bloco não pode coexistir com o bloco alimentar nutricional `alimentacao`. Cada refeição pode ter `alimentos`: lista de 1 a 15 `{id, nome, grupo, gramas, por100: {kcal, proteina, carboidrato, gordura, fibra}}`, sem repetir `id`, gramas de 1 a 2000 e grupo entre `carboidrato`, `leguminosa`, `fruta`, `proteina`, `laticinio`, `gordura`, `doce`, `bebida`, `preparado`, `livre` (`lib/core/alimentos.dart`). A composição viaja no plano para não depender da tabela do aparelho. Na aba Alimentação a paciente troca um alimento por outro do mesmo grupo só naquele dia; a quantidade mantém o macro principal do grupo (carboidrato, proteína, gordura; calorias em doces, bebidas e pratos prontos; mesmas gramas em `livre`), arredondada a 5 g. As trocas ficam em `config` `alimentos_trocas_<planoId>_<dia>` (entram no backup) e não alteram o plano. Na troca, opções ultraprocessadas/fritas ou com 25% a mais de calorias (+10 kcal) ficam em "Menos indicadas" e, ao escolher uma delas, o app mostra até três trocas melhores (mais fibra, menos calorias). A devolução de acompanhamento leva em `comido` o que a paciente comeu: `{dia: {refeicaoId: {alimentos, trocas}}}` só para refeições com alimentos marcadas como feitas, com as trocas do dia aplicadas e `trocas` com as posições trocadas. Clientes antigos ignoram `alimentos`.

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

## Pré-consulta e reavaliação

Envelopes enviados pela paciente à profissional, `.plano`, **não são prescrição** (`core/pre_consulta.dart`). Todos têm `id` aleatório de 32 hexadecimais, `criadoEm` ISO (até 1 dia no futuro, tolerância de relógio) e `paciente` `{nome, nascimento}` com nome completo. Parser estrito: chaves fora do contrato, opções fora das listas, escalas fora da faixa e tipos errados são recusados.

- **Pré-consulta** — `formato: plano-de-cuidado-pre-consulta`, `versao: 1`, até 1 MB, sem fotos. `termo` `{versao, aceitoEm}`; versão aceita: `20/09/2026, rev. 2`; aceite não pode ser posterior a `criadoEm`. `respostas`: `ident` (CPF `000.000.000-00` ou vazio, sexo `F`/`M`/null, e-mail, nome da mãe, CEP `00000-000` ou vazio, endereço), `saude` (condições e história familiar das listas fixas, detalhes só de itens marcados; SOP só com sexo F), `medidas`, `alimentacao.emocional` (0–10), `sono`, `emocional`, `habitos` (álcool AUDIT-C item 1, índice 0–4; cigarro; apoio 0–10), `hormonal` (só preenchida com sexo F).
- **Reavaliação** — `formato: plano-de-cuidado-reavaliacao`, `versao: 1`, até 256 KB. `planoId`, `itens` (subconjunto não vazio e sem repetição de `medidas`, `sono`, `humor`) e `respostas` exatamente com as seções pedidas (`humor` → `emocional`).
- Seções comuns: `medidas` `{peso 20–400 kg, altura 80–250 cm, cintura 30–300 cm, quadril 30–300 cm}`, cada uma número ou null. `sono` `{horas 0–24, restaurador, acordaNoite, acordaVezes 0–50, acordaMotivo, ronco, pausas}`; vezes e motivo só com `acordaNoite: "Sim"`. `emocional` `{phq2: [2], gad2: [2]}`, cada item 0–3 ou null.

IMC (1 casa) e relação cintura-quadril (2 casas) são calculados na leitura, **só como número, sem classificação**. PHQ-2 e GAD-2 ficam como respostas, sem soma. 

**Pedido de reavaliação no `.plano`** — campo opcional `reavaliacao: {itens, datas}`, em qualquer versão do plano. `itens` segue a regra do envelope; `datas` tem de 1 a 12 dias `AAAA-MM-DD`, em ordem crescente, sem repetir, entre `inicio` e `retorno.data`. Chaves fora disso são recusadas. Sem o campo, a paciente não vê nada de reavaliação. Com ele, aparece o cartão **Reavaliação** em Hoje (e em Ajustes) e um lembrete local às 9h de cada data; datas até o último envio (config `reavaliacao_enviada_<planoId>`) não geram lembrete. A resposta é o envelope de reavaliação acima, com o `planoId` do plano. Clientes antigos ignoram o campo.

## Backup

`.plano-backup` é JSON com `formato: "plano-de-cuidado-backup"`, `versao: 1`, planos/registros/envios e config. Chaves opcionais `pacientes`, `preConsultas` e `reavaliacoes` trazem o histórico da profissional; cópias antigas sem elas restauram com histórico vazio. A chave opcional `rascunhosPdf` traz os rascunhos de PDF (inclusive conferidos, de onde sai o `.plano` v4); restaurar grava os da cópia e mantém os do aparelho. Cópia sem a chave não mexe nos rascunhos. Um rascunho danificado impede toda a restauração. Cada pré-consulta/reavaliação é revalidada e precisa corresponder ao paciente da cópia, senão nada é restaurado. Não confundir versão do backup com versão SQLite ou `.plano`. Restauração substitui o banco em transação e rejeita cadastro de outro paciente quando já há cadastro local.

Arquivos são legíveis e não criptografados. O anexo base64 não é proteção. Compatibilidade, migração e destinatário devem ser verificados antes de alterar o contrato.
