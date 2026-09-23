SELECT
    identificador,
    valor_esperado,
    valor_pago,
    status
FROM vw_conciliacao_completa
ORDER BY identificador;

SELECT
    status,
    COUNT(*) AS quantidade
FROM vw_conciliacao_completa
GROUP BY status
ORDER BY status;

SELECT *
FROM vw_resumo_financeiro;
