BEGIN;

CREATE OR REPLACE VIEW vw_conciliacao_completa AS
WITH pagamentos_analisados AS (
    SELECT
        id,
        identificador_cobranca,
        valor_pago,
        ROW_NUMBER() OVER (
            PARTITION BY identificador_cobranca
            ORDER BY id
        ) AS numero,
        COUNT(*) OVER (
            PARTITION BY identificador_cobranca
        ) AS quantidade
    FROM pagamentos
)
SELECT
    c.identificador,
    c.valor_esperado,
    p.valor_pago,
    CASE
        WHEN p.id IS NULL THEN 'SEM PAGAMENTO'
        WHEN p.quantidade > 1 THEN 'DUPLICADO'
        WHEN c.valor_esperado = p.valor_pago THEN 'CORRETO'
        ELSE 'DIVERGENTE'
    END AS status
FROM cobrancas c
LEFT JOIN pagamentos_analisados p
    ON c.identificador = p.identificador_cobranca
    AND p.numero = 1

UNION ALL

SELECT
    p.identificador_cobranca AS identificador,
    NULL AS valor_esperado,
    p.valor_pago,
    'COBRANCA INEXISTENTE' AS status
FROM pagamentos_analisados p
LEFT JOIN cobrancas c
    ON p.identificador_cobranca = c.identificador
WHERE c.id IS NULL;

CREATE OR REPLACE VIEW vw_resumo_financeiro AS
WITH pagamentos_numerados AS (
    SELECT
        id,
        identificador_cobranca,
        valor_pago,
        ROW_NUMBER() OVER (
            PARTITION BY identificador_cobranca
            ORDER BY id
        ) AS numero
    FROM pagamentos
),
cobrancas_analisadas AS (
    SELECT
        c.valor_esperado,
        COALESCE(p.valor_pago, 0) AS valor_principal
    FROM cobrancas c
    LEFT JOIN pagamentos_numerados p
        ON c.identificador = p.identificador_cobranca
        AND p.numero = 1
),
metricas AS (
    SELECT
        (
            SELECT COALESCE(SUM(valor_esperado), 0)
            FROM cobrancas
        ) AS total_esperado,

        (
            SELECT COALESCE(SUM(valor_pago), 0)
            FROM pagamentos
        ) AS total_recebido_bruto,

        (
            SELECT COALESCE(SUM(p.valor_pago), 0)
            FROM pagamentos_numerados p
            JOIN cobrancas c
                ON p.identificador_cobranca = c.identificador
            WHERE p.numero > 1
        ) AS total_duplicado,

        -- Todos os pagamentos sem cobranca entram nesta categoria.
        (
            SELECT COALESCE(SUM(p.valor_pago), 0)
            FROM pagamentos_numerados p
            LEFT JOIN cobrancas c
                ON p.identificador_cobranca = c.identificador
            WHERE c.id IS NULL
        ) AS total_cobranca_inexistente,

        -- Mantem o nome existente: primeiro pagamento por cobranca.
        (
            SELECT COALESCE(SUM(valor_principal), 0)
            FROM cobrancas_analisadas
        ) AS total_pago_valido,

        (
            SELECT COALESCE(SUM(
                GREATEST(
                    valor_esperado - valor_principal,
                    0
                )
            ), 0)
            FROM cobrancas_analisadas
        ) AS valor_pendente,

        (
            SELECT COALESCE(SUM(
                GREATEST(
                    valor_principal - valor_esperado,
                    0
                )
            ), 0)
            FROM cobrancas_analisadas
        ) AS valor_excedente
)
SELECT
    total_esperado,
    total_recebido_bruto,
    total_duplicado,
    total_cobranca_inexistente,
    total_pago_valido,
    valor_pendente,
    valor_excedente,
    total_pago_valido - total_esperado AS saldo_liquido
FROM metricas;

COMMIT;
