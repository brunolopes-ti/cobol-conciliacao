#!/usr/bin/env bash
set -euo pipefail

raiz_projeto="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pasta_teste="$(mktemp -d)"
trap 'rm -rf -- "$pasta_teste"' EXIT

printf 'Compilando a protecao dos arquivos...\n'
cobc -x -free -o "$pasta_teste/conciliacao" \
    "$raiz_projeto/conciliacao.cob" \
    "$raiz_projeto/validar-monetario.cob" \
    "$raiz_projeto/entrada-segura.c" \
    "$raiz_projeto/relatorio-seguro.c"

# Injetores exclusivos dos testes: falhas deterministicas de sincronizacao
# e publicacao. Nao sao vinculados ao executavel da aplicacao.
cat > "$pasta_teste/falha-sync.c" <<'C'
#include <errno.h>
int fsync(int fd) { (void)fd; errno = EIO; return -1; }
C

cat > "$pasta_teste/falha-rename.c" <<'C'
#include <errno.h>
int renameat(int a, const char *b, int c, const char *d) {
    (void)a; (void)b; (void)c; (void)d; errno = EIO; return -1;
}
C

gcc -shared -fPIC -o "$pasta_teste/falha-sync.so" "$pasta_teste/falha-sync.c"
gcc -shared -fPIC -o "$pasta_teste/falha-rename.so" "$pasta_teste/falha-rename.c"

aprovados=0
reprovados=0
numero=0

preparar() {
    numero=$((numero + 1))
    caso="$pasta_teste/caso-$numero"
    mkdir -p "$caso/dados" "$caso/subpasta"
    printf 'P001;100.00\n' > "$caso/dados/esperados.csv"
    printf 'P001;80.00\n' > "$caso/dados/recebidos.csv"
    cp "$caso/dados/esperados.csv" "$caso/copia-esperados"
    cp "$caso/dados/recebidos.csv" "$caso/copia-recebidos"
    printf 'RELATORIO ANTERIOR\n' > "$caso/relatorio.txt"
    cp "$caso/relatorio.txt" "$caso/copia-relatorio"
    modo=normal
    biblioteca=""
    preservar_relatorio=1
}

executar() {
    local nome="$1" esperado="$2"
    shift 2

    local codigo=0 falhou=0

    (
        cd "$caso"

        if [ "$modo" = escrita ]; then
            # write() falha com EFBIG; ignorar SIGXFSZ permite tratar o erro.
            trap '' XFSZ
            ulimit -f 0
            exec "$pasta_teste/conciliacao" "$@" > /dev/null 2>&1

        elif [ -n "$biblioteca" ]; then
            exec env LD_PRELOAD="$biblioteca" \
                "$pasta_teste/conciliacao" "$@"

        else
            exec "$pasta_teste/conciliacao" "$@"
        fi
    ) > "$caso/saida.txt" 2>&1 || codigo=$?

    if [ "$codigo" -ne "$esperado" ]; then
        printf 'Codigo esperado: %s; obtido: %s\n' "$esperado" "$codigo"
        falhou=1
    fi

    cmp -s "$caso/dados/esperados.csv" "$caso/copia-esperados" || falhou=1
    cmp -s "$caso/dados/recebidos.csv" "$caso/copia-recebidos" || falhou=1

    if [ "$preservar_relatorio" -eq 1 ]; then
        cmp -s "$caso/relatorio.txt" "$caso/copia-relatorio" || falhou=1
    fi

    if [ -n "$(find "$caso" -name '.conciliacao-*.tmp' -print -quit)" ]; then
        echo 'Temporario nao foi removido.'
        falhou=1
    fi

    if [ "$esperado" -ne 0 ] &&
       grep -Fxq 'Conferencia concluida.' "$caso/saida.txt"; then
        echo 'Sucesso anunciado apesar da falha.'
        falhou=1
    fi

    if [ "$esperado" -eq 0 ]; then
        grep -Fxq 'Conferencia concluida.' \
            "$caso/relatorio.txt" || falhou=1

        grep -Fxq 'Saldo global: -20.00' \
            "$caso/relatorio.txt" || falhou=1

        cmp -s "$caso/antigo-via-link" \
            "$caso/copia-relatorio" || falhou=1

        if [ "$caso/relatorio.txt" -ef "$caso/antigo-via-link" ]; then
            echo 'Relatorio foi sobrescrito em vez de substituido.'
            falhou=1
        fi
    fi

    if [ -e "$caso/copia-alvo" ]; then
        cmp -s "$caso/alvo.txt" "$caso/copia-alvo" || falhou=1
        [ -L "$caso/link-saida" ] || falhou=1
    fi

    if [ -L "$caso/link-quebrado" ] &&
       [ -e "$caso/nao-existe" ]; then
        falhou=1
    fi

    if [ "$falhou" -eq 0 ]; then
        echo "PASSOU: $nome"
        aprovados=$((aprovados + 1))
    else
        echo "FALHOU: $nome"
        cat "$caso/saida.txt"
        reprovados=$((reprovados + 1))
    fi
}

preparar
executar 'alias com ponto nos esperados' 2 \
    dados/esperados.csv \
    dados/recebidos.csv \
    ./dados/esperados.csv \
    resultado.tsv

preparar
executar 'alias com dois pontos nos recebidos' 2 \
    dados/esperados.csv \
    dados/recebidos.csv \
    subpasta/../dados/recebidos.csv \
    resultado.tsv

preparar
executar 'caminho absoluto da entrada' 2 \
    dados/esperados.csv \
    dados/recebidos.csv \
    "$caso/dados/esperados.csv" \
    resultado.tsv

preparar
ln -s dados/esperados.csv "$caso/link-saida"
executar 'link simbolico para esperados' 2 \
    dados/esperados.csv \
    dados/recebidos.csv \
    link-saida \
    resultado.tsv

preparar
ln -s dados/recebidos.csv "$caso/link-saida"
executar 'link simbolico para recebidos' 2 \
    dados/esperados.csv \
    dados/recebidos.csv \
    link-saida \
    resultado.tsv

preparar
ln "$caso/dados/esperados.csv" "$caso/link-saida"
executar 'hard link para esperados' 2 \
    dados/esperados.csv \
    dados/recebidos.csv \
    link-saida \
    resultado.tsv

preparar
ln "$caso/dados/recebidos.csv" "$caso/link-saida"
executar 'hard link para recebidos' 2 \
    dados/esperados.csv \
    dados/recebidos.csv \
    link-saida \
    resultado.tsv

preparar
ln -s dados "$caso/atalho"
executar 'alias por diretorio simbolico' 2 \
    dados/esperados.csv \
    dados/recebidos.csv \
    atalho/esperados.csv \
    resultado.tsv

preparar
rm "$caso/relatorio.txt"
ln "$caso/dados/esperados.csv" "$caso/relatorio.txt"
cp "$caso/relatorio.txt" "$caso/copia-relatorio"
executar 'protecao tambem sem argumentos' 2

preparar
printf 'CONTEUDO EXTERNO\n' > "$caso/alvo.txt"
cp "$caso/alvo.txt" "$caso/copia-alvo"
ln -s alvo.txt "$caso/link-saida"
executar 'link simbolico para outro arquivo rejeitado' 1 \
    dados/esperados.csv \
    dados/recebidos.csv \
    link-saida \
    resultado.tsv

preparar
ln -s nao-existe "$caso/link-quebrado"
executar 'link simbolico quebrado rejeitado' 1 \
    dados/esperados.csv \
    dados/recebidos.csv \
    link-quebrado \
    resultado.tsv

preparar
modo=escrita
executar 'falha na escrita preserva relatorio anterior' 1

preparar
biblioteca="$pasta_teste/falha-sync.so"
executar 'falha no fsync preserva relatorio anterior' 1

preparar
biblioteca="$pasta_teste/falha-rename.so"
executar 'falha na publicacao preserva relatorio anterior' 1

preparar
ln "$caso/relatorio.txt" "$caso/antigo-via-link"
preservar_relatorio=0
executar 'sucesso substitui arquivo sem alterar inode antigo' 0

printf '\nResumo: %s aprovados, %s reprovados.\n' \
    "$aprovados" "$reprovados"

[ "$reprovados" -eq 0 ]
