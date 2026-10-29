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

## Alimentos de cada refeição (opcional)

A linha Alimentos transforma a refeição numa calculadora para a paciente. Liste os alimentos com as gramas, separados por ponto e vírgula, usando os nomes exatos da lista de alimentos do app (tabela TACO). Exemplo apenas de preenchimento:

Alimentos: Arroz, tipo 1, cozido 150 g; Feijão, carioca, cozido 100 g; Frango, peito, sem pele, grelhado 100 g

Mantenha a Prescricao com as medidas caseiras, como 6 colheres de sopa de arroz; ela aparece para a paciente como orientação. Se um nome não estiver na lista, o app recusa o PDF e sugere nomes parecidos. Use no máximo 15 alimentos por refeição. Sem a linha Alimentos, a refeição continua só com o texto.

No app, a paciente vê cada alimento com as gramas e os nutrientes, e quanto o dia soma contra as metas de macro. Se não quiser um alimento naquele dia, toca em trocar e escolhe outro do mesmo grupo: o app calcula a quantidade que mantém o mesmo carboidrato (cereais, tubérculos, leguminosas e frutas), a mesma proteína (carnes, ovos, peixes, leite e derivados) ou a mesma gordura (óleos e oleaginosas). Verduras trocam pela mesma quantidade em gramas. A troca vale só para aquele dia e pode ser desfeita. O plano que você enviou não muda. Trocas fritas, ultraprocessadas ou bem mais calóricas aparecem separadas como menos indicadas; se a paciente escolher uma, o app avisa e mostra até três opções melhores.

Na conferência, cada refeição tem o botão Incluir alimentos ou Editar alimentos: dá para acrescentar, remover ou mudar as gramas buscando na tabela, sem refazer o PDF. Quando a paciente exporta o acompanhamento, o arquivo traz o que ela comeu em cada dia (as refeições marcadas como feitas, já com as trocas), e você vê o total do dia contra as metas e o que foi trocado.

## Metas de macro e reavaliação (opcionais)

O bloco METAS DE MACRO leva as metas do dia todo. Escreva só o número em cada campo: Calorias em kcal; Proteina, Carboidrato, Gordura e Fibra em gramas. Fibra é opcional; se não quiser informar, apague a linha. Exemplo apenas de preenchimento:

Calorias: 2270
Proteina: 104
Carboidrato: 282
Gordura: 81

A paciente vê essas metas na aba Alimentação, acima das refeições. O aplicativo não confere se as refeições somam esses valores. Se não for definir metas, apague o bloco inteiro, de METAS DE MACRO até FIM METAS DE MACRO.

O bloco REAVALIACAO pede à paciente que atualize alguns dados ao longo do plano. Em Itens, escreva MEDIDAS, SONO e/ou HUMOR, separados por vírgula. Em Datas, escreva de uma a doze datas DD/MM/AAAA, em ordem, separadas por vírgula, entre o início dos registros e o retorno. Em cada data a paciente recebe um lembrete às 9h, responde no app e envia o arquivo, que entra na ficha dela. Exemplo:

Itens: MEDIDAS, SONO
Datas: 10/11/2026, 24/11/2026

Se não for pedir reavaliação, apague o bloco inteiro, de REAVALIACAO até FIM REAVALIACAO. Os dois blocos também podem ser ajustados no app durante a conferência.

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
