#!/usr/bin/env bash
set -euo pipefail

raiz_projeto="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pasta_teste="$(mktemp -d)"

trap 'rm -rf -- "$pasta_teste"' EXIT

echo "Compilando o leitor..."
cobc -x -free -o "$pasta_teste/leitor" \
    "$raiz_projeto/leitor.cob" \
    "$raiz_projeto/validar-monetario.cob"

mkdir -p "$pasta_teste/dados"

aprovados=0
reprovados=0

verificar_cenario() {
    local nome="$1"
    local codigo_esperado="$2"
    local codigo_obtido=0
    local falhou=0

    (
        cd "$pasta_teste"
        ./leitor
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

# Cenario 1: arquivo valido

cp "$raiz_projeto/testes/cenarios/validos.csv" \
   "$pasta_teste/dados/esperados.csv"

cat > "$pasta_teste/esperado.txt" <<'FIM'
Leitura dos pagamentos esperados.
Pagamento: P001 | Valor esperado: 100.50
Pagamento: P002 | Valor esperado: 200.00
Pagamento: P003 | Valor esperado: 75.25
Total de registros lidos: 3
Registros validos: 3
Registros invalidos: 0
FIM

verificar_cenario "arquivo valido" 0

# Cenario 2: arquivo misto

cp "$raiz_projeto/testes/cenarios/mistos.csv" \
   "$pasta_teste/dados/esperados.csv"

cat > "$pasta_teste/esperado.txt" <<'FIM'
Leitura dos pagamentos esperados.
Pagamento: P001 | Valor esperado: 100.50
Erro na linha 2: use digitos e ponto decimal, como 100.50.
Erro na linha 3: utilize no maximo 2 casas decimais.
Erro na linha 4: informe um valor entre 0 e 99999.99.
Pagamento: P005 | Valor esperado: 100.50
Pagamento: P006 | Valor esperado: 0.00
Pagamento: P007 | Valor esperado: 99999.99
Erro na linha 8: informe exatamente um ponto e virgula.
Total de registros lidos: 8
Registros validos: 4
Registros invalidos: 4
FIM

verificar_cenario "arquivo misto" 1

# Cenario 3: arquivo vazio

cp "$raiz_projeto/testes/cenarios/vazio.csv" \
   "$pasta_teste/dados/esperados.csv"

cat > "$pasta_teste/esperado.txt" <<'FIM'
Leitura dos pagamentos esperados.
Erro: arquivo de pagamentos esperados esta vazio.
FIM

verificar_cenario "arquivo vazio" 1

# Cenario 4: linha longa

cp "$raiz_projeto/testes/cenarios/linha-longa.csv" \
   "$pasta_teste/dados/esperados.csv"

cat > "$pasta_teste/esperado.txt" <<'FIM'
Leitura dos pagamentos esperados.
Erro na linha 1: linha excede o limite de 256 caracteres.
Total de registros lidos: 1
Registros validos: 0
Registros invalidos: 1
FIM

verificar_cenario "linha longa" 1

# Cenario 5: arquivo ausente

rm -- "$pasta_teste/dados/esperados.csv"

cat > "$pasta_teste/esperado.txt" <<'FIM'
Leitura dos pagamentos esperados.
Erro ao abrir arquivo. Codigo: 35
FIM

verificar_cenario "arquivo ausente" 1

echo
echo "Resumo: $aprovados aprovados, $reprovados reprovados."

if [ "$reprovados" -gt 0 ]; then
    exit 1
fi

exit 0
