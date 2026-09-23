#!/usr/bin/env bash
set -euo pipefail

raiz_projeto="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pasta_teste="$(mktemp -d)"

trap 'rm -rf -- "$pasta_teste"' EXIT

echo "Compilando a conciliacao..."
cobc -x -free -o "$pasta_teste/conciliacao" \
    "$raiz_projeto/conciliacao.cob" \
    "$raiz_projeto/validar-monetario.cob"

mkdir -p "$pasta_teste/dados"

aprovados=0
reprovados=0

preparar_base() {
    cat > "$pasta_teste/dados/esperados.csv" <<'FIM'
P001;100.50
P002;200.00
P003;75.25
FIM

    cat > "$pasta_teste/dados/recebidos.csv" <<'FIM'
P003;75.25
P001;90.00
P004;50.00
FIM
}

acrescentar_resumo() {
    {
        echo "Resumo da conciliacao:"
        printf 'Conferidos: %s\n' "$1"
        printf 'Acima do esperado: %s\n' "$2"
        printf 'Abaixo do esperado: %s\n' "$3"
        printf 'Sem recebimento: %s\n' "$4"
        printf 'Sem previsao: %s\n' "$5"
        printf 'Total esperado: %s\n' "$6"
        printf 'Total recebido: %s\n' "$7"
        printf 'Saldo global: %s\n' "$8"
        echo "Conferencia concluida."
    } >> "$pasta_teste/esperado.txt"
}

verificar_cenario() {
    local nome="$1"
    local codigo_esperado="$2"
    local codigo_obtido=0
    local falhou=0

    (
        cd "$pasta_teste"
        ./conciliacao
    ) > "$pasta_teste/obtido.txt" 2>&1 || codigo_obtido=$?

    if [ "$codigo_obtido" -ne "$codigo_esperado" ]; then
        echo "Codigo incorreto em '$nome':"
        echo "Esperado: $codigo_esperado | Obtido: $codigo_obtido"
        falhou=1
    fi

    if ! diff -u "$pasta_teste/esperado.txt" \
                 "$pasta_teste/obtido.txt"; then
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

# Cenario 1: ordem diferente, ausencia e sem previsao

preparar_base

cat > "$pasta_teste/esperado.txt" <<'FIM'
Carregamento dos pagamentos.
Conferencia dos pagamentos esperados:
Pagamento: P001 | Esperado: 100.50 | Recebido: 90.00 | Diferenca: -10.50 | Status: abaixo do esperado
Pagamento: P002 | Status: sem recebimento
Pagamento: P003 | Esperado: 75.25 | Recebido: 75.25 | Diferenca: +0.00 | Status: conferido
Recebimentos sem previsao:
Pagamento: P004 | Recebido: 50.00 | Status: sem previsao
FIM

acrescentar_resumo 1 0 1 1 1 375.75 215.25 -160.50
verificar_cenario "ordem diferente, ausencia e sem previsao" 0

# Cenario 2: duplicidade nos recebidos

preparar_base

cat > "$pasta_teste/dados/recebidos.csv" <<'FIM'
P003;75.25
P001;90.00
P001;10.00
FIM

cat > "$pasta_teste/esperado.txt" <<'FIM'
Carregamento dos pagamentos.
Erro em dados/recebidos.csv, linha 3: identificador duplicado neste arquivo.
FIM

verificar_cenario "duplicidade nos recebidos" 1

# Cenario 3: duplicidade nos esperados

preparar_base

cat > "$pasta_teste/dados/esperados.csv" <<'FIM'
P001;100.50
P001;200.00
FIM

cat > "$pasta_teste/esperado.txt" <<'FIM'
Carregamento dos pagamentos.
Erro em dados/esperados.csv, linha 2: identificador duplicado neste arquivo.
FIM

verificar_cenario "duplicidade nos esperados" 1

# Cenario 4: valor invalido nos recebidos

preparar_base

cat > "$pasta_teste/dados/recebidos.csv" <<'FIM'
P003;75.25
P001;abc
P004;50.00
FIM

cat > "$pasta_teste/esperado.txt" <<'FIM'
Carregamento dos pagamentos.
Erro em dados/recebidos.csv, linha 2: use digitos e ponto decimal, como 100.50.
FIM

verificar_cenario "valor invalido nos recebidos" 1

# Cenario 5: segundo arquivo ausente

preparar_base
rm -- "$pasta_teste/dados/recebidos.csv"

cat > "$pasta_teste/esperado.txt" <<'FIM'
Carregamento dos pagamentos.
Erro ao abrir dados/recebidos.csv. Codigo: 35
FIM

verificar_cenario "segundo arquivo ausente" 1

# Cenario 6: exatamente 1000 pagamentos em cada arquivo

for ((i = 1; i <= 1000; i++)); do
    printf 'P%04d;1.00\n' "$i"
done > "$pasta_teste/dados/esperados.csv"

cp "$pasta_teste/dados/esperados.csv" \
   "$pasta_teste/dados/recebidos.csv"

{
    echo "Carregamento dos pagamentos."
    echo "Conferencia dos pagamentos esperados:"

    for ((i = 1; i <= 1000; i++)); do
        printf 'Pagamento: P%04d | Esperado: 1.00 | Recebido: 1.00 | Diferenca: +0.00 | Status: conferido\n' "$i"
    done

    echo "Recebimentos sem previsao:"
} > "$pasta_teste/esperado.txt"

acrescentar_resumo 1000 0 0 0 0 1000.00 1000.00 +0.00
verificar_cenario "1000 pagamentos em cada arquivo" 0

# Cenario 7: excesso de capacidade nos recebidos

printf 'P1001;1.00\n' >> "$pasta_teste/dados/recebidos.csv"

cat > "$pasta_teste/esperado.txt" <<'FIM'
Carregamento dos pagamentos.
Erro em dados/recebidos.csv, linha 1001: arquivo excede o limite de 1000 pagamentos.
FIM

verificar_cenario "1001 pagamentos nos recebidos" 1

# Cenario 8: igual, acima e abaixo, com ordem diferente

cat > "$pasta_teste/dados/esperados.csv" <<'FIM'
P001;100.00
P002;100.00
P003;100.00
FIM

cat > "$pasta_teste/dados/recebidos.csv" <<'FIM'
P003;80.00
P001;100.00
P002;120.00
FIM

cat > "$pasta_teste/esperado.txt" <<'FIM'
Carregamento dos pagamentos.
Conferencia dos pagamentos esperados:
Pagamento: P001 | Esperado: 100.00 | Recebido: 100.00 | Diferenca: +0.00 | Status: conferido
Pagamento: P002 | Esperado: 100.00 | Recebido: 120.00 | Diferenca: +20.00 | Status: acima do esperado
Pagamento: P003 | Esperado: 100.00 | Recebido: 80.00 | Diferenca: -20.00 | Status: abaixo do esperado
Recebimentos sem previsao:
FIM

acrescentar_resumo 1 1 1 0 0 300.00 300.00 +0.00
verificar_cenario "igual, acima e abaixo em ordem diferente" 0

# Cenario 9: nenhum identificador em comum

cat > "$pasta_teste/dados/esperados.csv" <<'FIM'
P001;100.00
FIM

cat > "$pasta_teste/dados/recebidos.csv" <<'FIM'
P002;50.00
P003;25.00
FIM

cat > "$pasta_teste/esperado.txt" <<'FIM'
Carregamento dos pagamentos.
Conferencia dos pagamentos esperados:
Pagamento: P001 | Status: sem recebimento
Recebimentos sem previsao:
Pagamento: P002 | Recebido: 50.00 | Status: sem previsao
Pagamento: P003 | Recebido: 25.00 | Status: sem previsao
FIM

acrescentar_resumo 0 0 0 1 2 100.00 75.00 -25.00
verificar_cenario "nenhum identificador em comum" 0

# Cenario 10: maior total esperado permitido

for ((i = 1; i <= 1000; i++)); do
    printf 'P%04d;99999.99\n' "$i"
done > "$pasta_teste/dados/esperados.csv"

for ((i = 1; i <= 1000; i++)); do
    printf 'P%04d;0.00\n' "$i"
done > "$pasta_teste/dados/recebidos.csv"

{
    echo "Carregamento dos pagamentos."
    echo "Conferencia dos pagamentos esperados:"

    for ((i = 1; i <= 1000; i++)); do
        printf 'Pagamento: P%04d | Esperado: 99999.99 | Recebido: 0.00 | Diferenca: -99999.99 | Status: abaixo do esperado\n' "$i"
    done

    echo "Recebimentos sem previsao:"
} > "$pasta_teste/esperado.txt"

acrescentar_resumo 0 0 1000 0 0 99999990.00 0.00 -99999990.00
verificar_cenario "maior total esperado permitido" 0

echo
echo "Resumo: $aprovados aprovados, $reprovados reprovados."

if [ "$reprovados" -gt 0 ]; then
    exit 1
fi

exit 0
