/* Ubuntu/POSIX: relatorio temporario, comparacao por inode e troca atomica.
 * As regras de conciliacao continuam em COBOL. Uma sessao por processo.
 * Caminhos sao strings terminadas em NUL; mensagem tem 160 bytes COBOL.
 * Retornos: 0 = sucesso, 1 = erro de E/S, 2 = destino igual a uma entrada.
 * Nao oferece isolamento contra alteracoes concorrentes das entradas.
 */
#define _POSIX_C_SOURCE 200809L
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MENSAGEM_TAMANHO 160
#define CAMINHO_TAMANHO 257

static int pasta_fd = -1;
static int temporario_fd = -1;
static char destino[CAMINHO_TAMANHO];
static char temporario[80];
static char entradas[2][CAMINHO_TAMANHO];
static struct stat entradas_originais[2];
static unsigned long sequencia;
static int limpeza_registrada;

static void mensagem(char *saida, const char *texto)
{
    size_t n = strlen(texto);
    if (n > MENSAGEM_TAMANHO) n = MENSAGEM_TAMANHO;
    memset(saida, ' ', MENSAGEM_TAMANHO);
    memcpy(saida, texto, n);
}

static void limpar(void)
{
    if (temporario_fd >= 0) {
        close(temporario_fd);
        temporario_fd = -1;
    }
    if (pasta_fd >= 0) {
        if (temporario[0]) unlinkat(pasta_fd, temporario, 0);
        close(pasta_fd);
        pasta_fd = -1;
    }
    temporario[0] = '\0';
}

static int falhar(char *saida, const char *etapa)
{
    int erro = errno;
    char texto[320];
    snprintf(texto, sizeof texto, "%s: %s", etapa, strerror(erro));
    mensagem(saida, texto);
    limpar();
    return 1;
}

static int mesmo_arquivo(const struct stat *a, const struct stat *b)
{
    return a->st_dev == b->st_dev && a->st_ino == b->st_ino;
}

static int verificar_destino(char *saida)
{
    struct stat alvo, link, atual;
    if (fstatat(pasta_fd, destino, &link, AT_SYMLINK_NOFOLLOW) != 0) {
        if (errno == ENOENT) return 0;
        return falhar(saida, "Nao foi possivel consultar o destino");
    }
    if (fstatat(pasta_fd, destino, &alvo, 0) != 0)
        return falhar(saida, "Destino inacessivel");

    for (int i = 0; i < 2; i++) {
        if (stat(entradas[i], &atual) != 0)
            return falhar(saida, "Nao foi possivel consultar a entrada");
        if (mesmo_arquivo(&alvo, &entradas_originais[i]) ||
            mesmo_arquivo(&alvo, &atual)) {
            mensagem(saida, "O destino aponta para um arquivo de entrada.");
            limpar();
            return 2;
        }
    }
    if (S_ISLNK(link.st_mode) || !S_ISREG(link.st_mode)) {
        mensagem(saida, "O destino deve ser um arquivo comum, sem link simbolico.");
        limpar();
        return 1;
    }
    return 0;
}

int relatorio_abrir(const char *esperados, const char *recebidos,
                    const char *caminho, char *saida)
{
    char pasta[CAMINHO_TAMANHO];
    char *barra;
    int codigo;
    limpar();
    mensagem(saida, "");
    if (!limpeza_registrada) {
        if (atexit(limpar) != 0) {
            mensagem(saida, "Nao foi possivel registrar limpeza do temporario.");
            return 1;
        }
        limpeza_registrada = 1;
    }
    if (!*caminho || strlen(caminho) >= sizeof pasta ||
        strlen(esperados) >= sizeof entradas[0] ||
        strlen(recebidos) >= sizeof entradas[1]) {
        mensagem(saida, "Caminho vazio ou acima de 256 bytes.");
        return 1;
    }
    strcpy(entradas[0], esperados);
    strcpy(entradas[1], recebidos);
    for (int i = 0; i < 2; i++) {
        if (stat(entradas[i], &entradas_originais[i]) != 0)
            return falhar(saida, "Nao foi possivel consultar a entrada");
    }
    strcpy(pasta, caminho);
    barra = strrchr(pasta, '/');
    if (barra) {
        strcpy(destino, barra + 1);
        if (barra == pasta) barra[1] = '\0';
        else *barra = '\0';
    } else {
        strcpy(destino, caminho);
        strcpy(pasta, ".");
    }
    if (!*destino || !strcmp(destino, ".") || !strcmp(destino, "..")) {
        mensagem(saida, "Nome de relatorio invalido.");
        return 1;
    }
    pasta_fd = open(pasta, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (pasta_fd < 0) return falhar(saida, "Nao foi possivel abrir a pasta");
    codigo = verificar_destino(saida);
    if (codigo) return codigo;

    for (int tentativa = 0; tentativa < 100; tentativa++) {
        char candidato[80];
        snprintf(candidato, sizeof candidato, ".conciliacao-%ld-%lu.tmp",
                 (long)getpid(), ++sequencia);
        temporario_fd = openat(pasta_fd, candidato,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
        if (temporario_fd >= 0) {
            strcpy(temporario, candidato);
            return 0;
        }
        if (errno != EEXIST)
            return falhar(saida, "Nao foi possivel criar o temporario");
    }
    errno = EEXIST;
    return falhar(saida, "Nao foi possivel criar temporario exclusivo");
}

static int escrever(const char *dados, size_t tamanho)
{
    while (tamanho) {
        ssize_t n = write(temporario_fd, dados, tamanho);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) {
            if (!n) errno = EIO;
            return -1;
        }
        dados += n;
        tamanho -= (size_t)n;
    }
    return 0;
}

int relatorio_linha(const char *linha, const int32_t *tamanho, char *saida)
{
    if (temporario_fd < 0 || *tamanho < 0 || *tamanho > 512) {
        errno = EINVAL;
        return falhar(saida, "Estado ou tamanho de linha invalido");
    }
    if (escrever(linha, (size_t)*tamanho) || escrever("\n", 1))
        return falhar(saida, "Falha na gravacao do temporario");
    mensagem(saida, "");
    return 0;
}

int relatorio_confirmar(char *saida)
{
    int codigo, fd;
    if (temporario_fd < 0) {
        errno = EINVAL;
        return falhar(saida, "Relatorio nao iniciado");
    }
    if (fsync(temporario_fd) != 0)
        return falhar(saida, "Falha ao sincronizar o temporario");
    fd = temporario_fd;
    temporario_fd = -1;
    if (close(fd) != 0)
        return falhar(saida, "Falha ao fechar o temporario");
    codigo = verificar_destino(saida);
    if (codigo) return codigo;
    if (renameat(pasta_fd, temporario, pasta_fd, destino) != 0)
        return falhar(saida, "Falha ao publicar o relatorio");
    temporario[0] = '\0';
    limpar();
    mensagem(saida, "");
    return 0;
}
