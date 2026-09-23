#!/usr/bin/env bash
set -euo pipefail

raiz_projeto="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pasta_teste="$(mktemp -d)"

trap 'rm -rf -- "$pasta_teste"' EXIT

echo "Compilando a conferencia interativa..."
cobc -x -free -o "$pasta_teste/ola" \
    "$raiz_projeto/ola.cob" \
    "$raiz_projeto/validar-monetario.cob"

aprovados=0
reprovados=0

verificar_cenario() {
    local nome="$1"
    local entrada="$2"
    local codigo_esperado="$3"
    shift 3

    local codigo_obtido=0
    local falhou=0
    local mensagem

    printf '%b' "$entrada" |
        "$pasta_teste/ola" \
        > "$pasta_teste/obtido.txt" 2>&1 ||
        codigo_obtido=$?

    if [ "$codigo_obtido" -ne "$codigo_esperado" ]; then
        echo "Codigo incorreto em '$nome':"
        echo "Esperado: $codigo_esperado | Obtido: $codigo_obtido"
        falhou=1
    fi

    for mensagem in "$@"; do
        if ! grep -Fxq -- "$mensagem" "$pasta_teste/obtido.txt"; then
            echo "Linha esperada nao encontrada em '$nome':"
            echo "$mensagem"
            falhou=1
        fi
    done

    if [ "$falhou" -eq 0 ]; then
        echo "PASSOU: $nome"
        aprovados=$((aprovados + 1))
    else
        echo "FALHOU: $nome"
        echo "Saida obtida:"
        cat "$pasta_teste/obtido.txt"
        reprovados=$((reprovados + 1))
    fi
}

# Cenario 1: entrada encerrada antes do operador

verificar_cenario \
    "fim antes do operador" \
    "" \
    1 \
    "Erro: entrada encerrada antes de informar o operador."

# Cenario 2: entrada encerrada antes do valor esperado

verificar_cenario \
    "fim antes do valor esperado" \
    "bruno\n" \
    1 \
    "Erro: entrada encerrada antes do valor esperado."

# Cenario 3: entrada encerrada antes do valor recebido

verificar_cenario \
    "fim antes do valor recebido" \
    "bruno\n100.00\n" \
    1 \
    "Erro: entrada encerrada antes do valor recebido."

# Cenario 4: pagamento valido com diferenca negativa

verificar_cenario \
    "pagamento valido" \
    "bruno\n100.50\n90.80\n" \
    0 \
    "Valor esperado: 100.50" \
    "Valor recebido: 90.80" \
    "Diferenca: -9.70" \
    "Status: valor recebido abaixo do esperado."

echo
echo "Resumo: $aprovados aprovados, $reprovados reprovados."

if [ "$reprovados" -gt 0 ]; then
    exit 1
fi

exit 0
