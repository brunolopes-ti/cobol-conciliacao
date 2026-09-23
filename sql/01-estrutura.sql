CREATE TABLE cobrancas (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    identificador VARCHAR(50) NOT NULL UNIQUE,
    valor_esperado NUMERIC(12,2) NOT NULL CHECK (valor_esperado >= 0)
);

CREATE TABLE pagamentos (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    identificador_cobranca VARCHAR(50) NOT NULL,
    valor_pago NUMERIC(12,2) NOT NULL CHECK (valor_pago >= 0)
);
