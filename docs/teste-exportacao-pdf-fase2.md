# Exportar o plano conferido e testar como paciente

Nota de continuidade: esta é a etapa 2. A devolução antes indicada como futura foi implementada depois; ver `teste-devolucao-acompanhamento.md`. O responsável já confirmou exportação e importação como Ana no mesmo iPhone.

Atualização local de 17/10/2026, continuidade da importação já aceita pelo responsável no iPhone. O modelo da médica **não mudou**: continua PLANO-CUIDADO/1. A mudança está na conversão do rascunho aprovado para o `.plano` de formato interno 4.

## Na versão da profissional

1. Em Meus planos > Rascunhos de PDF, reabrir a conferência já concluída. Se modificar algum campo, marcar as três confirmações e concluir novamente.
2. Conferir o perfil profissional (nome e registro). Ele identifica quem emite o arquivo; não é extraído por suposição dos parágrafos do PDF.
3. Usar **Prévia do paciente**. Hoje mostra as metas e cada refeição; Alimentação mostra as prescrições sem inventar nutrientes; Semana mostra as marcações. A prévia não grava marcações.
4. Tocar **Exportar .plano conferido**. Conferir nome/nascimento do destinatário, perfil profissional e período. Confirmar **Compartilhar .plano** e escolher **Salvar em Arquivos** para o teste local, ou compartilhar com o destinatário correto em outro aparelho. O arquivo contém dados de saúde e o PDF original, não é criptografado, e o app não escolhe contatos nem confirma entrega.

## Testar no mesmo iPhone

1. Salvar o `.plano` em Arquivos. Voltar a Meus planos e abrir o botão de configurações > **Trocar de modo > Sou paciente**.
2. Cadastrar nome completo e nascimento independentemente, iguais aos do plano de teste. O aplicativo **não preenche o cadastro a partir do arquivo**. Se já houver outro cadastro, ajustar explicitamente em Meu cadastro apenas para este teste fictício.
3. Em Importar plano, selecionar o `.plano`, não o PDF. Conferir o destinatário e confirmar a importação.
4. Em Hoje, marcar uma refeição como **Fiz**, outra como **Não fiz** e, somente onde houver regra condicional, **Dispensado conforme plano**. A condição autorizada deve estar visível.
5. Incrementar a contagem ou usar **Informar quantidade** (aceita decimal). Fechar/abrir o aplicativo e verificar persistência. Sem marcação fica **Não confirmado**, sem criar evidência de que a pessoa não realizou a atividade.
6. Conferir a rotina em Alimentação e o registro em Semana. Dias futuros não podem ser marcados. O calendário de registros termina no **fim dos registros**, não no retorno quando forem datas distintas.
7. Reimportar o mesmo `.plano` e confirmar que as marcações permanecem no mesmo acompanhamento. Corrigir e reexportar o mesmo rascunho mantém os mesmos IDs. Para outro paciente/ciclo, importar um novo PDF; não duplicar a exportação v4 pelo editor manual.

## Lembretes e períodos

Lembretes da meta vêm dos campos explícitos de Lembretes. Refeições usam seus horários conferidos. Distribuição de quantidade **não é convertida em lembretes implícitos**. Metas/refeições/envio semanal só são agendados no período de registros; retorno possui seu aviso separado. O aplicativo respeita o desligamento de lembretes e depende da autorização do iOS para apresentá-los.

Para testar som/avisos agora, definir no rascunho horários futuros próximos e período que inclua hoje, conferir e exportar novamente. Não mudar o relógio do aparelho. Ainda há janela de até 60 notificações futuras, reposta ao abrir/recarregar o app, sem garantia de reposição em segundo plano. Notificação não confirma execução nem registra automaticamente “Não fiz”.

## Compatibilidade e limites

- Ambos os aparelhos precisam da versão atualizada para o formato 4. Clientes antigos recusam pedindo atualização, em vez de ignorar dispensa e último dia.
- Formatos 1, 2 e 3 continuam legíveis; o exportador manual não força mais a versão 2.
- Prescrições textuais ficam em `refeicoesPrescritas`, separadas da alimentação v3 com opções/nutrientes. Não há cálculo ou substituição automática. O link pessoal pode ser copiado; não é aberto durante importação.
- Arquivo e campos possuem IDs estáveis. SQLite e formato do backup não mudaram. O backup inclui os planos importados/registros, mas continua sem incluir os rascunhos PDF profissionais.
- Caso uma refeição antes condicional vire obrigatória em reexportação, uma dispensa antiga é preservada e identificada como registro de regra anterior, sem reclassificação silenciosa.
- Compartilhar a semana continua gerando a imagem existente. Exportar o arquivo de devolução contendo acompanhamento para a médica e sua importação longitudinal continuam sendo uma etapa futura; não confundir com o `.plano` de prescrição desta entrega.

## Validação e aceitação

Testes de serviço validam bloqueio antes da conferência, versão/identidade/período, três/cinco/seis/oito refeições, correção da contagem, IDs estáveis e reimportação. Testes de interface exercitam o arquivo realmente compartilhado, abertura do paciente, feito/dispensa, rotina/semana, prévia sem gravação, contagem decimal e fonte ampliada. Teste de agendamento verifica horários e fim do período via mock nativo. Análise estática e build iOS são informados separadamente da aceitação no aparelho. Som, permissões, arquivos compartilhados por outro telefone e aceitação completa ainda exigem teste manual.

Resultado local de 17/10/2026: análise estática sem ocorrências; **79 testes aprovados**; build iOS de simulador aprovado. Guia da médica atualizado e suas duas páginas renderizadas/inspecionadas, sem alterar o template da consulta. A suíte inclui o arquivo efetivamente compartilhado pela interface, sua importação e as marcações do paciente; isso não representa teste de som, permissão ou entrega pelo WhatsApp em aparelho real.

Após as verificações, a versão foi compilada, instalada e iniciada via Xcode no iPhone “Waldir” (14 Pro Max), com status Running e nova sessão Dart. Não houve desinstalação, limpeza de dados, backup prévio ou upload para TestFlight. A aceitação manual de exportar o rascunho real de teste e importar/acompanhá-lo no aparelho fica a cargo do responsável nesta rodada.
