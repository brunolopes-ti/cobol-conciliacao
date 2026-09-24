\set ON_ERROR_STOP on

BEGIN;

DO $$
BEGIN
    IF current_database() <> 'conciliacao_teste' THEN
        RAISE EXCEPTION
            'Execute somente no banco conciliacao_teste.';
    END IF;
END;
$$;

TRUNCATE TABLE pagamentos, cobrancas RESTART IDENTITY;

DO $$
DECLARE
    tabela TEXT;
    campo_id TEXT;
    campo_valor TEXT;
    entrada TEXT;
    rejeitou BOOLEAN;
    aprovados INTEGER := 0;
BEGIN
    FOREACH tabela IN ARRAY ARRAY['cobrancas', 'pagamentos']
    LOOP
        IF tabela = 'cobrancas' THEN
            campo_id := 'identificador';
            campo_valor := 'valor_esperado';
        ELSE
            campo_id := 'identificador_cobranca';
            campo_valor := 'valor_pago';
        END IF;

        FOREACH entrada IN ARRAY ARRAY[
            'NaN', 'Infinity', '-Infinity',
            '-0.001', '100.509', '100000'
        ]
        LOOP
            rejeitou := false;

            BEGIN
                EXECUTE format(
                    'INSERT INTO public.%I (%I, %I)
                     VALUES ($1, $2::numeric)',
                    tabela, campo_id, campo_valor
                )
                USING 'TESTE-INVALIDO', entrada;
            EXCEPTION
                WHEN check_violation THEN
                    rejeitou := true;
            END;

            IF NOT rejeitou THEN
                RAISE EXCEPTION
                    'FALHOU: % aceitou valor %.', tabela, entrada;
            END IF;

            aprovados := aprovados + 1;
        END LOOP;

        FOREACH entrada IN ARRAY ARRAY[
            '', '   ', ' A', 'A ', 'A;B', E'\t'
        ]
        LOOP
            rejeitou := false;

            BEGIN
                EXECUTE format(
                    'INSERT INTO public.%I (%I, %I)
                     VALUES ($1, 1)',
                    tabela, campo_id, campo_valor
                )
                USING entrada;
            EXCEPTION
                WHEN check_violation THEN
                    rejeitou := true;
            END;

            IF NOT rejeitou THEN
                RAISE EXCEPTION
                    'FALHOU: % aceitou identificador invalido.',
                    tabela;
            END IF;

            aprovados := aprovados + 1;
        END LOOP;

        -- Confirma que valores permitidos continuam aceitos.
        EXECUTE format(
            'INSERT INTO public.%I (%I, %I)
             VALUES ($1, 0), ($2, 99999.99), ($3, 100.50)',
            tabela, campo_id, campo_valor
        )
        USING 'LIMITE-ZERO', 'LIMITE-MAXIMO', 'VALOR-NORMAL';

        aprovados := aprovados + 3;
    END LOOP;

    RAISE NOTICE
        'PASSOU: % verificacoes de restricoes.', aprovados;
END;
$$;

ROLLBACK;

\echo SUITE DE RESTRICOES APROVADA.
