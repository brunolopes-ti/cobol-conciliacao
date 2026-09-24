#!/usr/bin/env bash
set -euo pipefail

raiz_projeto="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pasta_teste="$(mktemp -d)"
trap 'rm -rf -- "$pasta_teste"' EXIT

command -v python3 >/dev/null || {
    echo 'Erro: python3 necessario para os testes.'
    exit 1
}

echo 'Compilando os testes do resultado estruturado...'

cobc -x -free -o "$pasta_teste/conciliacao" \
    "$raiz_projeto/conciliacao.cob" \
    "$raiz_projeto/validar-monetario.cob" \
    "$raiz_projeto/entrada-segura.c" \
    "$raiz_projeto/relatorio-seguro.c"

caso="$pasta_teste/caso-principal"

mkdir -p "$caso/dados"

cat > "$caso/dados/esperados.csv" <<'EOF'
P001;100.00
P002;200.00
P003;75.00
P005;50.00
P006;60.00
EOF

cat > "$caso/dados/recebidos.csv" <<'EOF'
P001;100.00
P002;220.00
P003;70.00
P005;30.00
P005;40.00
P004;10.00
P004;20.00
EOF

codigo=0

(
    cd "$caso"

    "$pasta_teste/conciliacao" \
        dados/esperados.csv \
        dados/recebidos.csv \
        relatorio.txt \
        resultado.tsv
) > "$caso/saida.txt" 2>&1 || codigo=$?

if [ "$codigo" -ne 0 ]; then
    echo "FALHOU: conciliacao retornou codigo $codigo"
    cat "$caso/saida.txt"
    exit 1
fi

if [ ! -f "$caso/resultado.tsv" ]; then
    echo 'FALHOU: resultado.tsv nao foi criado.'
    exit 1
fi

if [ ! -f "$caso/relatorio.txt" ]; then
    echo 'FALHOU: relatorio.txt nao foi criado.'
    exit 1
fi

python3 - "$caso/resultado.tsv" <<'PY'
import pathlib
import sys

caminho = pathlib.Path(sys.argv[1])
dados = caminho.read_bytes()

def falhar(mensagem):
    print(f'FALHOU: {mensagem}')
    sys.exit(1)

if not dados:
    falhar('resultado.tsv esta vazio.')

if dados.startswith(b'\xef\xbb\xbf'):
    falhar('resultado.tsv contem BOM.')

if b'\r' in dados:
    falhar('resultado.tsv contem CR; o contrato exige LF.')

try:
    texto = dados.decode('utf-8')
except UnicodeDecodeError as erro:
    falhar(f'resultado.tsv nao e UTF-8 valido: {erro}')

if not texto.endswith('\n'):
    falhar('resultado.tsv deve terminar com LF.')

linhas = texto.splitlines()

if not linhas:
    falhar('resultado.tsv nao possui linhas.')

if any(linha == '' for linha in linhas):
    falhar('resultado.tsv contem linha vazia.')

registros = [linha.split('\t') for linha in linhas]

if registros[0] != ['VERSAO', '1']:
    falhar(
        'primeira linha deve ser exatamente '
        'VERSAO<TAB>1.'
    )

if len(registros[0]) != 2:
    falhar('linha VERSAO deve possuir exatamente 2 campos.')

if registros[-1][0] != 'RESUMO':
    falhar('RESUMO deve ser a ultima linha.')

if len(registros[-1]) != 10:
    falhar('linha RESUMO deve possuir exatamente 10 campos.')

for numero, registro in enumerate(registros[1:-1], start=2):
    if registro[0] != 'DETALHE':
        falhar(
            f'linha {numero} deveria ser DETALHE, '
            f'mas recebeu {registro[0]!r}.'
        )

    if len(registro) != 7:
        falhar(
            f'linha {numero} possui {len(registro)} campos; '
            'esperado: 7.'
        )

esperado = [
    ['VERSAO', '1'],

    [
        'DETALHE',
        'P001',
        '100.00',
        '100.00',
        '0.00',
        'CONFERIDO',
        '1',
    ],

    [
        'DETALHE',
        'P002',
        '200.00',
        '220.00',
        '20.00',
        'ACIMA_DO_ESPERADO',
        '1',
    ],

    [
        'DETALHE',
        'P003',
        '75.00',
        '70.00',
        '-5.00',
        'ABAIXO_DO_ESPERADO',
        '1',
    ],

    [
        'DETALHE',
        'P005',
        '50.00',
        '30.00',
        '-20.00',
        'DUPLICADO',
        '2',
    ],

    [
        'DETALHE',
        'P006',
        '60.00',
        '',
        '',
        'SEM_RECEBIMENTO',
        '0',
    ],

    [
        'DETALHE',
        'P004',
        '',
        '10.00',
        '',
        'SEM_PREVISAO',
        '1',
    ],

    [
        'DETALHE',
        'P004',
        '',
        '20.00',
        '',
        'SEM_PREVISAO',
        '1',
    ],

    [
        'RESUMO',
        '1',
        '1',
        '1',
        '1',
        '1',
        '2',
        '485.00',
        '490.00',
        '5.00',
    ],
]

if registros != esperado:
    print('FALHOU: conteudo do resultado.tsv diverge do contrato.')
    print()
    print('Obtido:')

    for registro in registros:
        print(repr(registro))

    print()
    print('Esperado:')

    for registro in esperado:
        print(repr(registro))

    sys.exit(1)

status_validos = {
    'CONFERIDO',
    'ACIMA_DO_ESPERADO',
    'ABAIXO_DO_ESPERADO',
    'DUPLICADO',
    'SEM_RECEBIMENTO',
    'SEM_PREVISAO',
}

status_encontrados = {
    registro[5]
    for registro in registros
    if registro[0] == 'DETALHE'
}

if status_encontrados != status_validos:
    falhar(
        'conjunto de status diferente do contrato. '
        f'Obtido: {sorted(status_encontrados)}'
    )

print('PASSOU: versao e estrutura')
print('PASSOU: quantidade de campos')
print('PASSOU: todos os status')
print('PASSOU: valores monetarios')
print('PASSOU: primeiro recebimento define duplicado')
print('PASSOU: quantidade de recebimentos duplicados')
print('PASSOU: recebimentos repetidos sem previsao')
print('PASSOU: campos vazios conforme o status')
print('PASSOU: resumo e totais')
print('PASSOU: resumo como ultima linha')
print('PASSOU: UTF-8 sem BOM e linhas LF')
PY

grep -Fxq \
    'Conferencia concluida.' \
    "$caso/relatorio.txt" || {
        echo 'FALHOU: relatorio nao foi concluido.'
        exit 1
    }

grep -Fxq \
    'Conferencia concluida.' \
    "$caso/saida.txt" || {
        echo 'FALHOU: sucesso nao foi anunciado.'
        exit 1
    }

echo
echo 'Resumo: resultado estruturado aprovado.'
exit 0
