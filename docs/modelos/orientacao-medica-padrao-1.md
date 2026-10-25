# Como preencher o plano para o aplicativo

Use o modelo editável PLANO-CUIDADO/1. O aplicativo lê campos combinados, sem inteligência artificial. A prescrição e a conferência continuam sendo suas. Preencha uma cópia por paciente no Word ou Pages e exporte como PDF com texto selecionável.

## Comece pelo arquivo editável

Substitua todos os trechos entre colchetes. Mantenha os rótulos, os dois-pontos e os marcadores de início e fim. Não use fotos, escaneamento, caixas de texto ou duas colunas. Não é necessário refazer o layout após cada consulta: basta preencher os valores do modelo.

No bloco DADOS DO PLANO, informe nome completo, nascimento, consulta, emissão, início e último dia de registro, retorno e horário. As datas usam DD/MM/AAAA e os horários usam HH:MM, com dois dígitos: por exemplo, 09:30. Não escreva “por volta das 9h” no campo de horário.

Envio semanal aceita DOMINGO, SEGUNDA, TERCA, QUARTA, QUINTA, SEXTA ou SABADO. Informe também a hora do envio. O fim dos registros não pode ser anterior ao início nem posterior ao retorno. Não deixe esses campos em branco nesta versão.

## Escreva as metas nos blocos próprios

O modelo já traz uma meta de refeições e uma de contagem. Você pode remover uma meta inteira ou duplicar o bloco adequado. Numere META 1, META 2 e assim por diante, até oito. Esta versão considera as metas diárias. Condutas semanais ou pontuais ficam nas orientações livres até que esse acompanhamento seja implementado.

Tipo REFEICOES usa as refeições cadastradas abaixo, com suas regras de obrigatoriedade. Tipo CONTAGEM usa quantidade diária, unidade e distribuição. Tipo CONFIRMACAO registra uma ação diária com sim ou não e usa os mesmos campos de REFEICOES: Titulo, Tipo, Lembretes e Orientacao. Não acrescente quantidade ou distribuição nesses dois tipos.

Lembretes deve conter horários HH:MM separados por vírgula, sem repetir, ou NENHUM. O número de lembretes não define a quantidade da meta. Horários escritos somente em parágrafos não são importados como lembretes.

## Defina a contagem sem soma implícita

Na meta CONTAGEM, informe a quantidade em número e a unidade por extenso. A distribuição indica uma quantidade em cada horário, nunca uma quantidade acumulada. A soma deve ser igual à quantidade diária. Se não quiser distribuição fixa, escreva LIVRE; os lembretes continuam sendo definidos separadamente.

Exemplo apenas de preenchimento, não de prescrição:

Quantidade diaria: 4
Unidade: copos de 500 ml
Distribuicao: 07:00=1; 10:00=1; 12:00=1; 15:00=1
Lembretes: 10:00, 12:00

Nesse exemplo, são quatro unidades e dois lembretes. O aplicativo não deduz quantidades de frases como “um ao acordar e mais dois depois”.

## Identifique as refeições condicionais

Mantenha de uma a oito refeições quando houver meta REFEICOES. Não precisam ser sempre quatro. Para remover ou acrescentar, remova ou duplique o bloco inteiro e numere REFEICAO 1, REFEICAO 2 e assim por diante. Cada nome deve ser único.

Em Regra, escreva OBRIGATORIA ou CONDICIONAL. Para obrigatória, preencha Condicao para dispensar com NAO SE APLICA. Para condicional, descreva a exceção autorizada, por exemplo, “quando não sentir fome”. A condição fica separada da lista de refeições obrigatórias. Alimentos e quantidades vão em Prescricao. Mantenha a orientação geral coerente com as exceções; o aplicativo não procura contradições em frases livres.

## Inclua o link e as orientações

Link pessoal deve conter o endereço completo, começando com https e incluindo a parte #p=..., ou NENHUM. Copie o destino do link pessoal do Monte seu prato, não somente o nome visível do site. O aplicativo não abre esse link durante a leitura.

Use ORIENTACOES LIVRES para mensagem, prioridades, exames, atividade física, sinais de alerta, medicamentos já prescritos, identificação profissional e demais orientações. Esses textos são preservados como referência; não criam automaticamente doses, tarefas ou alarmes. Não coloque apenas nesse bloco algo que precisa virar uma meta estruturada.

## Importe e confira antes de concluir

Exporte como PDF, abra o modo profissional e escolha Meus planos > Importar PDF do plano. Confira o destinatário, as datas, as metas, as condições e os textos. Você pode corrigir campos e salvar um rascunho para continuar depois. Se alterar algo, confirme novamente os três itens finais.

Um PDF sem o padrão, com rótulos ausentes ou valores inválidos é recusado com a indicação do problema. Ajuste o arquivo de origem e exporte novamente. Não preencha uma justificativa para contornar quantidades incompatíveis. Rascunhos antigos já salvos continuam disponíveis, mas PDFs antigos precisam ser refeitos no modelo novo para uma nova importação.

## Exporte o plano conferido

Depois de concluir e salvar, use Prévia do paciente para conferir a apresentação. Em Exportar .plano conferido, confirme nome, nascimento, perfil profissional e período antes de compartilhar. O arquivo contém dados de saúde e o PDF original; envie somente ao destinatário correto. Os dois aparelhos precisam da versão atualizada do aplicativo.

O paciente cadastra seus próprios dados e importa o .plano, não o PDF. Na aba Hoje, registra Fiz, Não fiz ou, nas refeições condicionais, Dispensado conforme plano. Sem marcação fica Não confirmado. Alimentação mostra a prescrição; Semana mostra os registros. Lembretes dependem da autorização do iPhone e respeitam o fim dos registros. Reexportar o mesmo rascunho mantém os identificadores para atualizar o acompanhamento sem apagar as marcações.

Para testar no mesmo iPhone, salve o .plano em Arquivos e use Ajustes > Trocar de modo > Sou paciente. Cadastre nome e nascimento iguais aos do exemplo de teste e importe o arquivo salvo. Depois confira as abas Hoje, Alimentação e Semana.

Não há IA, OCR, cálculo nutricional, verificação clínica automática ou confirmação de entrega. Ausência de aviso não substitui sua revisão. O arquivo de devolução do acompanhamento à médica ainda é uma etapa futura; o compartilhamento semanal atual gera uma imagem.
