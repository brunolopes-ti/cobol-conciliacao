/* Ubuntu/Linux. Leitura limitada em memoria, sem descartar silenciosamente
 * o excesso. Linhas grandes sao consumidas ate LF/EOF antes do retorno.
 * Codigos: 0 sucesso; 4 limite; 9 controle/UTF-8 invalido; 10 EOF;
 * 30 erro de E/S; 35 arquivo inexistente. Inteiros COBOL: BINARY-LONG.
 */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>

static FILE *arquivo;

static int proximo_utf8(const unsigned char *s, int n, int *pos, uint32_t *cp)
{
    unsigned char c = s[(*pos)++];
    int extras;
    uint32_t minimo;
    if (c < 0x80) { *cp = c; return 0; }
    if (c >= 0xc2 && c <= 0xdf) { extras=1; *cp=c&31; minimo=0x80; }
    else if (c >= 0xe0 && c <= 0xef) { extras=2; *cp=c&15; minimo=0x800; }
    else if (c >= 0xf0 && c <= 0xf4) { extras=3; *cp=c&7; minimo=0x10000; }
    else return -1;
    if (n - *pos < extras) return -1;
    while (extras--) {
        c = s[(*pos)++];
        if ((c & 0xc0) != 0x80) return -1;
        *cp = (*cp << 6) | (c & 63);
    }
    return (*cp < minimo || *cp > 0x10ffff ||
           (*cp >= 0xd800 && *cp <= 0xdfff)) ? -1 : 0;
}

static int texto_valido(const char *s, int n)
{
    int pos=0;
    uint32_t cp;
    while (pos < n) {
        if (proximo_utf8((const unsigned char *)s,n,&pos,&cp)) return 0;
        if (cp < 32 || (cp >= 127 && cp <= 159)) return 0;
    }
    return 1;
}

static void guardar(int c, char *saida, int capacidade, int *n)
{
    if (*n < capacidade) saida[*n]=(char)c;
    if (*n <= capacidade) ++*n;
}

static int ler_linha(FILE *f, char *saida, const int32_t *cap, int32_t *tamanho)
{
    int c, anterior=-1, n=0, houve=0;
    if (!f || *cap < 1 || *cap > 4096) return 30;
    memset(saida,' ',(size_t)*cap);
    *tamanho=0;
    while (1) {
        c=fgetc(f);
        if (c==EOF || c=='\n') {
            if (anterior >= 0 && !(c=='\n' && anterior=='\r'))
                guardar(anterior,saida,*cap,&n);
            break;
        }
        houve=1;
        if (anterior >= 0) guardar(anterior,saida,*cap,&n);
        anterior=c;
    }
    if (ferror(f)) return 30;
    if (c==EOF && !houve) return 10;
    *tamanho=n > *cap ? *cap : n;
    if (n > *cap) return 4;
    if (!texto_valido(saida,n)) return 9;
    return 0;
}

int entrada_abrir(const char *caminho)
{
    if (arquivo) { fclose(arquivo); arquivo=NULL; }
    arquivo=fopen(caminho,"rb");
    return arquivo ? 0 : (errno==ENOENT ? 35 : 30);
}

int entrada_ler(char *saida, const int32_t *cap, int32_t *tamanho)
{
    return ler_linha(arquivo,saida,cap,tamanho);
}

int entrada_fechar(void)
{
    FILE *f=arquivo;
    arquivo=NULL;
    return (!f || fclose(f)!=0) ? 30 : 0;
}

int entrada_terminal(char *saida, const int32_t *cap, int32_t *tamanho)
{
    fflush(stdout);
    return ler_linha(stdin,saida,cap,tamanho);
}

/* /proc fornece os argumentos originais completos, incluindo espacos finais.
 * Evita truncamento previo de ACCEPT FROM ARGUMENT-VALUE em campo fixo.
 */
int entrada_argumento(const int32_t *indice, char *saida,
                      const int32_t *cap, int32_t *tamanho)
{
    int c, atual=0, n=0, achou=0;
    FILE *f;
    if (*indice < 1 || *cap < 1 || *cap > 4096) return 30;
    memset(saida,' ',(size_t)*cap);
    *tamanho=0;
    f=fopen("/proc/self/cmdline","rb");
    if (!f) return 30;
    while ((c=fgetc(f))!=EOF) {
        if (atual==*indice) {
            achou=1;
            if (!c) break;
            guardar(c,saida,*cap,&n);
        }
        if (!c) ++atual;
    }
    int erro=ferror(f);
    if (fclose(f)!=0) erro=1;
    if (erro || !achou) return 30;
    *tamanho=n > *cap ? *cap : n;
    if (n > *cap) return 4;
    if (!texto_valido(saida,n)) return 9;
    return 0;
}

static int erro_id(char *saida,const char *texto)
{
    size_t n=strlen(texto);
    memset(saida,' ',80);
    memcpy(saida,texto,n > 80 ? 80 : n);
    return 1;
}

int entrada_identificador(const char *id, const int32_t *tamanho, char *erro)
{
    int pos=0, caracteres=0, visivel=0;
    uint32_t cp;
    memset(erro,' ',80);
    if (*tamanho < 1) return erro_id(erro,"identificador vazio.");
    if (*tamanho > 256) return erro_id(erro,"identificador muito longo.");
    if (id[0]==' ' || id[*tamanho-1]==' ')
        return erro_id(erro,"identificador nao deve ter espacos nas extremidades.");
    while (pos < *tamanho) {
        if (proximo_utf8((const unsigned char *)id,*tamanho,&pos,&cp))
            return erro_id(erro,"identificador deve usar UTF-8 valido.");
        if (cp < 32 || (cp>=127 && cp<=159) || cp==';')
            return erro_id(erro,"identificador contem caractere proibido.");
        /* Espacos Unicode, alem do espaco ASCII. */
        if (!(cp==32 || cp==0x1680 || (cp>=0x2000 && cp<=0x200a) ||
              cp==0x2028 || cp==0x2029 || cp==0x205f || cp==0x3000))
            visivel=1;
        if (++caracteres > 50)
            return erro_id(erro,"identificador excede o limite de 50 caracteres.");
    }
    if (!visivel) return erro_id(erro,"identificador vazio.");
    return 0;
}
