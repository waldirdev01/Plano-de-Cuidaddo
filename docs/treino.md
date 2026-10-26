# Treino no Plano de Cuidado

Estado: **código escrito e não compilado nem testado em Flutter** (24–25/10/2026). O motor foi validado antes em JavaScript (21.600 combinações) e traduzido para Dart; a sintaxe foi conferida com um analisador, mas `flutter analyze` e `flutter test` ainda precisam rodar. Veja "Antes de usar".

## O que é

Aba **Treino** para o paciente, com programa de 4 semanas calculado no aparelho por regras fixas (sem IA, sem rede) e registro do que foi feito. A médica ativa o treino por plano; o paciente escolhe só a logística.

## Contrato

Bloco opcional `treino` no `.plano` (v3 ou v4; o parser de versões antigas ignora o bloco):

| Campo | Regra |
| --- | --- |
| `nivel` | 1 iniciante, 2 intermediário, 3 avançado |
| `objetivo` | `perda`, `recomp`, `saude` ou `manut` |
| `limitacoes` | opcional; subconjunto único de `j` joelho, `o` ombro, `l` lombar |
| `posParto` | opcional, booleano |
| `triagemNegativa` | **obrigatório `true`**: a profissional confirma a triagem de segurança |
| `liberacaoPosParto` | obrigatório `true` quando `posParto` é `true` |

`Plano.parse` recusa o arquivo se a triagem ou a liberação faltarem. O bloco não guarda local, dias ou tempo: o paciente escolhe na aba e a escolha fica em `config` (`treino_escolhas_<planoId>`), incluída no backup.

## Registros

Usam a tabela `registros` existente, na data do treino:

- `trn_<slug-do-exercicio>`: `{nome, series:[{f, r, k}], sobraram?}` (f = feita, r = repetições ou segundos, k = carga em kg).
- `trn_aerobico`: `{feito, min}`.

Esses campos **não entram** em `camposRegistraveis`; Hoje, Semana e a imagem semanal não os leem.

## Devolução

O envelope `plano-de-cuidado-acompanhamento` v1 ganha a chave opcional `treino` (data → campo → valor). Só é criada quando o plano tem treino; o recebimento valida datas, nomes de campo `trn_*` e a forma dos valores, e recusa `treino` em plano sem treino. A tela de acompanhamento da médica mostra o treino de cada dia. Receptores antigos ignoram a chave.

Limite herdado: a devolução só existe para planos **v4** (conferidos por PDF). Plano manual v3 mostra o treino e registra, mas não devolve.

Onde a médica inclui o treino: no plano manual, botão **Treino** do cartão em Meus planos; no PDF, cartão **Treino** da tela de conferência (Rascunhos de PDF). No PDF, o bloco fica no rascunho, a alteração desfaz as confirmações como qualquer outra edição e `planoDoPdfConferido` copia o bloco para o `.plano` v4. Assim o plano conferido nunca muda sem nova conferência.

## Regras do motor (`lib/core/treino.dart`)

- Força: multiarticulares primeiro; unilateral nunca em bi-set; bi-set só empurrar com puxar e só com sessão de até 30 min; 48–72 h entre treinos de pernas; core com isometria e sem abdominal tradicional.
- Sem séries até a falha: o esforço é dado em repetições na reserva.
- Aeróbico: 150 a 300 min/semana (OMS 2020); HIIT só no nível intermediário (a partir da semana 3) e avançado (a partir da semana 2), nunca no iniciante, no pós-parto nem em casa com limitação de joelho.
- Sugestão de carga: sobe 2–5% (arredonda a 0,5 kg) se todas as séries chegaram ao topo da faixa; desce cerca de 7% se alguma série ficou abaixo da faixa ou se o paciente foi até a falha; mantém no meio da faixa.
- **Os parâmetros de séries, repetições, progressão e percentuais de ajuste são regras propostas e ainda não foram conferidas no OpenEvidence.** A médica deve revisar antes do uso com pacientes.

## Antes de usar

1. `flutter pub get && flutter analyze && flutter test` (inclui `test/treino_test.dart`).
2. Corrigir o que o compilador apontar; o código novo não foi compilado.
3. No iPhone: criar plano com treino (Profissional > Treino), exportar, importar como paciente, registrar séries, usar Marcar treino todo feito, exportar acompanhamento e abrir no modo profissional.
4. Conferir as regras com a médica e no OpenEvidence.

## Regulatório e LGPD

- Dados de saúde legíveis, sem criptografia nova, como no restante do app.
- Triagem negativa e liberação no pós-parto são declaradas pela médica; o app não faz triagem.
- Não divulgar o treino como prescrição de exercício por profissional de educação física: é orientação médica genérica, com a frase fixa de acompanhamento profissional.
