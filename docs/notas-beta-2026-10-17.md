# Teste da médica — importação e acompanhamento

## O que mudou

- Importação local do PDF no padrão PLANO-CUIDADO/1, com conferência antes de gerar o plano.
- Exportação da prescrição conferida em `.plano` para o paciente.
- Rotina alimentar textual, registro de refeições e hidratação, com lembretes locais.
- Exportação cumulativa do acompanhamento pelo paciente.
- Abertura dos acompanhamentos recebidos no modo profissional, com consulta de cada dia sem alterar a prescrição.

## Roteiro curto

1. Médica: preencher o modelo Word, exportar PDF com texto selecionável e importar em Meus planos. Conferir identidade, período, metas, refeições e lembretes; concluir e exportar o `.plano`.
2. Paciente: cadastrar nome/nascimento iguais aos da prescrição, importar o `.plano` e permitir notificações. Registrar o que fez, não fez ou dispensou conforme regra escrita. Quantidades são informadas diretamente.
3. Paciente: Hoje ou Semana > Exportar acompanhamento > conferir > compartilhar. O arquivo de devolução começa com `acompanhamento-`. Salvar em Arquivos não é enviar; só declarar envio após encaminhar à médica.
4. Médica: Meus planos > Acompanhamentos recebidos > Abrir acompanhamento .plano > conferir > Receber e visualizar. Abrir cada dia e verificar os registros.

## Atenções

O app não tem IA, não cria prescrição a partir da anamnese e não interpreta texto livre como tarefa. Usar o padrão do template. Cada paciente recebe somente o próprio arquivo; conferir nome e nascimento antes de compartilhar.

Não confirmado significa ausência de marcação, não prova de que não fez. Os dados são declarados pelo paciente. Não há envio automático, confirmação de recebimento, assinatura digital ou criptografia adicional do arquivo. Evitar dados reais nos primeiros testes de beta; usar o exemplo fictício da Ana.

Ambos os aparelhos precisam da versão atualizada. Na simulação no mesmo aparelho, trocar de modo não importa arquivos nem altera cadastros. Não cadastrar Ana no aparelho de um paciente real.

Os lembretes dependem da permissão do iOS, usam o fuso America/Sao_Paulo e têm janela de até 60 eventos futuros, reposta ao abrir o app. Foi confirmado som em segundo plano no iPhone do responsável. Ainda testar comportamento após instalação do TestFlight, reinício e uso ao longo do ciclo.
