"""Build assets/alimentos/taco.json from the TACO 4th edition CSVs.

Source: TACO - Tabela Brasileira de Composição de Alimentos, 4a edição
(NEPA/UNICAMP, 2011), CSV normalization from github.com/raulfdm/taco-api
(references/csv). Usage:

    python3 -I scripts/gerar_tabela_alimentos.py <pasta com food.csv>

Blank values in TACO (not analysed or trace) count as zero. Each food gets the
swap group the app uses to keep the main macro when the patient trades foods.
Also writes output/lista-alimentos.txt, the exact names accepted in the PDF.
"""
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# TACO has no macros for fluid milk and no peanut butter. These come from USDA
# FoodData Central, SR Legacy (public domain): 01077, 01151 and 16098.
COMPLEMENTOS = [
    [9001, 'Leite, de vaca, integral', 'laticinio', 61.0, 3.2, 4.8, 3.3, 0.0],
    [9002, 'Leite, de vaca, desnatado, UHT', 'laticinio', 34.0, 3.4, 5.0, 0.1, 0.0],
    [9003, 'Pasta de amendoim, integral', 'gordura', 588.0, 25.1, 20.0, 50.4, 6.0],
]


def numero(v):
    return round(float(v), 1) if v not in ('', None) else 0.0


# Seasonings that TACO files with vegetables; traded gram for gram.
TEMPEROS = ('Alho,', 'Coentro,', 'Tomate, extrato', 'Jurubeba,')


def grupo(categoria, nome, kcal, p, c, g):
    if categoria == 11 or nome.startswith(TEMPEROS):
        return 'livre'
    if categoria == 13:
        return 'preparado'
    if categoria in (5, 6, 9):
        return 'proteina'
    if categoria == 7:
        return 'laticinio'
    if categoria in (4, 15):
        return 'gordura'
    if categoria == 3:
        return 'fruta'
    if categoria == 14:
        return 'leguminosa'
    if categoria == 1:
        return 'carboidrato'
    if categoria == 2:
        return 'carboidrato' if c >= 10 else 'livre'
    if categoria == 8:
        return 'bebida'
    if categoria == 10:
        return 'doce'
    if kcal < 25:
        return 'livre'
    partes = {'carboidrato': c * 4, 'proteina': p * 4, 'gordura': g * 9}
    return max(partes, key=partes.get)


def main(pasta):
    pasta = Path(pasta)
    foods = list(csv.DictReader(open(pasta / 'food.csv', encoding='utf-8')))
    nut = {r['foodId']: r for r in csv.DictReader(open(pasta / 'nutrients.csv', encoding='utf-8'))}
    lista = []
    for f in foods:
        n = nut[f['id']]
        if n['kcal'] == '':
            continue
        kcal = numero(n['kcal'])
        p, c, g = numero(n['protein']), numero(n['carbohydrates']), numero(n['lipids'])
        fib = numero(n['dietaryFiber'])
        nome = ' '.join(f['name'].split())
        lista.append([int(f['id']), nome, grupo(int(f['categoryId']), nome, kcal, p, c, g), kcal, p, c, g, fib])
    lista += COMPLEMENTOS
    nomes = [x[1].lower() for x in lista]
    assert len(nomes) == len(set(nomes)), 'nomes repetidos'
    destino = ROOT / 'assets' / 'alimentos' / 'taco.json'
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(json.dumps({
        'fonte': 'TACO - Tabela Brasileira de Composição de Alimentos, 4ª edição. NEPA/UNICAMP, 2011. Leite líquido e pasta de amendoim: USDA FoodData Central.',
        'colunas': ['id', 'nome', 'grupo', 'kcal', 'proteina', 'carboidrato', 'gordura', 'fibra'],
        'alimentos': lista,
    }, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    saida = ROOT / 'output' / 'lista-alimentos.txt'
    saida.parent.mkdir(parents=True, exist_ok=True)
    grupos = {'carboidrato': 'carboidratos', 'leguminosa': 'leguminosas', 'fruta': 'frutas',
              'proteina': 'proteínas', 'laticinio': 'leite e derivados', 'gordura': 'gorduras',
              'doce': 'doces', 'bebida': 'bebidas', 'preparado': 'pratos prontos',
              'livre': 'verduras e baixa caloria'}
    linhas = [
        'Alimentos aceitos na linha "Alimentos:" do plano em PDF.',
        'Copie o nome exatamente como está antes da primeira barra e acrescente as gramas, por exemplo:',
        'Alimentos: Arroz, tipo 1, cozido 150 g; Feijão, carioca, cozido 80 g',
        'Colunas: nome | grupo de troca | por 100 g: kcal | proteína g | carboidrato g | gordura g | fibra g',
        'Fonte: TACO 4ª edição (NEPA/UNICAMP, 2011); leite líquido e pasta de amendoim: USDA FoodData Central.',
        '',
    ] + [
        f'{x[1]} | {grupos[x[2]]} | {x[3]:g} | {x[4]:g} | {x[5]:g} | {x[6]:g} | {x[7]:g}'
        for x in sorted(lista, key=lambda x: x[1].lower())
    ]
    saida.write_text('\n'.join(linhas) + '\n', encoding='utf-8')
    print(len(lista), destino)


if __name__ == '__main__':
    main(sys.argv[1])
