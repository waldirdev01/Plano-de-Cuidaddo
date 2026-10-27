# Pré-consulta no app e histórico de pacientes — plano

Estado: **etapa 1 implementada (27/10/2026)**: envelopes, banco local e backup, com testes; sem telas. Decisões da médica registradas em 27/10/2026. Origem: formulário web de pré-consulta da médica (artifact "Pré-Consulta — Consultório Priscila Carvalho", termo versão 20/09/2026 rev. 2).

## Decisões do responsável

- Os dados ficam **somente no app, em banco local** (SQLite já existente). Sem servidor, sem nuvem, sem login.
- O site fica como **porta de entrada** (divulgação, Monte seu prato, link para instalar o app). A pré-consulta passa a ser preenchida no app.
- A pré-consulta chega à médica como **arquivo para o app**, aberto no modo profissional, como a devolução de acompanhamento.
- **Sem fotos** na primeira versão.
- A médica quer **histórico da paciente**: tudo de uma mesma pessoa reunido no celular dela, sem precisar colar nada em outro lugar.

## Respostas da médica às perguntas em aberto (27/10/2026)

1. **Termo: manter o texto atual por enquanto** (versão 20/09/2026, rev. 2). O texto fala em envio por WhatsApp/e-mail e em leitura por pessoa de apoio; no app o arquivo vai por onde a paciente escolher e fica no celular da médica. **Descompasso conhecido:** o termo ainda não foi revisado por advogado e não descreve o fluxo do app. Resolver antes de qualquer paciente real usar a pré-consulta no app.
2. **Cálculos na ficha: IMC e relação cintura-quadril.** Só o número, sem classificar ("normal", "alterado"). PHQ-2 e GAD-2 continuam como respostas cruas, sem soma nem rastreio automático. Nenhuma interpretação clínica automática.
3. **Reavaliação: depende da paciente.** A médica liga a reavaliação paciente a paciente, no plano (ver "Reavaliação" abaixo). Quem não tem a opção ligada não vê nada de reavaliação.
4. **Distribuição: ainda não decidida.** Hoje o app está em TestFlight; pacientes reais em escala pedem publicação na App Store. Até a decisão, o formulário web atual continua sendo a pré-consulta. Não bloqueia o desenvolvimento.

## Fluxo

1. Paciente instala o app, faz o cadastro (nome e nascimento, como hoje) e abre **Pré-consulta**. Disponível sem plano importado.
2. Preenche as etapas; o rascunho fica salvo no aparelho e pode ser retomado.
3. Revisão → **Exportar pré-consulta** → arquivo `pre-consulta-<nome>-<data>.plano` pela folha de compartilhamento (WhatsApp, e-mail, AirDrop). Mesma regra da devolução: salvar em Arquivos não é enviar; só registra envio após declaração explícita. Depois, opção de apagar as respostas do aparelho.
4. Médica: Meus planos → **Pacientes** → Abrir pré-consulta `.plano` → confere nome e nascimento → recebe. A pré-consulta entra na ficha da paciente.

## Conteúdo (igual ao formulário web)

| Etapa | Campos |
| --- | --- |
| Antes de começar | Termo de consentimento versionado; aceite obrigatório, com data/hora e versão |
| Você | Nome, CPF (máscara), nascimento, sexo (F/M), e-mail, nome da mãe, CEP, endereço completo |
| Sua saúde até hoje | 13 condições (+ SOP se sexo F) com detalhe por item; outras; cirurgias; alergia a remédio; história familiar (4 itens com detalhe) |
| Suas medidas | Peso, altura, cintura, quadril, com instrução de medida e link do vídeo |
| Hábitos | Comer emocional 0–10; álcool (AUDIT-C item 1, 5 opções); cigarro (3 opções); apoio 0–10 |
| Sono e humor | Horas; sono restaurador; acorda à noite (vezes, motivo); ronco; pausas; PHQ-2 e GAD-2 (Likert 0–3); quadro fixo CVV 188 / SAMU 192 |
| Saúde hormonal (só sexo F) | Última menstruação, ciclo, menopausa, hormônio/anticoncepcional |
| Revisar e enviar | Resumo e exportação |

Respostas guardadas cruas, como no web. **Na ficha, a médica vê IMC e relação cintura-quadril calculados a partir das medidas, só como número.** PHQ-2 e GAD-2 aparecem como respostas, sem soma.

## Reavaliação (decidida em 27/10/2026)

Para as pacientes que a médica escolher, a paciente repete um formulário curto no app, e a médica vê a evolução na ficha.

- **A médica liga a opção por paciente, ao criar ou renovar o plano.** O pedido viaja dentro do próprio arquivo `.plano` que ela já envia, sem canal novo. Proposta de campo: `reavaliacao: { itens: [medidas | sono | humor], datas: [AAAA-MM-DD, ...] }`. Sem o campo, o app da paciente não mostra reavaliação.
- **A médica marca os dias.** O app da paciente agenda um lembrete local em cada data. Depende de a paciente permitir notificações; sem permissão, o botão "Reavaliação" continua disponível no app, só sem aviso.
- A paciente preenche os itens pedidos e exporta `reavaliacao-<nome>-<data>.plano` (envelope `formato: "plano-de-cuidado-reavaliacao"`, `versao: 1`, mesma regra de declaração de envio). A médica abre em Pacientes e o resultado entra na ficha em ordem de data, com IMC e relação cintura-quadril recalculados.
- Parser estrito, como nos outros envelopes: recusa itens fora da lista, datas inválidas e valores fora da faixa.
- O integrador confirma o nome dos campos e o contrato (`contrato-plano.md`) antes de codificar.

## Formato do arquivo da pré-consulta

Envelope JSON `formato: "plano-de-cuidado-pre-consulta"`, `versao: 1`, extensão `.plano` (o app já recebe `.plano` e distingue pelo `formato`, como faz com a devolução). Campos: `id` (aleatório), `criadoEm`, `termo` (`versao`, `aceitoEm`), `paciente` (`nome`, `nascimento`), `respostas` (estrutura do estado web: `ident`, `saude`, `medidas`, `alimentacao`, `sono`, `emocional`, `habitos`, `hormonal`). Parser estrito: recusa campos fora do contrato, datas inválidas, escalas fora da faixa e termo não aceito. Ver contrato em `contrato-plano.md` quando implementado.

## Banco local (celular da médica)

Mudança **aditiva**, sem apagar nada existente (`onUpgrade` cria tabelas novas):

- `pacientes(id, nome, nascimento, criado_em, atualizado_em)` — identidade por nome normalizado + nascimento, a mesma regra que o app já usa para conferir destinatário.
- `pre_consultas(id, paciente_id, recebida_em, json)`.
- `reavaliacoes(id, paciente_id, recebida_em, json)`.

A ficha da paciente reúne, em ordem de data: pré-consultas, reavaliações, planos criados, rascunhos de PDF conferidos e acompanhamentos recebidos. Planos e acompanhamentos são ligados **por consulta** (nome + nascimento), sem migrar os dados atuais. Tudo entra no backup `.plano-backup` existente.

## Segurança e LGPD

- CPF, endereço e nome da mãe passam a ficar no celular da médica. O modo profissional já exige biometria; manter.
- Histórico local depende de backup: perder o celular sem backup é perder o histórico. Adicionar lembrete de backup no modo profissional.
- O histórico do app **não substitui o prontuário eletrônico** (guarda legal de 20 anos). O app não grava no iMedicina: a consulta continua sendo registrada lá.
- Arquivo da pré-consulta e da reavaliação trafega legível, sem criptografia adicional, como o `.plano` e a devolução.
- **Termo desatualizado para o app** (ver decisão 1). Sem nova versão revisada por advogado, usar o app só em teste, sem paciente real.

## Pendências

1. Termo do app: escrever e levar ao advogado (a médica optou por adiar).
2. Distribuição: TestFlight ou App Store (a médica ainda não decidiu).
3. Nome dos campos de `reavaliacao` no contrato, a confirmar com o integrador.

## Etapas de implementação

1. **Núcleo (feito):** `core/pre_consulta.dart`, tabelas `pacientes`/`pre_consultas`/`reavaliacoes` (SQLite v3), backup e `test/pre_consulta_test.dart`. Campos no contrato: `contrato-plano.md`. Rascunhos de PDF passaram a entrar no backup (27/10/2026), então a ficha não perde os planos vindos de PDF.
2. **Paciente:** telas das etapas, rascunho, revisão, exportação com declaração de envio. Testes de widget, fonte ampliada.
3. **Médica:** receber arquivo, tela Pacientes, ficha com histórico, IMC e relação cintura-quadril. Testes de widget.
4. **Depois:** campo `reavaliacao` no plano e lembretes locais, criar plano a partir da ficha (pré-preenche identidade), lembrete de backup.

Os módulos da `Especificacao_Aplicativo_Plano_Cuidado.docx` (pilares, medicamentos, métricas, tarefas, exames) entram depois, cada um com o próprio contrato.
