# Verificação da fase 2 — 03/10/2026

## Resultado

- `flutter analyze`: sem problemas.
- `flutter test`: 22 testes aprovados.
- `flutter build ios --simulator --debug`: compilação aprovada; versão atual carregada com hot reload após os ajustes finais.

## Cobertura automatizada

- Validação da assinatura, versão, tipos, datas e limites das semanas.
- Rejeição de PDF, imagem, JSON inválido e versão futura, com mensagens em português.
- Criação e edição de planos profissionais sem substituir o plano ativo do paciente.
- Duplicação com novo identificador, nome vazio e remoção do PDF anterior.
- Edição de metas dos cinco tipos e seção de texto; anexo de um PDF local pelo seletor simulado.
- Exportação de arquivo real em UTF-8 e reabertura pelo validador do app.
- Reimportação conservando registros de vários dias.
- Checklist, contador, texto e escala sem erro de conversão.
- Edição pela tabela de um dia passado e bloqueio de futuro.
- Escolha de outro dia, carregamento do texto salvo e edição sem alterar o texto de hoje.
- Prévia sem gravar registros; interação com fonte ampliada em 3,2 vezes.
- PNG com cabeçalho, paciente, profissional e período; registro de envio após sucesso do compartilhamento simulado.
- Backup/restauração de planos, rascunhos, registros, envios e configuração; rejeição de versão inválida.
- Agendamento local limitado a 60 avisos; desligamento cancela os avisos.

Os testes usam SQLite real em armazenamento isolado. Seletor de arquivos, compartilhamento e notificações usam substitutos locais nos testes automatizados.

## Verificação no simulador iOS 17.5

Confirmados na interface: modo Profissional, cópia do plano importado como modelo, nome do novo paciente, salvamento local, prévia do paciente, checklist e contador na prévia, abertura do editor de meta, confirmação ao sair sem salvar e abertura do compartilhamento nativo do `.plano`. Foi criado um rascunho chamado Teste Fase 2. O plano ativo do paciente foi mantido.

O PNG gerado pelos testes foi inspecionado visualmente com as fontes reais. O fundo está branco e as colunas têm largura limitada. Nenhum plano foi enviado a outra pessoa.

## Verificações que exigem aparelho real

Ainda não confirmados: abertura a partir do WhatsApp em outro telefone, legibilidade na prévia do WhatsApp, disparo de avisos com o aparelho reiniciado, biometria e funcionamento em modo avião no iPhone físico. A instalação física depende da autenticação do Apple ID/Personal Team. Android e o manifesto do release pertencem à fase 3.
