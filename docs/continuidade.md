# Estado e próximas tarefas - 10/10/2026

Levantamento de código para passagem ao próximo programador. Não interpretar propostas antigas como funcionalidades concluídas.

## Atualização de 17/10/2026 - conferência e exportação do PDF

### Continuação: devolução do paciente

**Aceitação manual posterior:** o responsável confirmou exportação do acompanhamento, abertura e consulta no modo profissional no mesmo iPhone. Confirmou também lembrete com som com app em segundo plano. Autorizou preparar a entrega para teste da médica pela loja/TestFlight. A entrega release e seu processamento pela Apple são etapas separadas; registrar o resultado real em `distribuicao-ios.md`.

O responsável conseguiu exportar o plano da Ana, alterar explicitamente o cadastro fictício e importar no modo paciente. Relatou que os horários de hidratação vieram corretamente; isso não equivale à comprovação de som/notificação pelo iOS. Autorizou então a devolução do acompanhamento.

Implementado `RetornoAcompanhamento` (envelope v1, extensão `.plano`) para prescrições conferidas v4. Exporta cumulativo até hoje/fim, mantendo correções anteriores e ausência como não confirmado. Recebimento no modo profissional confere nome/registro e guarda snapshots separados em config `retorno_recebido_<id>` (incluídos no backup existente). Não altera planos, seleção, cadastro ou registros locais. A tela permite abrir cada dia e consultar as metas/prescrições de referência. Compartilhamento requer declaração explícita de envio antes de registrar em envios e reagendar avisos; salvar/cancelar não equivale a enviar. Há lembrete final às 18h do último dia de registros, além dos semanais. Veja `teste-devolucao-acompanhamento.md` e o contrato atualizado. Aceitação manual desta etapa ainda pendente.

O responsável testou e aceitou importação e conclusão da conferência no iPhone. Depois autorizou exportação e teste como paciente. Implementado o conversor do rascunho aprovado para `.plano` v4, prévia e compartilhamento com conferência do destinatário. O paciente importa pelo fluxo existente, recebe rotina textual, registra execução/dispensa e tem lembretes locais após autorização. Ver `teste-exportacao-pdf-fase2.md`. “Anexar PDF” no editor manual continua sendo apenas anexo. A devolução, inicialmente fora da etapa 2, foi implementada na continuação acima.

O padrão de entrada **PLANO-CUIDADO/1** e o template continuam iguais. O novo formato 4 é do arquivo paciente, não uma mudança da versão do app. Rascunhos antigos são preservados, mas só os do padrão novo podem ser convertidos. O resultado completo de exportação/abertura/acompanhamento ainda precisa de aceitação no aparelho.

## Prioridades

1. **Aceitar exportação v4 no aparelho:** exportador deixou de forçar v2; preservar versão original e nunca fazer downgrade do v4. Testes exercitam bytes realmente compartilhados nos fluxos manual e conferido. Testar abertura em outro telefone atualizado e alarmes reais.
2. **Calendário ampliado:** v4 já separa fim de registros e retorno, com consumidores limitados pelo fim; versões anteriores mantêm o comportamento legado. Frequência semanal de metas, dias de descanso e término opcional continuam pendentes. Não inferir essas regras de texto livre.
3. **Alimentação:** PDF conferido agora gera rotina **textual** no paciente, com estados próprios e sem nutrientes inventados, separada da alimentação v3 com opções. Catálogo/equivalências e integração com site ou IA continuam pendentes. O código do site não acompanha este repositório.
4. **Históricos alimentares:** confirmar interface com trocas de planos/dias, backup/restauração e reimportação. Considerar ID/refeição estáveis e validação de seleções diárias inexistentes.
5. **Isolar horários personalizados:** hoje chave `horarios_meta_<metaId>` pode ser compartilhada entre planos que repetem ID de meta. Migrar para chave por plano sem perder configurações.
6. **Exclusão com confirmação:** encerramento/reativação existem; exclusão completa de acompanhamento não está implementada. Definir política de dados e confirmação antes de criar operação destrutiva.

## Correções e refinamentos conhecidos

- Parser v3 deve exigir nascimento como v2; revisar validação alimentar (`modo`, tipos opcionais, referências diárias e datas). Algumas conversões diretas podem produzir erros de tipo.
- Máscara do nascimento insere barras, mas posiciona o cursor no final. Melhorar edição no meio/colagem e comportamento ao apagar sem alterar a validação civil.
- Prévia alimentar não salva, mas ainda lê seleções/registros do armazenamento. Avaliar isolamento e atualização de tela quando JSON muda mantendo ID.
- PDF base64 aumenta arquivos/banco; não há limite específico de tamanho. Avaliar limite com mensagem útil e preservação de dados.
- Lembretes usam America/Sao_Paulo e janela de 60 eventos. Confirmar comportamento com reinício, fuso diferente e muitos horários; abrir o app repõe janela.
- Manter espaçamento em formulários, botões e fonte ampliada; testar teclado/telas pequenas.

## Android

Projeto Flutter/Gradle está presente. MainActivity não implementa ponte de arquivos recebidos; notificações só inicializam configuração iOS, autorização também é iOS. Release usa assinatura debug. Ícones, permissões, abertura `.plano`, biometria e avisos requerem implementação/validação antes de entrega Android.

## Distribuição e aceitação

Em 08/10/2026 foram aprovados analyze, 48 testes e geração de IPA assinado 1.1.0+3. Houve execução no iPhone em versões anteriores relatada pelo usuário. Ainda falta confirmação completa desta versão no aparelho, alarmes reais, WhatsApp em outro telefone, modo avião e fluxo alimentar real da médica.

Upload/aprovação TestFlight não foram confirmados nesta passagem. Build iOS informa plugin de notificações sem Swift Package Manager e launch image padrão. Corrigir launch image e avaliar migração do plugin em tarefa própria, preservando API/notificações; não fazer upgrade amplo sem validar.

Relatórios `testes-fase2.md` e `testes-conferencia-paciente.md` são históricos. O resumo da médica e o guia local não constituem evidência de teste executado.
