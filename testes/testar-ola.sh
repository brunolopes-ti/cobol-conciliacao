#!/usr/bin/env bash
set -euo pipefail

raiz_projeto="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pasta_teste="$(mktemp -d)"

trap 'rm -rf -- "$pasta_teste"' EXIT

echo "Compilando a conferencia interativa..."
cobc -x -free -o "$pasta_teste/ola" "$raiz_projeto/ola.cob"

aprovados=0
reprovados=0

verificar_fim_entrada() {
    local nome="$1"
    local entrada="$2"
    local mensagem_esperada="$3"
    local codigo_obtido=0
    local falhou=0

    printf '%b' "$entrada" |
        "$pasta_teste/ola" \
        > "$pasta_teste/obtido.txt" 2>&1 ||
        codigo_obtido=$?

    if [ "$codigo_obtido" -ne 1 ]; then
        echo "Codigo incorreto em '$nome':"
        echo "Esperado: 1 | Obtido: $codigo_obtido"
        falhou=1
    fi

    if ! grep -Fq "$mensagem_esperada" \
        "$pasta_teste/obtido.txt"; then

        echo "Mensagem esperada nao encontrada em '$nome':"
        echo "Esperado:"
        echo "$mensagem_esperada"
        echo
        echo "Saida obtida:"
        cat "$pasta_teste/obtido.txt"

        falhou=1
    fi

    if [ "$falhou" -eq 0 ]; then
        echo "PASSOU: $nome"
        aprovados=$((aprovados + 1))
    else
        echo "FALHOU: $nome"
        reprovados=$((reprovados + 1))
    fi
}

# Cenario 1: entrada encerrada antes do operador

verificar_fim_entrada \
    "fim antes do operador" \
    "" \
    "Erro: entrada encerrada antes de informar o operador."

# Cenario 2: entrada encerrada antes do valor esperado

verificar_fim_entrada \
    "fim antes do valor esperado" \
    "bruno\n" \
    "Erro: entrada encerrada antes do valor esperado."

# Cenario 3: entrada encerrada antes do valor recebido

verificar_fim_entrada \
    "fim antes do valor recebido" \
    "bruno\n100.00\n" \
    "Erro: entrada encerrada antes do valor recebido."

echo
echo "Resumo: $aprovados aprovados, $reprovados reprovados."

if [ "$reprovados" -gt 0 ]; then
    exit 1
fi

exit 0
