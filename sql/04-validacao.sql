\set ON_ERROR_STOP on

-- Execute somente no banco conciliacao_teste.
-- Os dados são substituídos dentro de uma transação.
-- O ROLLBACK final restaura os dados anteriores.

BEGIN;

DO $$
BEGIN
    IF current_database() <> 'conciliacao_teste' THEN
        RAISE EXCEPTION
            'Execute esta suite somente no banco conciliacao_teste.';
    END IF;
END;
$$;

TRUNCATE TABLE pagamentos, cobrancas RESTART IDENTITY;

INSERT INTO cobrancas (identificador, valor_esperado) VALUES
('COB001', 100.50),
('COB002', 200.00),
('COB003', 75.25),
('COB004', 90.00);

INSERT INTO pagamentos (identificador_cobranca, valor_pago) VALUES
('COB001', 100.50),
('COB002', 180.00),
('COB999', 50.00),
('COB001', 100.50),
('COB003', 75.25);

DO $$
DECLARE
    r RECORD;
BEGIN
    IF (SELECT COUNT(*) FROM vw_conciliacao_completa) <> 5
       OR EXISTS (
           SELECT 1
           FROM (
               VALUES
                   ('COB001', 'DUPLICADO'),
                   ('COB002', 'DIVERGENTE'),
                   ('COB003', 'CORRETO'),
                   ('COB004', 'SEM PAGAMENTO'),
                   ('COB999', 'COBRANCA INEXISTENTE')
           ) AS esperado(identificador, status)
           LEFT JOIN vw_conciliacao_completa v
               ON v.identificador = esperado.identificador
           WHERE v.status IS DISTINCT FROM esperado.status
       )
    THEN
        RAISE EXCEPTION 'FALHOU: cinco classificacoes.';
    END IF;

    SELECT * INTO STRICT r FROM vw_resumo_financeiro;

    IF ROW(
        r.total_esperado,
        r.total_recebido_bruto,
        r.total_duplicado,
        r.total_cobranca_inexistente,
        r.total_pago_valido,
        r.valor_pendente,
        r.valor_excedente,
        r.saldo_liquido
    ) IS DISTINCT FROM ROW(
        465.75::numeric, 506.25::numeric, 100.50::numeric,
        50.00::numeric, 355.75::numeric, 110.00::numeric,
        0::numeric, -110.00::numeric
    ) THEN
        RAISE EXCEPTION 'FALHOU: totais do cenario original.';
    END IF;

    RAISE NOTICE 'PASSOU: cinco classificacoes e totais originais.';
END;
$$;

INSERT INTO pagamentos (identificador_cobranca, valor_pago)
VALUES ('COB999', 30.00);

DO $$
DECLARE
    r RECORD;
BEGIN
    SELECT * INTO STRICT r FROM vw_resumo_financeiro;

    IF r.total_recebido_bruto IS DISTINCT FROM 536.25::numeric
       OR r.total_cobranca_inexistente IS DISTINCT FROM 80::numeric
       OR r.total_recebido_bruto IS DISTINCT FROM (
           r.total_pago_valido
           + r.total_duplicado
           + r.total_cobranca_inexistente
       )
    THEN
        RAISE EXCEPTION 'FALHOU: pagamentos repetidos sem cobranca.';
    END IF;

    RAISE NOTICE 'PASSOU: pagamentos repetidos sem cobranca.';
END;
$$;

TRUNCATE TABLE pagamentos, cobrancas RESTART IDENTITY;

INSERT INTO cobrancas (identificador, valor_esperado)
VALUES ('A', 100), ('B', 100);

INSERT INTO pagamentos (identificador_cobranca, valor_pago)
VALUES ('A', 200);

DO $$
DECLARE
    r RECORD;
BEGIN
    SELECT * INTO STRICT r FROM vw_resumo_financeiro;

    IF r.valor_pendente IS DISTINCT FROM 100::numeric
       OR r.valor_excedente IS DISTINCT FROM 100::numeric
       OR r.saldo_liquido IS DISTINCT FROM 0::numeric
    THEN
        RAISE EXCEPTION 'FALHOU: excedente esconde pendencia.';
    END IF;

    RAISE NOTICE 'PASSOU: excedente nao esconde pendencia.';
END;
$$;

TRUNCATE TABLE pagamentos, cobrancas RESTART IDENTITY;

INSERT INTO cobrancas (identificador, valor_esperado)
VALUES ('A', 100);

INSERT INTO pagamentos (identificador_cobranca, valor_pago)
VALUES ('A', 20), ('A', 100);

DO $$
DECLARE
    r RECORD;
BEGIN
    SELECT * INTO STRICT r FROM vw_resumo_financeiro;

    IF r.total_pago_valido IS DISTINCT FROM 20::numeric
       OR r.total_duplicado IS DISTINCT FROM 100::numeric
       OR r.valor_pendente IS DISTINCT FROM 80::numeric
       OR (SELECT status FROM vw_conciliacao_completa
           WHERE identificador = 'A') IS DISTINCT FROM 'DUPLICADO'
    THEN
        RAISE EXCEPTION 'FALHOU: primeiro pagamento por identificador.';
    END IF;

    RAISE NOTICE 'PASSOU: primeiro pagamento por identificador.';
END;
$$;

TRUNCATE TABLE pagamentos, cobrancas RESTART IDENTITY;

DO $$
DECLARE
    r RECORD;
BEGIN
    SELECT * INTO STRICT r FROM vw_resumo_financeiro;

    IF EXISTS (SELECT 1 FROM vw_conciliacao_completa)
       OR ROW(
           r.total_esperado,
           r.total_recebido_bruto,
           r.total_duplicado,
           r.total_cobranca_inexistente,
           r.total_pago_valido,
           r.valor_pendente,
           r.valor_excedente,
           r.saldo_liquido
       ) IS DISTINCT FROM ROW(
           0::numeric, 0::numeric, 0::numeric, 0::numeric,
           0::numeric, 0::numeric, 0::numeric, 0::numeric
       )
    THEN
        RAISE EXCEPTION 'FALHOU: banco vazio.';
    END IF;

    RAISE NOTICE 'PASSOU: banco vazio.';
END;
$$;

ROLLBACK;

\echo SUITE SQL APROVADA: 5 cenarios.
