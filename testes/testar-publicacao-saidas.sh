#!/usr/bin/env bash
set -euo pipefail
raiz="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pasta="$(mktemp -d)"
trap 'rm -rf -- "$pasta"' EXIT
cobc -x -free -o "$pasta/conciliacao" "$raiz/conciliacao.cob" \
    "$raiz/validar-monetario.cob" "$raiz/entrada-segura.c" "$raiz/relatorio-seguro.c"
cat > "$pasta/falhas.c" <<'C'
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
static int modo(const char *s) { const char *v=getenv("FALHA_TESTE"); return v && !strcmp(v,s); }
int renameat(int a,const char*b,int c,const char*d) {
    static int n; ++n;
    if ((n==2 && (modo("rename2") || modo("recuperacao"))) ||
        (n==3 && modo("recuperacao"))) { errno=EIO; return -1; }
    int(*f)(int,const char*,int,const char*)=dlsym(RTLD_NEXT,"renameat");
    return f(a,b,c,d);
}
int fsync(int fd) {
    static int n; ++n;
    if(n==2 && modo("fsync2")) {errno=EIO;return -1;}
    int(*f)(int)=dlsym(RTLD_NEXT,"fsync");return f(fd);
}
int linkat(int a,const char*b,int c,const char*d,int flags) {
    if(modo("reserva")) {errno=EPERM;return -1;}
    int(*f)(int,const char*,int,const char*,int)=dlsym(RTLD_NEXT,"linkat");
    return f(a,b,c,d,flags);
}
C
gcc -shared -fPIC -o "$pasta/falhas.so" "$pasta/falhas.c" -ldl
python3 - "$pasta" <<'PY'
import pathlib, subprocess, os, sys
base=pathlib.Path(sys.argv[1]);count=0

def preparar():
    global count
    count+=1;p=base/str(count);p.mkdir()
    (p/'e').write_text('P1;100.00\n');(p/'r').write_text('P1;90.00\n')
    return p

def executar(p,rel='rel',res='res',fault=''):
    env=dict(os.environ)
    if fault:env.update(LD_PRELOAD=str(base/'falhas.so'),FALHA_TESTE=fault)
    q=subprocess.run([str(base/'conciliacao'),'e','r',rel,res],cwd=p,env=env,capture_output=True,text=True)
    assert (p/'e').read_text()=='P1;100.00\n'
    assert (p/'r').read_text()=='P1;90.00\n'
    if q.returncode:assert 'Conferencia concluida.' not in q.stdout
    assert not list(p.glob('.conciliacao-*.tmp'))
    return q

for alias in ['./saida','sub/../saida','ABSOLUTO','link/saida']:
    p=preparar();(p/'sub').mkdir();(p/'link').symlink_to(p,target_is_directory=True)
    target=str(p/'saida') if alias=='ABSOLUTO' else alias
    q=executar(p,'saida',target)
    assert q.returncode==2,(alias,q.stdout)
    assert not (p/'saida').exists()
    print('PASSOU: destino inexistente equivalente '+alias)

for tipo in ['hardlink','symlink']:
    p=preparar();(p/'rel').write_text('ANTERIOR')
    if tipo=='hardlink':os.link(p/'rel',p/'res')
    else:(p/'res').symlink_to('rel')
    q=executar(p);assert q.returncode!=0
    assert (p/'rel').read_text()=='ANTERIOR' and (p/'res').read_text()=='ANTERIOR'
    print('PASSOU: colisao entre saidas '+tipo)

for fault in ['fsync2','rename2']:
    for oldrel,oldres in [(False,False),(True,False),(False,True),(True,True)]:
        p=preparar()
        if oldrel:(p/'rel').write_text('REL ANTERIOR');inode=(p/'rel').stat().st_ino
        if oldres:(p/'res').write_text('TSV ANTERIOR')
        q=executar(p,fault=fault);assert q.returncode==1,q.stdout
        assert (p/'rel').exists()==oldrel and (p/'res').exists()==oldres
        if oldrel:assert (p/'rel').read_text()=='REL ANTERIOR' and (p/'rel').stat().st_ino==inode
        if oldres:assert (p/'res').read_text()=='TSV ANTERIOR'
        assert not list(p.glob('.conciliacao-*.bak'))
        print(f'PASSOU: {fault}, anteriores={oldrel}/{oldres}')

p=preparar();(p/'rel').write_text('REL ANTERIOR');(p/'res').write_text('TSV ANTERIOR')
q=executar(p,fault='reserva');assert q.returncode==1
assert (p/'rel').read_text()=='REL ANTERIOR' and (p/'res').read_text()=='TSV ANTERIOR'
assert not list(p.glob('.conciliacao-*.bak'))
print('PASSOU: falha na reserva preserva ambas as saidas')

p=preparar();(p/'rel').write_text('REL ANTERIOR');(p/'res').write_text('TSV ANTERIOR')
q=executar(p,fault='recuperacao');assert q.returncode==1
backups=list(p.glob('.conciliacao-*.bak'));assert len(backups)==1
assert backups[0].read_text()=='REL ANTERIOR' and backups[0].name in q.stdout
assert (p/'res').read_text()=='TSV ANTERIOR'
print('PASSOU: falha na recuperacao conserva reserva e informa o nome')

p=preparar();(p/'rel').write_text('REL ANTERIOR');(p/'res').write_text('TSV ANTERIOR')
q=executar(p);assert q.returncode==0,q.stdout
assert (p/'res').read_text().startswith('VERSAO\t1\n')
assert (p/'rel').read_text().endswith('Conferencia concluida.\n')
assert not list(p.glob('.conciliacao-*.bak'))
print('PASSOU: sucesso publica ambas as saidas e remove reserva')
print(f'Resumo: {count} aprovados, 0 reprovados.')
PY
