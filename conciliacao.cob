identification division.
program-id. conciliacao.

data division.
working-storage section.
78 limite-pagamentos value 1000.

01 caminho-esperados pic x(256)
    value "dados/esperados.csv".
01 caminho-recebidos pic x(256)
    value "dados/recebidos.csv".
01 caminho-relatorio pic x(256)
    value "relatorio.txt".
01 caminho-resultado pic x(256)
    value "resultado.tsv".
01 quantidade-argumentos binary-long.
01 indice-argumento binary-long.
01 argumento-bruto pic x(256) value spaces.
01 capacidade-argumento binary-long value 256.
01 tamanho-argumento binary-long value zero.
01 argumentos.
   05 caminho-argumento pic x(256) occurs 4 times.

01 caminho-arquivo pic x(256) value spaces.
01 status-arquivo pic 99 value zero.
01 codigo-entrada binary-long value zero.
01 capacidade-registro binary-long value 256.
01 comprimento-registro binary-long value zero.
01 tamanho-identificador binary-long value zero.
01 posicao-separador binary-long value zero.
01 codigo-identificador binary-long value zero.
01 caminho-entrada-c pic x(257) value low-values.
01 registro-arquivo pic x(256) value spaces.
01 codigo-relatorio binary-long signed value zero.
01 tamanho-linha-relatorio binary-long signed value zero.
01 erro-relatorio pic x(160) value spaces.
01 esperado-c pic x(257) value low-values.
01 recebido-c pic x(257) value low-values.
01 relatorio-c pic x(257) value low-values.
01 linha-relatorio pic x(512) value spaces.
01 fim-arquivo pic 9 value zero.
01 numero-linha pic 9(9) value zero.
01 numero-exibicao pic z(8)9.
01 tamanho-registro pic 9(4) value zero.
01 quantidade-separadores pic 9(4) value zero.

01 tipo-arquivo binary-long.
01 indice binary-long.
01 posicao-livre binary-long.
01 identificador pic x(256) value spaces.
01 valor-texto pic x(256) value spaces.

01 entrada-validacao pic x(256) value spaces.
01 validacao-ok pic 9 value zero.
01 valor-validado pic 9(5)v99 value zero.
01 mensagem-erro pic x(80) value spaces.

01 indice-esperado binary-long.
01 indice-recebido binary-long.
01 posicao-encontrada binary-long.
01 quantidade-correspondencias binary-long value zero.
01 diferenca pic s9(5)v99 value zero.
01 esperado-exibicao pic zzzz9.99.
01 recebido-exibicao pic zzzz9.99.
01 diferenca-exibicao pic +++++9.99.
01 status-pagamento pic x(30) value spaces.

01 quantidade-conferidos pic 9(4) value zero.
01 quantidade-acima pic 9(4) value zero.
01 quantidade-abaixo pic 9(4) value zero.
01 quantidade-duplicados pic 9(4) value zero.
01 quantidade-sem-recebimento pic 9(4) value zero.
01 quantidade-sem-previsao pic 9(4) value zero.

01 total-esperado pic 9(8)v99 value zero.
01 total-recebido pic 9(8)v99 value zero.
01 saldo-global pic s9(8)v99 value zero.
01 total-exibicao pic z(7)9.99.
01 saldo-exibicao pic +(8)9.99.

01 listas-pagamentos.
   05 lista occurs 2 times.
      10 quantidade binary-long.
      10 pagamento occurs 1000 times.
         15 pagamento-id pic x(256).
         15 pagamento-valor pic 9(5)v99.
         15 pagamento-utilizado pic 9.

procedure division.
    initialize listas-pagamentos
    perform configurar-argumentos

    display "Carregamento dos pagamentos."

    move 1 to tipo-arquivo
    move caminho-esperados to caminho-arquivo
    perform carregar-arquivo

    move 2 to tipo-arquivo
    move caminho-recebidos to caminho-arquivo
    perform carregar-arquivo

    perform preparar-relatorio

    move "Conferencia dos pagamentos esperados:"
        to linha-relatorio
    perform emitir-linha
    perform conferir-pagamentos

    move "Recebimentos sem previsao:" to linha-relatorio
    perform emitir-linha
    perform mostrar-sem-previsao

    perform mostrar-resumo

    move "Conferencia concluida." to linha-relatorio
    perform gravar-linha

    call static "relatorio_confirmar" using
        by reference erro-relatorio
        returning codigo-relatorio
    end-call

    if codigo-relatorio not = zero
        display "Erro ao publicar relatorio: "
            function trim(erro-relatorio)
        move 1 to return-code
        stop run
    end-if

    display "Conferencia concluida."

    move zero to return-code
    stop run.

configurar-argumentos.
    accept quantidade-argumentos from argument-number

    if quantidade-argumentos = zero
        exit paragraph
    end-if

    if quantidade-argumentos not = 4
        display "Erro: informe zero ou quatro argumentos."
        perform encerrar-uso
    end-if

    perform varying indice-argumento from 1 by 1
        until indice-argumento > 4

        move spaces to argumento-bruto

        call static "entrada_argumento" using
            indice-argumento
            argumento-bruto
            capacidade-argumento
            tamanho-argumento
            returning codigo-entrada
        end-call

        evaluate codigo-entrada
            when 4
                display "Erro: caminho excede 256 posicoes."
                perform encerrar-uso

            when zero
                continue

            when other
                display
                    "Erro: argumento invalido ou nao foi possivel le-lo."
                perform encerrar-uso
        end-evaluate

        if argumento-bruto = spaces
            or tamanho-argumento = zero
            display "Erro: caminho vazio."
            perform encerrar-uso
        end-if

        if argumento-bruto(tamanho-argumento:1) = space
            display "Erro: caminho nao deve terminar com espaco."
            perform encerrar-uso
        end-if

        move argumento-bruto
            to caminho-argumento(indice-argumento)
    end-perform

    move caminho-argumento(1) to caminho-esperados
    move caminho-argumento(2) to caminho-recebidos
    move caminho-argumento(3) to caminho-relatorio
    move caminho-argumento(4) to caminho-resultado

    if caminho-relatorio = caminho-esperados
        or caminho-relatorio = caminho-recebidos
        display
            "Erro: relatorio deve ter caminho diferente das entradas."
        perform encerrar-uso
    end-if

    if caminho-resultado = caminho-esperados
        or caminho-resultado = caminho-recebidos
        or caminho-resultado = caminho-relatorio
        display
            "Erro: resultado deve ter caminho diferente dos demais arquivos."
        perform encerrar-uso
    end-if.

encerrar-uso.
    display
        "Uso: ./conciliacao [esperados recebidos relatorio resultado]"
    move 2 to return-code
    stop run.

carregar-arquivo.
    move zero to fim-arquivo numero-linha

    move low-values to caminho-entrada-c

    string
        function trim(caminho-arquivo trailing)
        x"00"
        delimited by size
        into caminho-entrada-c
    end-string

    perform abrir-entrada

    if status-arquivo not = "00"
        display "Erro ao abrir "
            function trim(caminho-arquivo)
            ". Codigo: "
            status-arquivo

        move 1 to return-code
        stop run
    end-if

    perform until fim-arquivo = 1
        perform ler-entrada

        evaluate status-arquivo
            when "00"
            when "04"
            when "09"
                add 1 to numero-linha

                perform validar-registro

                if mensagem-erro not = spaces
                    perform encerrar-com-erro
                end-if

                perform armazenar-registro

            when "10"
                move 1 to fim-arquivo

            when other
                display "Erro na leitura de "
                    function trim(caminho-arquivo)
                    ". Codigo: "
                    status-arquivo

                perform fechar-entrada

                move 1 to return-code
                stop run
        end-evaluate
    end-perform

    perform fechar-entrada

    if status-arquivo not = "00"
        display "Erro ao fechar "
            function trim(caminho-arquivo)
            ". Codigo: "
            status-arquivo

        move 1 to return-code
        stop run
    end-if

    if quantidade(tipo-arquivo) = zero
        display "Erro: arquivo vazio: "
            function trim(caminho-arquivo)

        move 1 to return-code
        stop run
    end-if.

validar-registro.
    move spaces to identificador valor-texto mensagem-erro
    move zero to quantidade-separadores

    if status-arquivo = "04"
        move "linha excede o limite de 256 bytes."
            to mensagem-erro
        exit paragraph
    end-if

    if status-arquivo = "09"
        move "linha contem controle ou UTF-8 invalido."
            to mensagem-erro
        exit paragraph
    end-if

    inspect registro-arquivo
        tallying quantidade-separadores for all ";"

    if quantidade-separadores not = 1
        move "informe exatamente um ponto e virgula."
            to mensagem-erro
        exit paragraph
    end-if

    move 1 to posicao-separador

    perform until
        registro-arquivo(posicao-separador:1) = ";"

        add 1 to posicao-separador
    end-perform

    compute tamanho-identificador =
        posicao-separador - 1

    unstring registro-arquivo
        delimited by ";"
        into identificador valor-texto
    end-unstring

    call static "entrada_identificador" using
        identificador
        tamanho-identificador
        mensagem-erro
        returning codigo-identificador
    end-call

    if codigo-identificador not = zero
        exit paragraph
    end-if

    if function trim(valor-texto) = spaces
        move "valor vazio." to mensagem-erro
        exit paragraph
    end-if

    move valor-texto to entrada-validacao

    call "validar-monetario" using
        entrada-validacao
        validacao-ok
        valor-validado
        mensagem-erro
    end-call.

armazenar-registro.
    if tipo-arquivo = 1
        perform varying indice from 1 by 1
            until indice > quantidade(tipo-arquivo)

            if pagamento-id(tipo-arquivo, indice) =
                identificador

                move "identificador duplicado neste arquivo."
                    to mensagem-erro

                perform encerrar-com-erro
            end-if
        end-perform
    end-if

    if quantidade(tipo-arquivo) >= limite-pagamentos
        move "arquivo excede o limite de 1000 pagamentos."
            to mensagem-erro

        perform encerrar-com-erro
    end-if

    compute posicao-livre =
        quantidade(tipo-arquivo) + 1

    move identificador
        to pagamento-id(tipo-arquivo, posicao-livre)

    move valor-validado
        to pagamento-valor(tipo-arquivo, posicao-livre)

    move zero
        to pagamento-utilizado(tipo-arquivo, posicao-livre)

    add 1 to quantidade(tipo-arquivo)

    if tipo-arquivo = 1
        add valor-validado to total-esperado
    else
        add valor-validado to total-recebido
    end-if.

encerrar-com-erro.
    move numero-linha to numero-exibicao

    display "Erro em "
        function trim(caminho-arquivo)
        ", linha "
        function trim(numero-exibicao)
        ": "
        function trim(mensagem-erro)

    perform fechar-entrada

    move 1 to return-code
    stop run.

conferir-pagamentos.
    perform varying indice-esperado from 1 by 1
        until indice-esperado > quantidade(1)

        perform procurar-recebimento

        if posicao-encontrada = zero
            add 1 to quantidade-sem-recebimento

            move spaces to linha-relatorio

            string
                "Pagamento: "
                function trim(
                    pagamento-id(1, indice-esperado)
                )
                " | Status: sem recebimento"
                delimited by size
                into linha-relatorio
            end-string

            perform emitir-linha
        else
            if quantidade-correspondencias > 1
                add 1 to quantidade-duplicados
                perform mostrar-duplicado
            else
                perform comparar-valores
            end-if
        end-if
    end-perform.

procurar-recebimento.
    move zero to
        posicao-encontrada
        quantidade-correspondencias

    perform varying indice-recebido from 1 by 1
        until indice-recebido > quantidade(2)

        if pagamento-id(1, indice-esperado) =
            pagamento-id(2, indice-recebido)

            add 1 to quantidade-correspondencias

            move 1 to
                pagamento-utilizado(
                    2,
                    indice-recebido
                )

            if posicao-encontrada = zero
                move indice-recebido
                    to posicao-encontrada
            end-if
        end-if
    end-perform.

mostrar-duplicado.
    compute diferenca =
        pagamento-valor(2, posicao-encontrada)
        - pagamento-valor(1, indice-esperado)

    move pagamento-valor(1, indice-esperado)
        to esperado-exibicao

    move pagamento-valor(2, posicao-encontrada)
        to recebido-exibicao

    move diferenca to diferenca-exibicao

    move spaces to linha-relatorio

    string
        "Pagamento: "
        function trim(
            pagamento-id(1, indice-esperado)
        )
        " | Esperado: "
        function trim(esperado-exibicao)
        " | Recebido: "
        function trim(recebido-exibicao)
        " | Diferenca: "
        function trim(diferenca-exibicao)
        " | Status: duplicado"
        delimited by size
        into linha-relatorio
    end-string

    perform emitir-linha.

comparar-valores.
    compute diferenca =
        pagamento-valor(2, posicao-encontrada)
        - pagamento-valor(1, indice-esperado)

    evaluate true
        when diferenca = zero
            move "conferido" to status-pagamento
            add 1 to quantidade-conferidos

        when diferenca > zero
            move "acima do esperado"
                to status-pagamento
            add 1 to quantidade-acima

        when other
            move "abaixo do esperado"
                to status-pagamento
            add 1 to quantidade-abaixo
    end-evaluate

    move pagamento-valor(1, indice-esperado)
        to esperado-exibicao

    move pagamento-valor(2, posicao-encontrada)
        to recebido-exibicao

    move diferenca to diferenca-exibicao

    move spaces to linha-relatorio

    string
        "Pagamento: "
        function trim(
            pagamento-id(1, indice-esperado)
        )
        " | Esperado: "
        function trim(esperado-exibicao)
        " | Recebido: "
        function trim(recebido-exibicao)
        " | Diferenca: "
        function trim(diferenca-exibicao)
        " | Status: "
        function trim(status-pagamento)
        delimited by size
        into linha-relatorio
    end-string

    perform emitir-linha.

mostrar-sem-previsao.
    perform varying indice-recebido from 1 by 1
        until indice-recebido > quantidade(2)

        if pagamento-utilizado(
            2,
            indice-recebido
        ) = zero

            add 1 to quantidade-sem-previsao

            move pagamento-valor(
                2,
                indice-recebido
            )
                to recebido-exibicao

            move spaces to linha-relatorio

            string
                "Pagamento: "
                function trim(
                    pagamento-id(
                        2,
                        indice-recebido
                    )
                )
                " | Recebido: "
                function trim(recebido-exibicao)
                " | Status: sem previsao"
                delimited by size
                into linha-relatorio
            end-string

            perform emitir-linha
        end-if
    end-perform.

mostrar-resumo.
    move "Resumo da conciliacao:"
        to linha-relatorio
    perform emitir-linha

    move quantidade-conferidos
        to numero-exibicao

    move spaces to linha-relatorio

    string
        "Conferidos: "
        function trim(numero-exibicao)
        delimited by size
        into linha-relatorio
    end-string

    perform emitir-linha

    move quantidade-acima
        to numero-exibicao

    move spaces to linha-relatorio

    string
        "Acima do esperado: "
        function trim(numero-exibicao)
        delimited by size
        into linha-relatorio
    end-string

    perform emitir-linha

    move quantidade-abaixo
        to numero-exibicao

    move spaces to linha-relatorio

    string
        "Abaixo do esperado: "
        function trim(numero-exibicao)
        delimited by size
        into linha-relatorio
    end-string

    perform emitir-linha

    move quantidade-duplicados
        to numero-exibicao

    move spaces to linha-relatorio

    string
        "Duplicados: "
        function trim(numero-exibicao)
        delimited by size
        into linha-relatorio
    end-string

    perform emitir-linha

    move quantidade-sem-recebimento
        to numero-exibicao

    move spaces to linha-relatorio

    string
        "Sem recebimento: "
        function trim(numero-exibicao)
        delimited by size
        into linha-relatorio
    end-string

    perform emitir-linha

    move quantidade-sem-previsao
        to numero-exibicao

    move spaces to linha-relatorio

    string
        "Sem previsao: "
        function trim(numero-exibicao)
        delimited by size
        into linha-relatorio
    end-string

    perform emitir-linha

    move total-esperado
        to total-exibicao

    move spaces to linha-relatorio

    string
        "Total esperado: "
        function trim(total-exibicao)
        delimited by size
        into linha-relatorio
    end-string

    perform emitir-linha

    move total-recebido
        to total-exibicao

    move spaces to linha-relatorio

    string
        "Total recebido: "
        function trim(total-exibicao)
        delimited by size
        into linha-relatorio
    end-string

    perform emitir-linha

    compute saldo-global =
        total-recebido - total-esperado

    move saldo-global
        to saldo-exibicao

    move spaces to linha-relatorio

    string
        "Saldo global: "
        function trim(saldo-exibicao)
        delimited by size
        into linha-relatorio
    end-string

    perform emitir-linha.

emitir-linha.
    perform gravar-linha

    display function trim(
        linha-relatorio trailing
    ).

preparar-relatorio.
    move low-values
        to esperado-c
        recebido-c
        relatorio-c

    string
        function trim(
            caminho-esperados trailing
        )
        x"00"
        delimited by size
        into esperado-c
    end-string

    string
        function trim(
            caminho-recebidos trailing
        )
        x"00"
        delimited by size
        into recebido-c
    end-string

    string
        function trim(
            caminho-relatorio trailing
        )
        x"00"
        delimited by size
        into relatorio-c
    end-string

    call static "relatorio_abrir" using
        by reference
            esperado-c
            recebido-c
            relatorio-c
            erro-relatorio
        returning codigo-relatorio
    end-call

    evaluate codigo-relatorio
        when zero
            continue

        when 2
            display
                "Erro: relatorio deve ter caminho diferente das entradas."

            perform encerrar-uso

        when other
            display "Erro ao abrir "
                function trim(caminho-relatorio)
                ". Codigo: "
                codigo-relatorio

            display function trim(
                erro-relatorio
            )

            move 1 to return-code
            stop run
    end-evaluate.

gravar-linha.
    compute tamanho-linha-relatorio =
        function length(
            function trim(
                linha-relatorio trailing
            )
        )

    call static "relatorio_linha" using
        by reference
            linha-relatorio
            tamanho-linha-relatorio
            erro-relatorio
        returning codigo-relatorio
    end-call

    if codigo-relatorio not = zero
        display "Erro ao gravar relatorio: "
            function trim(erro-relatorio)

        move 1 to return-code
        stop run
    end-if.

abrir-entrada.
    call static "entrada_abrir" using
        caminho-entrada-c
        returning codigo-entrada
    end-call

    move codigo-entrada to status-arquivo.

ler-entrada.
    call static "entrada_ler" using
        registro-arquivo
        capacidade-registro
        comprimento-registro
        returning codigo-entrada
    end-call

    move codigo-entrada to status-arquivo.

fechar-entrada.
    call static "entrada_fechar"
        returning codigo-entrada
    end-call

    move codigo-entrada to status-arquivo.
