/* Ubuntu/POSIX: saida temporaria, comparacao por inode e troca atomica.
 * As regras de conciliacao continuam em COBOL.
 *
 * O estado de cada saida fica isolado em um contexto proprio.
 * Isso permite manter mais de uma saida independente sem compartilhar
 * descritores, destino ou arquivo temporario.
 *
 * Caminhos sao strings terminadas em NUL; mensagem tem 160 bytes COBOL.
 * Retornos: 0 = sucesso, 1 = erro de E/S, 2 = destino igual a protegido.
 *
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
#define MAX_PROTEGIDOS 4

enum {
    CONTEXTO_RELATORIO = 0,
    CONTEXTO_RESULTADO = 1,
    QUANTIDADE_CONTEXTOS = 2
};

typedef struct {
    int pasta_fd;
    int temporario_fd;

    char destino[CAMINHO_TAMANHO];
    char temporario[80];

    char protegidos[MAX_PROTEGIDOS][CAMINHO_TAMANHO];
    struct stat protegidos_originais[MAX_PROTEGIDOS];
    int protegido_original_valido[MAX_PROTEGIDOS];
    int quantidade_protegidos;
    int quantidade_protegidos_obrigatorios;
} saida_segura;

static saida_segura contextos[QUANTIDADE_CONTEXTOS] = {
    {
        .pasta_fd = -1,
        .temporario_fd = -1
    },
    {
        .pasta_fd = -1,
        .temporario_fd = -1
    }
};

static unsigned long sequencia;
static int limpeza_registrada;

static void mensagem(char *saida, const char *texto)
{
    size_t n = strlen(texto);

    if (n > MENSAGEM_TAMANHO)
        n = MENSAGEM_TAMANHO;

    memset(saida, ' ', MENSAGEM_TAMANHO);
    memcpy(saida, texto, n);
}

static void limpar_contexto(saida_segura *contexto)
{
    if (contexto->temporario_fd >= 0) {
        close(contexto->temporario_fd);
        contexto->temporario_fd = -1;
    }

    if (contexto->pasta_fd >= 0) {
        if (contexto->temporario[0]) {
            unlinkat(
                contexto->pasta_fd,
                contexto->temporario,
                0
            );
        }

        close(contexto->pasta_fd);
        contexto->pasta_fd = -1;
    }

    contexto->temporario[0] = '\0';
    contexto->destino[0] = '\0';
    contexto->quantidade_protegidos = 0;
    contexto->quantidade_protegidos_obrigatorios = 0;
}

static void limpar_todos(void)
{
    int i;

    for (i = 0; i < QUANTIDADE_CONTEXTOS; i++)
        limpar_contexto(&contextos[i]);
}

static int falhar(
    saida_segura *contexto,
    char *saida,
    const char *etapa
)
{
    int erro = errno;
    char texto[320];

    snprintf(
        texto,
        sizeof texto,
        "%s: %s",
        etapa,
        strerror(erro)
    );

    mensagem(saida, texto);
    limpar_contexto(contexto);

    return 1;
}

static int mesmo_arquivo(
    const struct stat *a,
    const struct stat *b
)
{
    return
        a->st_dev == b->st_dev &&
        a->st_ino == b->st_ino;
}

static int verificar_destino(
    saida_segura *contexto,
    char *saida
)
{
    struct stat alvo;
    struct stat link;
    struct stat atual;
    int atual_valido;
    int i;

    if (
        fstatat(
            contexto->pasta_fd,
            contexto->destino,
            &link,
            AT_SYMLINK_NOFOLLOW
        ) != 0
    ) {
        if (errno == ENOENT)
            return 0;

        return falhar(
            contexto,
            saida,
            "Nao foi possivel consultar o destino"
        );
    }

    if (
        fstatat(
            contexto->pasta_fd,
            contexto->destino,
            &alvo,
            0
        ) != 0
    ) {
        return falhar(
            contexto,
            saida,
            "Destino inacessivel"
        );
    }

    for (
        i = 0;
        i < contexto->quantidade_protegidos;
        i++
    ) {
        atual_valido = 0;

        if (
            stat(
                contexto->protegidos[i],
                &atual
            ) == 0
        ) {
            atual_valido = 1;
        } else if (
            errno == ENOENT &&
            i >= contexto->quantidade_protegidos_obrigatorios
        ) {
            atual_valido = 0;
        } else {
            return falhar(
                contexto,
                saida,
                "Nao foi possivel consultar arquivo protegido"
            );
        }

        if (
            (
                contexto->protegido_original_valido[i] &&
                mesmo_arquivo(
                    &alvo,
                    &contexto->protegidos_originais[i]
                )
            ) ||
            (
                atual_valido &&
                mesmo_arquivo(
                    &alvo,
                    &atual
                )
            )
        ) {
            mensagem(
                saida,
                "O destino aponta para um arquivo protegido."
            );

            limpar_contexto(contexto);
            return 2;
        }
    }

    if (
        S_ISLNK(link.st_mode) ||
        !S_ISREG(link.st_mode)
    ) {
        mensagem(
            saida,
            "O destino deve ser um arquivo comum, sem link simbolico."
        );

        limpar_contexto(contexto);
        return 1;
    }

    return 0;
}

static int abrir_saida(
    saida_segura *contexto,
    const char *const protegidos[],
    int quantidade_protegidos,
    int quantidade_protegidos_obrigatorios,
    const char *caminho,
    char *saida,
    const char *mensagem_nome_invalido
)
{
    char pasta[CAMINHO_TAMANHO];
    char candidato[80];
    char *barra;
    int codigo;
    int i;
    int tentativa;

    limpar_contexto(contexto);
    mensagem(saida, "");

    if (!limpeza_registrada) {
        if (atexit(limpar_todos) != 0) {
            mensagem(
                saida,
                "Nao foi possivel registrar limpeza do temporario."
            );

            return 1;
        }

        limpeza_registrada = 1;
    }

    if (
        quantidade_protegidos < 1 ||
        quantidade_protegidos > MAX_PROTEGIDOS ||
        quantidade_protegidos_obrigatorios < 0 ||
        quantidade_protegidos_obrigatorios >
            quantidade_protegidos
    ) {
        errno = EINVAL;

        return falhar(
            contexto,
            saida,
            "Quantidade de arquivos protegidos invalida"
        );
    }

    if (
        !*caminho ||
        strlen(caminho) >= sizeof pasta
    ) {
        mensagem(
            saida,
            "Caminho vazio ou acima de 256 bytes."
        );

        return 1;
    }

    for (i = 0; i < quantidade_protegidos; i++) {
        if (
            !protegidos[i] ||
            !*protegidos[i] ||
            strlen(protegidos[i]) >=
                sizeof contexto->protegidos[i]
        ) {
            mensagem(
                saida,
                "Caminho vazio ou acima de 256 bytes."
            );

            return 1;
        }

        strcpy(
            contexto->protegidos[i],
            protegidos[i]
        );

        contexto->protegido_original_valido[i] = 0;

        if (
            stat(
                contexto->protegidos[i],
                &contexto->protegidos_originais[i]
            ) == 0
        ) {
            contexto->protegido_original_valido[i] = 1;
        } else if (
            errno == ENOENT &&
            i >= quantidade_protegidos_obrigatorios
        ) {
            contexto->protegido_original_valido[i] = 0;
        } else {
            return falhar(
                contexto,
                saida,
                "Nao foi possivel consultar arquivo protegido"
            );
        }
    }

    contexto->quantidade_protegidos =
        quantidade_protegidos;

    contexto->quantidade_protegidos_obrigatorios =
        quantidade_protegidos_obrigatorios;

    strcpy(pasta, caminho);

    barra = strrchr(pasta, '/');

    if (barra) {
        strcpy(
            contexto->destino,
            barra + 1
        );

        if (barra == pasta)
            barra[1] = '\0';
        else
            *barra = '\0';
    } else {
        strcpy(
            contexto->destino,
            caminho
        );

        strcpy(pasta, ".");
    }

    if (
        !*contexto->destino ||
        !strcmp(contexto->destino, ".") ||
        !strcmp(contexto->destino, "..")
    ) {
        mensagem(
            saida,
            mensagem_nome_invalido
        );

        limpar_contexto(contexto);
        return 1;
    }

    contexto->pasta_fd = open(
        pasta,
        O_RDONLY |
        O_DIRECTORY |
        O_CLOEXEC
    );

    if (contexto->pasta_fd < 0) {
        return falhar(
            contexto,
            saida,
            "Nao foi possivel abrir a pasta"
        );
    }

    /* Mesmo diretorio fisico + mesmo nome: colisao mesmo sem arquivo. */
    for (i = 0; i < QUANTIDADE_CONTEXTOS; i++) {
        saida_segura *outro = &contextos[i];
        struct stat pasta_atual, pasta_outra;
        if (outro == contexto || outro->pasta_fd < 0)
            continue;
        if (fstat(contexto->pasta_fd, &pasta_atual) != 0 ||
            fstat(outro->pasta_fd, &pasta_outra) != 0)
            return falhar(contexto, saida, "Falha ao comparar pastas");
        if (mesmo_arquivo(&pasta_atual, &pasta_outra) &&
            strcmp(contexto->destino, outro->destino) == 0) {
            mensagem(saida, "Relatorio e resultado apontam para o mesmo destino.");
            limpar_contexto(contexto);
            return 2;
        }
    }

    codigo = verificar_destino(
        contexto,
        saida
    );

    if (codigo)
        return codigo;

    for (tentativa = 0; tentativa < 100; tentativa++) {
        snprintf(
            candidato,
            sizeof candidato,
            ".conciliacao-%ld-%lu.tmp",
            (long)getpid(),
            ++sequencia
        );

        contexto->temporario_fd = openat(
            contexto->pasta_fd,
            candidato,
            O_WRONLY |
            O_CREAT |
            O_EXCL |
            O_NOFOLLOW |
            O_CLOEXEC,
            0600
        );

        if (contexto->temporario_fd >= 0) {
            strcpy(
                contexto->temporario,
                candidato
            );

            return 0;
        }

        if (errno != EEXIST) {
            return falhar(
                contexto,
                saida,
                "Nao foi possivel criar o temporario"
            );
        }
    }

    errno = EEXIST;

    return falhar(
        contexto,
        saida,
        "Nao foi possivel criar temporario exclusivo"
    );
}

static int escrever(
    saida_segura *contexto,
    const char *dados,
    size_t tamanho
)
{
    while (tamanho) {
        ssize_t n = write(
            contexto->temporario_fd,
            dados,
            tamanho
        );

        if (
            n < 0 &&
            errno == EINTR
        ) {
            continue;
        }

        if (n <= 0) {
            if (!n)
                errno = EIO;

            return -1;
        }

        dados += n;
        tamanho -= (size_t)n;
    }

    return 0;
}

static int escrever_linha(
    saida_segura *contexto,
    const char *linha,
    const int32_t *tamanho,
    char *saida
)
{
    if (
        contexto->temporario_fd < 0 ||
        *tamanho < 0 ||
        *tamanho > 512
    ) {
        errno = EINVAL;

        return falhar(
            contexto,
            saida,
            "Estado ou tamanho de linha invalido"
        );
    }

    if (
        escrever(
            contexto,
            linha,
            (size_t)*tamanho
        ) ||
        escrever(
            contexto,
            "\n",
            1
        )
    ) {
        return falhar(
            contexto,
            saida,
            "Falha na gravacao do temporario"
        );
    }

    mensagem(saida, "");
    return 0;
}

static int confirmar_saida(
    saida_segura *contexto,
    char *saida,
    const char *mensagem_nao_iniciado,
    const char *mensagem_publicacao
)
{
    int codigo;
    int fd;

    if (contexto->temporario_fd < 0) {
        errno = EINVAL;

        return falhar(
            contexto,
            saida,
            mensagem_nao_iniciado
        );
    }

    if (
        fsync(contexto->temporario_fd) != 0
    ) {
        return falhar(
            contexto,
            saida,
            "Falha ao sincronizar o temporario"
        );
    }

    fd = contexto->temporario_fd;
    contexto->temporario_fd = -1;

    if (close(fd) != 0) {
        return falhar(
            contexto,
            saida,
            "Falha ao fechar o temporario"
        );
    }

    codigo = verificar_destino(
        contexto,
        saida
    );

    if (codigo)
        return codigo;

    if (
        renameat(
            contexto->pasta_fd,
            contexto->temporario,
            contexto->pasta_fd,
            contexto->destino
        ) != 0
    ) {
        return falhar(
            contexto,
            saida,
            mensagem_publicacao
        );
    }

    contexto->temporario[0] = '\0';

    limpar_contexto(contexto);
    mensagem(saida, "");

    return 0;
}

/*
 * Interface publica atual usada pelo COBOL.
 *
 * As assinaturas abaixo permanecem inalteradas para que esta
 * refatoracao nao modifique o contrato existente.
 */

int relatorio_abrir(
    const char *esperados,
    const char *recebidos,
    const char *caminho,
    char *saida
)
{
    const char *protegidos[2] = {
        esperados,
        recebidos
    };

    return abrir_saida(
        &contextos[CONTEXTO_RELATORIO],
        protegidos,
        2,
        2,
        caminho,
        saida,
        "Nome de relatorio invalido."
    );
}

int relatorio_linha(
    const char *linha,
    const int32_t *tamanho,
    char *saida
)
{
    return escrever_linha(
        &contextos[CONTEXTO_RELATORIO],
        linha,
        tamanho,
        saida
    );
}

int relatorio_confirmar(char *saida)
{
    return confirmar_saida(
        &contextos[CONTEXTO_RELATORIO],
        saida,
        "Relatorio nao iniciado",
        "Falha ao publicar o relatorio"
    );
}

/*
 * Interface publica destinada ao resultado estruturado.
 *
 * Usa um contexto independente do relatorio para que os dois
 * arquivos possam ser produzidos sem compartilhar descritores,
 * destino ou arquivo temporario.
 */

int resultado_abrir(
    const char *esperados,
    const char *recebidos,
    const char *relatorio,
    const char *caminho,
    char *saida
)
{
    const char *protegidos[3] = {
        esperados,
        recebidos,
        relatorio
    };

    /*
     * Esperados e recebidos sao obrigatorios.
     * O relatorio pode ainda nao existir quando o resultado e aberto.
     * Ele sera consultado novamente antes da publicacao do resultado.
     */
    return abrir_saida(
        &contextos[CONTEXTO_RESULTADO],
        protegidos,
        3,
        2,
        caminho,
        saida,
        "Nome de resultado invalido."
    );
}

int resultado_linha(
    const char *linha,
    const int32_t *tamanho,
    char *saida
)
{
    return escrever_linha(
        &contextos[CONTEXTO_RESULTADO],
        linha,
        tamanho,
        saida
    );
}

int resultado_confirmar(char *saida)
{
    return confirmar_saida(
        &contextos[CONTEXTO_RESULTADO],
        saida,
        "Resultado nao iniciado",
        "Falha ao publicar o resultado"
    );
}

/* Publicacao coordenada com recuperacao de falhas detectadas.
 * Nao e uma transacao atomica de dois arquivos nem tolerante a SIGKILL.
 * O chamador deve usar um diretorio exclusivo e aceitar apenas retorno 0.
 */
int saidas_confirmar(char *saida)
{
    saida_segura *rel = &contextos[CONTEXTO_RELATORIO];
    saida_segura *res = &contextos[CONTEXTO_RESULTADO];
    char reserva[80] = "";
    struct stat anterior;
    int tinha_relatorio, i, fd, erro, restaurado, reserva_criada = 0;

    /* Nenhum destino e alterado antes de sincronizar e fechar ambos. */
    for (i = 0; i < QUANTIDADE_CONTEXTOS; i++) {
        saida_segura *ctx = &contextos[i];
        if (ctx->temporario_fd < 0) {
            errno = EINVAL;
            falhar(ctx, saida, "Saida nao iniciada");
            limpar_todos();
            return 1;
        }
        if (fsync(ctx->temporario_fd) != 0) {
            falhar(ctx, saida, "Falha ao sincronizar o temporario");
            limpar_todos();
            return 1;
        }
        fd = ctx->temporario_fd;
        ctx->temporario_fd = -1;
        if (close(fd) != 0) {
            falhar(ctx, saida, "Falha ao fechar o temporario");
            limpar_todos();
            return 1;
        }
        if (verificar_destino(ctx, saida)) {
            limpar_todos();
            return 1;
        }
    }

    tinha_relatorio = fstatat(rel->pasta_fd, rel->destino,
                             &anterior, AT_SYMLINK_NOFOLLOW) == 0;
    if (!tinha_relatorio && errno != ENOENT) {
        falhar(rel, saida, "Falha ao consultar relatorio anterior");
        limpar_todos();
        return 1;
    }
    if (tinha_relatorio) {
        /* linkat cria uma reserva exclusiva do inode anterior, sem copia. */
        for (i = 0; i < 100; i++) {
            snprintf(reserva, sizeof reserva, ".conciliacao-%ld-%lu.bak",
                     (long)getpid(), ++sequencia);
            if (linkat(rel->pasta_fd, rel->destino,
                       rel->pasta_fd, reserva, 0) == 0) {
                reserva_criada = 1;
                break;
            }
            if (errno != EEXIST)
                break;
        }
        if (!reserva_criada) {
            falhar(rel, saida, "Falha ao reservar relatorio anterior");
            limpar_todos();
            return 1;
        }
    }

    if (renameat(rel->pasta_fd, rel->temporario,
                 rel->pasta_fd, rel->destino) != 0) {
        erro = errno;
        if (reserva[0]) unlinkat(rel->pasta_fd, reserva, 0);
        errno = erro;
        falhar(rel, saida, "Falha ao publicar relatorio");
        limpar_todos();
        return 1;
    }
    rel->temporario[0] = '\0';

    /* Nova verificacao imediatamente antes da segunda publicacao. */
    if (verificar_destino(res, saida) != 0 ||
        renameat(res->pasta_fd, res->temporario,
                 res->pasta_fd, res->destino) != 0) {
        restaurado = tinha_relatorio
            ? renameat(rel->pasta_fd, reserva, rel->pasta_fd, rel->destino)
            : unlinkat(rel->pasta_fd, rel->destino, 0);
        if (restaurado == 0) {
            mensagem(saida, "Falha ao publicar resultado; saidas anteriores preservadas.");
        } else {
            char texto[160];
            snprintf(texto, sizeof texto,
                     "Falha na publicacao e recuperacao; reserva na pasta do relatorio: %s",
                     reserva[0] ? reserva : "inexistente");
            mensagem(saida, texto);
            /* A reserva fica disponivel para recuperacao manual. */
        }
        limpar_todos();
        return 1;
    }
    res->temporario[0] = '\0';
    if (reserva[0] && unlinkat(rel->pasta_fd, reserva, 0) != 0) {
        mensagem(saida, "Saidas publicadas, mas falhou a limpeza da reserva do relatorio.");
        limpar_todos();
        return 1;
    }
    limpar_todos();
    mensagem(saida, "");
    return 0;
}
