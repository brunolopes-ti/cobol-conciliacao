#!/usr/bin/env bash
set -euo pipefail

raiz_projeto="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

suites_aprovadas=0
suites_reprovadas=0

executar_suite() {
    local nome="$1"
    local arquivo="$2"
    local codigo=0

    echo
    echo "Executando suite: $nome"

    if bash "$raiz_projeto/testes/$arquivo"; then
        suites_aprovadas=$((suites_aprovadas + 1))
        echo "SUITE APROVADA: $nome"
    else
        codigo=$?
        suites_reprovadas=$((suites_reprovadas + 1))
        echo "SUITE REPROVADA: $nome | Codigo: $codigo"
    fi
}

executar_suite "leitor" "testar-leitor.sh"
executar_suite "interativo" "testar-ola.sh"
executar_suite "conciliacao" "testar-conciliacao.sh"
executar_suite "relatorio" "testar-relatorio.sh"
executar_suite "resultado estruturado" "testar-resultado.sh"
executar_suite "argumentos" "testar-argumentos.sh"
executar_suite "protecao dos arquivos" "testar-protecao-arquivos.sh"
executar_suite "limites das entradas" "testar-limites.sh"

echo
echo "Resumo geral:"
echo "Suites aprovadas: $suites_aprovadas"
echo "Suites reprovadas: $suites_reprovadas"

if [ "$suites_reprovadas" -gt 0 ]; then
    echo "VERIFICACAO COMPLETA: FALHOU"
    exit 1
fi

echo "VERIFICACAO COMPLETA: PASSOU"
exit 0
