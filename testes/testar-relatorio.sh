#!/usr/bin/env bash
set -euo pipefail

raiz_projeto="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pasta_teste="$(mktemp -d)"

trap 'rm -rf -- "$pasta_teste"' EXIT

echo "Compilando os testes do relatorio..."
cobc -x -free -o "$pasta_teste/conciliacao" \
    "$raiz_projeto/conciliacao.cob" \
    "$raiz_projeto/validar-monetario.cob"

mkdir -p "$pasta_teste/dados"

aprovados=0
reprovados=0
codigo_obtido=0

executar_programa() {
    codigo_obtido=0

    (
        cd "$pasta_teste"
        ./conciliacao
    ) > "$pasta_teste/obtido.txt" 2>&1 || codigo_obtido=$?
}

registrar_resultado() {
    local nome="$1"
    local falhou="$2"

    if [ "$falhou" -eq 0 ]; then
        echo "PASSOU: $nome"
        aprovados=$((aprovados + 1))
    else
        echo "FALHOU: $nome"
        cat "$pasta_teste/obtido.txt"
        reprovados=$((reprovados + 1))
    fi
}

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

cat > "$pasta_teste/relatorio-esperado.txt" <<'FIM'
Conferencia dos pagamentos esperados:
Pagamento: P001 | Esperado: 100.50 | Recebido: 90.00 | Diferenca: -10.50 | Status: abaixo do esperado
Pagamento: P002 | Status: sem recebimento
Pagamento: P003 | Esperado: 75.25 | Recebido: 75.25 | Diferenca: +0.00 | Status: conferido
Recebimentos sem previsao:
Pagamento: P004 | Recebido: 50.00 | Status: sem previsao
Resumo da conciliacao:
Conferidos: 1
Acima do esperado: 0
Abaixo do esperado: 1
Sem recebimento: 1
Sem previsao: 1
Total esperado: 375.75
Total recebido: 215.25
Saldo global: -160.50
Conferencia concluida.
FIM

# Cenario 1: conteudo completo do relatorio

executar_programa
falhou=0

if [ "$codigo_obtido" -ne 0 ]; then
    echo "Esperado codigo 0, obtido $codigo_obtido."
    falhou=1
fi

if ! diff -u "$pasta_teste/relatorio-esperado.txt" \
             "$pasta_teste/relatorio.txt"; then
    falhou=1
fi

registrar_resultado "conteudo completo do relatorio" "$falhou"

# Cenario 2: entrada invalida preserva relatorio anterior

printf 'RELATORIO ANTERIOR\n' > "$pasta_teste/relatorio.txt"
cp "$pasta_teste/relatorio.txt" "$pasta_teste/anterior.txt"

printf 'P001;abc\n' > "$pasta_teste/dados/recebidos.csv"

executar_programa
falhou=0

if [ "$codigo_obtido" -ne 1 ]; then
    echo "Esperado codigo 1, obtido $codigo_obtido."
    falhou=1
fi

if ! grep -Fxq \
    "Erro em dados/recebidos.csv, linha 1: use digitos e ponto decimal, como 100.50." \
    "$pasta_teste/obtido.txt"; then
    falhou=1
fi

if ! diff -u "$pasta_teste/anterior.txt" \
             "$pasta_teste/relatorio.txt"; then
    falhou=1
fi

registrar_resultado "entrada invalida preserva relatorio anterior" "$falhou"

# Cenario 3: caminho do relatorio ocupado por uma pasta

printf 'P001;100.50\n' > "$pasta_teste/dados/recebidos.csv"

rm -- "$pasta_teste/relatorio.txt"
mkdir "$pasta_teste/relatorio.txt"

executar_programa
falhou=0

if [ "$codigo_obtido" -ne 1 ]; then
    echo "Esperado codigo 1, obtido $codigo_obtido."
    falhou=1
fi

if ! grep -Fq "Erro ao abrir relatorio.txt. Codigo:" \
    "$pasta_teste/obtido.txt"; then
    falhou=1
fi

if grep -Fxq "Conferencia concluida." "$pasta_teste/obtido.txt"; then
    echo "O programa anunciou sucesso apesar da falha."
    falhou=1
fi

registrar_resultado "falha ao abrir relatorio" "$falhou"

echo
echo "Resumo: $aprovados aprovados, $reprovados reprovados."

if [ "$reprovados" -gt 0 ]; then
    exit 1
fi

exit 0
