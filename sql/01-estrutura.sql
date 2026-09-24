BEGIN;

CREATE TABLE cobrancas (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    identificador VARCHAR(50) NOT NULL UNIQUE,
    valor_esperado NUMERIC NOT NULL,

    CONSTRAINT cobrancas_identificador_valido CHECK (
        identificador ~ '[^[:space:]]'
        AND identificador = btrim(identificador)
        AND identificador !~ '[;[:cntrl:]]'
    ),

    CONSTRAINT cobrancas_valor_valido CHECK (
        valor_esperado BETWEEN 0 AND 99999.99
        AND scale(valor_esperado) <= 2
    )
);

CREATE TABLE pagamentos (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    identificador_cobranca VARCHAR(50) NOT NULL,
    valor_pago NUMERIC NOT NULL,

    CONSTRAINT pagamentos_identificador_valido CHECK (
        identificador_cobranca ~ '[^[:space:]]'
        AND identificador_cobranca = btrim(identificador_cobranca)
        AND identificador_cobranca !~ '[;[:cntrl:]]'
    ),

    CONSTRAINT pagamentos_valor_valido CHECK (
        valor_pago BETWEEN 0 AND 99999.99
        AND scale(valor_pago) <= 2
    )
);

COMMIT;
