#!/usr/bin/env bash
set -euo pipefail

raiz_projeto="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pasta_teste="$(mktemp -d)"

trap 'rm -rf -- "$pasta_teste"' EXIT

echo "Compilando os testes dos argumentos..."
cobc -x -free -o "$pasta_teste/conciliacao" \
    "$raiz_projeto/conciliacao.cob" \
    "$raiz_projeto/validar-monetario.cob" \
    "$raiz_projeto/entrada-segura.c" \
    "$raiz_projeto/relatorio-seguro.c"

aprovados=0
reprovados=0

esperados="$pasta_teste/valores esperados.csv"
recebidos="$pasta_teste/valores recebidos.csv"
relatorio="$pasta_teste/resultado final.txt"
resultado="$pasta_teste/resultado estruturado.tsv"

printf 'P001;100.00\n' > "$esperados"
printf 'P001;80.00\n' > "$recebidos"

cat > "$pasta_teste/relatorio-esperado.txt" <<'FIM'
Conferencia dos pagamentos esperados:
Pagamento: P001 | Esperado: 100.00 | Recebido: 80.00 | Diferenca: -20.00 | Status: abaixo do esperado
Recebimentos sem previsao:
Resumo da conciliacao:
Conferidos: 0
Acima do esperado: 0
Abaixo do esperado: 1
Duplicados: 0
Sem recebimento: 0
Sem previsao: 0
Total esperado: 100.00
Total recebido: 80.00
Saldo global: -20.00
Conferencia concluida.
FIM

verificar_cenario() {
    local nome="$1"
    local codigo_esperado="$2"
    local mensagem="$3"
    shift 3

    local codigo_obtido=0
    local falhou=0

    (
        cd "$pasta_teste"
        ./conciliacao "$@"
    ) > "$pasta_teste/obtido.txt" 2>&1 || codigo_obtido=$?

    if [ "$codigo_obtido" -ne "$codigo_esperado" ]; then
        echo "Esperado codigo $codigo_esperado, obtido $codigo_obtido."
        falhou=1
    fi

    if ! grep -Fxq -- "$mensagem" "$pasta_teste/obtido.txt"; then
        echo "Mensagem esperada nao encontrada:"
        echo "$mensagem"
        falhou=1
    fi

    if [ "$codigo_esperado" -eq 0 ]; then
        if ! diff -u "$pasta_teste/relatorio-esperado.txt" \
                     "$relatorio"; then
            falhou=1
        fi
    fi

    if ! cmp -s "$esperados" "$pasta_teste/copia-esperados.csv"; then
        echo "O arquivo de esperados foi alterado."
        falhou=1
    fi

    if ! cmp -s "$recebidos" "$pasta_teste/copia-recebidos.csv"; then
        echo "O arquivo de recebidos foi alterado."
        falhou=1
    fi

    if [ "$falhou" -eq 0 ]; then
        echo "PASSOU: $nome"
        aprovados=$((aprovados + 1))
    else
        echo "FALHOU: $nome"
        cat "$pasta_teste/obtido.txt"
        reprovados=$((reprovados + 1))
    fi
}

cp "$esperados" "$pasta_teste/copia-esperados.csv"
cp "$recebidos" "$pasta_teste/copia-recebidos.csv"

verificar_cenario \
    "caminhos personalizados com espacos" \
    0 \
    "Conferencia concluida." \
    "$esperados" "$recebidos" "$relatorio" "$resultado"

verificar_cenario \
    "quantidade incorreta de argumentos" \
    2 \
    "Erro: informe zero ou quatro argumentos." \
    "$esperados"

verificar_cenario \
    "caminho vazio" \
    2 \
    "Erro: caminho vazio." \
    "" "$recebidos" "$relatorio" "$resultado"

verificar_cenario \
    "relatorio igual ao caminho de entrada" \
    2 \
    "Erro: relatorio deve ter caminho diferente das entradas." \
    "$esperados" "$recebidos" "$esperados" "$resultado"

verificar_cenario \
    "resultado igual ao caminho de entrada" \
    2 \
    "Erro: resultado deve ter caminho diferente dos demais arquivos." \
    "$esperados" "$recebidos" "$relatorio" "$esperados"

verificar_cenario \
    "resultado igual ao relatorio" \
    2 \
    "Erro: resultado deve ter caminho diferente dos demais arquivos." \
    "$esperados" "$recebidos" "$relatorio" "$relatorio"

printf -v caminho_longo '%0257d' 0

verificar_cenario \
    "caminho acima do limite" \
    2 \
    "Erro: caminho excede 256 posicoes." \
    "$caminho_longo" "$recebidos" "$relatorio" "$resultado"

verificar_cenario \
    "entrada personalizada inexistente" \
    1 \
    "Erro ao abrir inexistente.csv. Codigo: 35" \
    "inexistente.csv" "$recebidos" "$relatorio" "$resultado"

echo
echo "Resumo: $aprovados aprovados, $reprovados reprovados."

if [ "$reprovados" -gt 0 ]; then
    exit 1
fi

exit 0
