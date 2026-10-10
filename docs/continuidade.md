# Estado e próximas tarefas - 10/10/2026

Levantamento de código para passagem ao próximo programador. Não interpretar propostas antigas como funcionalidades concluídas.

## Prioridades

1. **Unificar exportação v3:** `_exportarPlano` força v2, embora criação/editor usem v3. Testar arquivo realmente compartilhado, inclusive rotina alimentar, e abrir novamente no parser. Não confundir testes de `novoPlano` com exportação da interface.
2. **Calendário único:** atualmente retorno é obrigatório e metas aparecem/agendam diariamente. Frequência semanal, dias do acompanhamento, descanso e término opcional ainda não têm implementação comum em Hoje/tabela/alarmes. Planejar contrato e migrar consumidores juntos; preservar registros por ID.
3. **Importação alimentar prática:** há importação JSON e modelo fictício com três refeições. Conversão automática do PDF, link/HTML do Monte seu prato, catálogo completo/equivalências, imagens e integração com Claude/IA ainda não existem neste checkout. O código do site não acompanha este repositório.
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
