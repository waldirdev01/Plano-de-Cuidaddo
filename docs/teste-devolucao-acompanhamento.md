# Devolução do acompanhamento — 17/10/2026

Escopo: paciente com `.plano` conferido v4 exporta os registros; médica recebe e consulta. O Word/PDF e as regras PLANO-CUIDADO/1 não mudaram. Não há IA nem envio automático.

## Teste no mesmo iPhone, com Ana fictícia

1. No modo paciente, cadastro Ana Exemplo Completo, nascimento 01/01/1990, abrir o plano já importado. Não repetir a importação do PDF.
2. Em Hoje, registrar uma refeição Fiz, outra Não fiz, lanche condicional Dispensado conforme plano e quantidade de água (ex.: 1,5). Deixar outra refeição sem marcar. Usar apenas datas não futuras no período.
3. Tocar **Exportar acompanhamento** em Hoje ou Semana. Conferir nome/nascimento, destinatária, período, metas e registros de cada dia. O período é cumulativo desde início até hoje ou o último dia, se já terminou.
4. Tocar **Compartilhar acompanhamento .plano** > Salvar em Arquivos. O nome começa por `acompanhamento-`. Na pergunta “Você enviou à médica?”, escolher **Só salvei / ainda não enviei** no teste local. Salvar não é enviar.
5. Voltar, trocar para **Sou profissional de saúde**, sem alterar o cadastro da Ana. O perfil profissional precisa ter o mesmo nome/registro usado na exportação da prescrição.
6. Abrir **Meus planos > Acompanhamentos recebidos > Abrir acompanhamento .plano**, selecionar o arquivo `acompanhamento-...plano` e conferir paciente/destinatária. Confirmar **Receber e visualizar**.
7. Expandir o dia marcado. Conferir Feito, Não feito, dispensa, quantidade exata e Não confirmado nos campos sem marcação. Consulta é somente leitura. Expansor de metas mostra referência prescrita, incluindo alvo e regra condicional.
8. Voltar e reabrir na lista. Reimportar o mesmo arquivo não duplica. Corrigir uma marcação no modo paciente, exportar novo arquivo e receber: aparecem dois snapshots; o novo inclui também os dias anteriores corrigidos. Nenhum substitui a prescrição nem os registros locais.

## Em aparelhos diferentes

Paciente compartilha o arquivo com a médica por aplicativo/canal escolhido por ele. Somente após encaminhar, escolhe **Já enviei à médica**. Isso declara envio e atualiza lembretes; não atesta entrega/leitura. A médica precisa do aplicativo atualizado no modo profissional. Tocar no `.plano` recebido usa o roteador nativo existente; também pode selecionar em Acompanhamentos recebidos.

Não mandar cópia de segurança. Não selecionar o `.plano` original de prescrição na área de recebimentos. Devolução aberta no modo paciente pede troca explícita e não altera perfil/plano.

## Avisos

Aviso semanal usa o dia/hora definidos no plano (uma hora antes do limite). Planos v4 também têm lembrete final às 18h do último dia de registros, se ainda não declararam envio até esse dia. Avisos dependem de autorização do iOS, fuso America/Sao_Paulo e janela de até 60 eventos reposta ao abrir/recarregar o app. Não há botão de confirmar tarefa dentro da notificação. Não há garantia de avisos em segundo plano por todo o ciclo sem abrir o app.

## Limites e segurança

- Apenas prescrições conferidas v4 nesta etapa; arquivos legados continuam funcionando nos fluxos antigos, sem conversão silenciosa.
- Estado final de cada dia, não auditoria de cada toque/horário. Ausência não significa não execução.
- Somente dados de autorrelato, sem prova de autenticidade/assinatura. Arquivo JSON legível, sem senha ou criptografia nova.
- Nome/nascimento identificam o paciente e nome/registro identificam a destinatária declarada; não verificam uma identidade real externamente.
- Não mescla snapshots automaticamente e não gera recomendação clínica. Consulta diária, sem gráficos/escores novos.
- O backup já inclui os recebimentos por estarem em config. Continua sem incluir rascunhos PDF profissionais.

## Verificação

Testes de serviço: recorte cumulativo, valores/zero/ausência, correções, período futuro/término, limites e arquivos inválidos, destinatária, importação idempotente, isolamento dos registros e backup/restauração. Testes de tela: arquivo efetivamente compartilhado, cancelamento/salvar sem declarar envio, confirmação explícita, abertura profissional sem mexer no paciente, bloqueio antes de exibir identidade no modo errado e fonte ampliada. Testes não substituem compartilhamento e abertura reais no iPhone.

Resultado local nesta etapa: `flutter analyze` sem problemas; `flutter test` com **88 testes aprovados**, incluindo os nove novos testes de devolução. Nenhuma mensagem ou arquivo foi enviado a uma médica real pelas ferramentas. Depois da instalação, o responsável confirmou manualmente que exportou, abriu no modo profissional e tudo funcionou. Também confirmou alerta com som no iPhone com o aplicativo em segundo plano. Funcionamento em primeiro plano não foi confirmado; não inferir a causa da tentativa anterior sem aviso.

Compilação assinada debug concluída e instalação/inicialização no iPhone Waldir (14 Pro Max), sem desinstalar nem limpar dados. A execução não residente encerrou com código 0 após sincronização (registrou desconexão do cliente Flutter); uma leitura posterior do Xcode confirmou **Running Runner on Waldir** e nova sessão Dart. Não houve upload TestFlight, commit ou publicação remota nesta etapa. A aceitação manual posterior está registrada acima e não decorre apenas da compilação.
