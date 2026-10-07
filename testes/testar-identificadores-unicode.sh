#!/usr/bin/env bash
set -euo pipefail

raiz="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

cobc -x -free -o "$tmp/conciliacao" \
    "$raiz/conciliacao.cob" \
    "$raiz/validar-monetario.cob" \
    "$raiz/entrada-segura.c" \
    "$raiz/relatorio-seguro.c"

espacos=(
    $'\u0020'
    $'\u1680'
    $'\u2000'
    $'\u2001'
    $'\u2002'
    $'\u2003'
    $'\u2004'
    $'\u2005'
    $'\u2006'
    $'\u2007'
    $'\u2008'
    $'\u2009'
    $'\u200A'
    $'\u2028'
    $'\u2029'
    $'\u205F'
    $'\u3000'
)

nomes=(
    "U+0020"
    "U+1680"
    "U+2000"
    "U+2001"
    "U+2002"
    "U+2003"
    "U+2004"
    "U+2005"
    "U+2006"
    "U+2007"
    "U+2008"
    "U+2009"
    "U+200A"
    "U+2028"
    "U+2029"
    "U+205F"
    "U+3000"
)

executar_invalido() {
    local id="$1"
    local nome="$2"

    printf '%s;1.00\n' "$id" > "$tmp/esperados.csv"
    printf 'P001;1.00\n' > "$tmp/recebidos.csv"

    set +e
    saida="$("$tmp/conciliacao" \
        "$tmp/esperados.csv" \
        "$tmp/recebidos.csv" \
        "$tmp/relatorio.txt" \
        "$tmp/resultado.tsv" 2>&1)"
    codigo=$?
    set -e

    if [ "$codigo" -eq 0 ]; then
        echo "FALHOU: $nome deveria ser rejeitado"
        exit 1
    fi

    if ! grep -Eq \
        'identificador (vazio|nao deve ter espacos nas extremidades)' \
        <<<"$saida"; then
        echo "FALHOU: mensagem inesperada em $nome"
        printf '%s\n' "$saida"
        exit 1
    fi
}

executar_interior_valido() {
    local espaco="$1"
    local nome="$2"
    local id="A${espaco}B"

    printf '%s;1.00\n' "$id" > "$tmp/esperados.csv"
    printf '%s;1.00\n' "$id" > "$tmp/recebidos.csv"

    "$tmp/conciliacao" \
        "$tmp/esperados.csv" \
        "$tmp/recebidos.csv" \
        "$tmp/relatorio.txt" \
        "$tmp/resultado.tsv" >/dev/null

    if ! grep -Fq "$id" "$tmp/resultado.tsv"; then
        echo "FALHOU: $nome interno nao foi preservado no resultado"
        exit 1
    fi
}

for i in "${!espacos[@]}"; do
    espaco="${espacos[$i]}"
    nome="${nomes[$i]}"

    executar_invalido "$espaco" "$nome isolado"
    executar_invalido "${espaco}ABC" "$nome no inicio"
    executar_invalido "ABC${espaco}" "$nome no fim"
    executar_interior_valido "$espaco" "$nome"
done

echo "Identificadores Unicode: PASSOU (${#espacos[@]} espacos validados)"
