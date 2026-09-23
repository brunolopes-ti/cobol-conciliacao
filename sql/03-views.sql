CREATE VIEW vw_conciliacao_completa AS
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
WHERE c.id IS NULL
  AND p.numero = 1;


CREATE VIEW vw_resumo_financeiro AS
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
metricas AS (
    SELECT
        (SELECT COALESCE(SUM(valor_esperado), 0)
         FROM cobrancas) AS total_esperado,

        (SELECT COALESCE(SUM(valor_pago), 0)
         FROM pagamentos) AS total_recebido_bruto,

        (SELECT COALESCE(SUM(p.valor_pago), 0)
         FROM pagamentos_numerados p
         JOIN cobrancas c
             ON p.identificador_cobranca = c.identificador
         WHERE p.numero > 1) AS total_duplicado,

        (SELECT COALESCE(SUM(p.valor_pago), 0)
         FROM pagamentos_numerados p
         LEFT JOIN cobrancas c
             ON p.identificador_cobranca = c.identificador
         WHERE c.id IS NULL
           AND p.numero = 1) AS total_cobranca_inexistente,

        (SELECT COALESCE(SUM(p.valor_pago), 0)
         FROM pagamentos_numerados p
         JOIN cobrancas c
             ON p.identificador_cobranca = c.identificador
         WHERE p.numero = 1) AS total_pago_valido
)
SELECT
    total_esperado,
    total_recebido_bruto,
    total_duplicado,
    total_cobranca_inexistente,
    total_pago_valido,
    total_esperado - total_pago_valido AS valor_pendente
FROM metricas;
