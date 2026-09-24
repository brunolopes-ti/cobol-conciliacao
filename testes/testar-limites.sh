#!/usr/bin/env bash
set -euo pipefail
raiz_projeto="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pasta_teste="$(mktemp -d)"
trap 'rm -rf -- "$pasta_teste"' EXIT
command -v python3 >/dev/null || { echo 'Erro: python3 necessario para os testes.'; exit 1; }
echo 'Compilando os testes dos limites...'
for programa in ola leitor conciliacao; do
    fontes=("$raiz_projeto/$programa.cob" "$raiz_projeto/validar-monetario.cob" "$raiz_projeto/entrada-segura.c")
    if [ "$programa" = conciliacao ]; then
        fontes+=("$raiz_projeto/relatorio-seguro.c")
    fi
    cobc -x -free -o "$pasta_teste/$programa" "${fontes[@]}"
done
python3 - "$pasta_teste" <<'PY'
import pathlib
import subprocess
import sys

raiz = pathlib.Path(sys.argv[1])
aprovados = 0
reprovados = 0
numero = 0

def testar(nome, programa, codigo, mensagens, *, esperados=b'P001;100.00\n',
           recebidos=b'P001;80.00\n', entrada=b'', argumentos=(), ausentes=()):
    global aprovados, reprovados, numero
    numero += 1
    caso = raiz / f'caso-{numero}'
    (caso / 'dados').mkdir(parents=True)
    (caso / 'dados/esperados.csv').write_bytes(esperados)
    (caso / 'dados/recebidos.csv').write_bytes(recebidos)
    anterior = b'RELATORIO ANTERIOR\n'
    (caso / 'relatorio.txt').write_bytes(anterior)
    try:
        p = subprocess.run([str(raiz / programa), *argumentos], cwd=caso,
                           input=entrada, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=10)
        saida = p.stdout.decode('utf-8', errors='replace')
        assert p.returncode == codigo, f'Codigo {p.returncode}; esperado {codigo}'
        for mensagem in mensagens:
            assert mensagem in saida, f'Mensagem ausente: {mensagem}'
        for mensagem in ausentes:
            assert mensagem not in saida, f'Mensagem indevida: {mensagem}'
        assert (caso / 'dados/esperados.csv').read_bytes() == esperados
        assert (caso / 'dados/recebidos.csv').read_bytes() == recebidos
        if programa != 'conciliacao' or codigo != 0:
            assert (caso / 'relatorio.txt').read_bytes() == anterior, 'Relatorio alterado'
        assert not list(caso.glob('.conciliacao-*.tmp')), 'Temporario restante'
        aprovados += 1
        print(f'PASSOU: {nome}')
    except (AssertionError, subprocess.TimeoutExpired) as e:
        reprovados += 1
        print(f'FALHOU: {nome}: {e}')
        if 'saida' in locals():
            print(saida)

limite_id = 'identificador excede o limite de 50 caracteres.'
limite_linha = 'linha excede o limite de 256 bytes.'
controle = 'linha contem controle ou UTF-8 invalido.'

# Exercitar o mesmo contrato nos dois consumidores de CSV.
for programa in ('leitor', 'conciliacao'):
    for nome, texto, codigo, mensagem in (
        ('ID ASCII de 50 caracteres', 'A'*50+';100.00\n', 0, 'Pagamento: '+ 'A'*50),
        ('ID ASCII de 51 caracteres', 'A'*51+';100.00\n', 1, limite_id),
        ('ID acentuado de 50 caracteres', 'Á'*50+';100.00\n', 0, 'Pagamento: '+ 'Á'*50),
        ('ID acentuado de 51 caracteres', 'Á'*51+';100.00\n', 1, limite_id),
        ('ID UTF-8 de quatro bytes', '😀'*50+';100.00\n', 0, 'Pagamento: '+ '😀'*50),
        ('ID com espaco inicial', ' P001;100.00\n', 1, 'espacos nas extremidades'),
        ('ID com espaco final', 'P001 ;100.00\n', 1, 'espacos nas extremidades'),
        ('linha exata de 256 bytes', 'P001;100.00'+' '*245+'\n', 0, 'Pagamento: P001'),
        ('257 bytes com espacos finais', 'P001;100.00'+' '*246+'\n', 1, limite_linha),
        ('excesso escondido apos 5000 espacos', 'P001;100.00'+' '*5000+'abc\n', 1, limite_linha),
        ('CRLF', 'P001;100.00\r\n', 0, 'Pagamento: P001'),
        ('ultima linha sem quebra', 'P001;100.00', 0, 'Pagamento: P001'),
        ('tabulacao no ID', 'P\t001;100.00\n', 1, controle),
        ('NUL no valor', 'P001;100.00\0abc\n', 1, controle),
    ):
        testar(f'{programa}: {nome}', programa, codigo, [mensagem], esperados=texto.encode())
    testar(f'{programa}: UTF-8 invalido', programa, 1, [controle], esperados=b'P\xff;100.00\n')

# O leitor deve recuperar a fronteira da linha, sem inventar novos registros.
testar('leitor: continua depois de linha muito longa', 'leitor', 1,
       ['Erro na linha 1:', 'Pagamento: P002', 'Total de registros lidos: 2',
        'Registros validos: 1', 'Registros invalidos: 1'],
       esperados=b'P001;100.00'+b' '*10000+b'abc\nP002;20.00\n')
testar('conciliacao: recebido longo preserva relatorio', 'conciliacao', 1,
       [limite_linha], recebidos=b'P001;80.00'+b' '*5000+b'abc\n')

limite_terminal = 'Erro: entrada excede o limite de 40 bytes.'
status = 'Status: pagamento conferido.'
testar('operador com 40 bytes', 'ola', 0, ['Operador: '+'A'*40, status],
       entrada=b'A'*40+b'\n100\n100\n')
testar('operador longo pede novamente', 'ola', 0,
       [limite_terminal, 'Operador: Bruno', status],
       entrada=b'A'*41+b'\nBruno\n100\n100\n')
testar('operador UTF-8 sem corte parcial', 'ola', 0,
       [limite_terminal, 'Operador: João', status],
       entrada=('Á'*21+'\nJoão\n100\n100\n').encode())
testar('esperado com excesso oculto e nova tentativa', 'ola', 0,
       [limite_terminal, 'Valor esperado: 100.00', status],
       entrada=b'Bruno\n100'+b' '*5000+b'abc\n100\n100\n')
testar('recebido com excesso oculto e nova tentativa', 'ola', 0,
       [limite_terminal, 'Valor recebido: 100.00', status],
       entrada=b'Bruno\n100\n100'+b' '*5000+b'abc\n100\n')
testar('EOF depois de entrada rejeitada', 'ola', 1,
       [limite_terminal, 'Erro: entrada encerrada antes do valor esperado.'],
       entrada=b'Bruno\n'+b'9'*5000, ausentes=['Status:'])
testar('valor com NUL nao vira numero valido', 'ola', 0,
       ['controle ou UTF-8 invalido', status],
       entrada=b'Bruno\n100\0abc\n100\n100\n')
testar('interativo aceita CRLF', 'ola', 0, [status], entrada=b'Bruno\r\n100\r\n100\r\n')
testar('interativo aceita ultima linha sem quebra', 'ola', 0, [status], entrada=b'Bruno\n100\n100')

testar('argumento longo com excesso oculto', 'conciliacao', 2,
       ['Erro: caminho excede 256 posicoes.'],
       argumentos=('dados/esperados.csv'+' '*5000+'x', 'dados/recebidos.csv', 'relatorio.txt'))
testar('argumento com espaco final rejeitado', 'conciliacao', 2,
       ['Erro: caminho nao deve terminar com espaco.'],
       argumentos=('dados/esperados.csv ', 'dados/recebidos.csv', 'relatorio.txt'))

print(f'\nResumo: {aprovados} aprovados, {reprovados} reprovados.')
sys.exit(1 if reprovados else 0)
PY
