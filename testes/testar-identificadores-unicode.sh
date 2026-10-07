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

u2007=$'\u2007'

executar_invalido() {
    local id="$1"
    local nome="$2"

    printf '%s;1.00\n' "$id" > "$tmp/esperados.csv"
    printf 'P001;1.00\n' > "$tmp/recebidos.csv"

    set +e
    saida="$($tmp/conciliacao \
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

    if ! grep -Eq 'identificador (vazio|nao deve ter espacos nas extremidades)' <<<"$saida"; then
        echo "FALHOU: mensagem inesperada em $nome"
        printf '%s\n' "$saida"
        exit 1
    fi
}

executar_invalido "$u2007" "U+2007 isolado"
executar_invalido "${u2007}ABC" "U+2007 no inicio"
executar_invalido "ABC${u2007}" "U+2007 no fim"

# O contrato preserva identidade: espaco Unicode interno nao e removido.
printf 'A%sB;1.00\n' "$u2007" > "$tmp/esperados.csv"
printf 'A%sB;1.00\n' "$u2007" > "$tmp/recebidos.csv"
"$tmp/conciliacao" \
    "$tmp/esperados.csv" \
    "$tmp/recebidos.csv" \
    "$tmp/relatorio.txt" \
    "$tmp/resultado.tsv" >/dev/null

echo "Identificadores Unicode: PASSOU"
