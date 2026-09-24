\set ON_ERROR_STOP on

BEGIN;
SET LOCAL search_path TO public, pg_catalog;

DO $$
DECLARE
    nomes TEXT[] := ARRAY[
        'vw_conciliacao',
        'vw_conciliacao_completa',
        'vw_resumo_financeiro'
    ];
    definicoes TEXT[] := ARRAY[NULL, NULL, NULL]::TEXT[];
    i INTEGER;
    precisa_alterar BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE (attrelid = 'public.cobrancas'::regclass
               AND attname = 'valor_esperado'
               OR attrelid = 'public.pagamentos'::regclass
               AND attname = 'valor_pago')
          AND atttypmod <> -1
          AND NOT attisdropped
    ) INTO precisa_alterar;

    IF precisa_alterar THEN
        FOR i IN 1..array_length(nomes, 1) LOOP
            IF to_regclass('public.' || nomes[i]) IS NOT NULL THEN
                definicoes[i] := pg_get_viewdef(
                    to_regclass('public.' || nomes[i]), true
                );
            END IF;
        END LOOP;

        FOR i IN REVERSE array_length(nomes, 1)..1 LOOP
            IF definicoes[i] IS NOT NULL THEN
                EXECUTE format('DROP VIEW public.%I', nomes[i]);
            END IF;
        END LOOP;

        ALTER TABLE public.cobrancas
            ALTER COLUMN valor_esperado TYPE NUMERIC;

        ALTER TABLE public.pagamentos
            ALTER COLUMN valor_pago TYPE NUMERIC;
    END IF;

    ALTER TABLE public.cobrancas
        DROP CONSTRAINT IF EXISTS cobrancas_identificador_valido,
        DROP CONSTRAINT IF EXISTS cobrancas_valor_valido,
        ADD CONSTRAINT cobrancas_identificador_valido CHECK (
            identificador ~ '[^[:space:]]'
            AND identificador = btrim(identificador)
            AND identificador !~ '[;[:cntrl:]]'
        ),
        ADD CONSTRAINT cobrancas_valor_valido CHECK (
            valor_esperado BETWEEN 0 AND 99999.99
            AND scale(valor_esperado) <= 2
        );

    ALTER TABLE public.pagamentos
        DROP CONSTRAINT IF EXISTS pagamentos_identificador_valido,
        DROP CONSTRAINT IF EXISTS pagamentos_valor_valido,
        ADD CONSTRAINT pagamentos_identificador_valido CHECK (
            identificador_cobranca ~ '[^[:space:]]'
            AND identificador_cobranca = btrim(identificador_cobranca)
            AND identificador_cobranca !~ '[;[:cntrl:]]'
        ),
        ADD CONSTRAINT pagamentos_valor_valido CHECK (
            valor_pago BETWEEN 0 AND 99999.99
            AND scale(valor_pago) <= 2
        );

    IF precisa_alterar THEN
        FOR i IN 1..array_length(nomes, 1) LOOP
            IF definicoes[i] IS NOT NULL THEN
                EXECUTE format(
                    'CREATE VIEW public.%I AS %s',
                    nomes[i], definicoes[i]
                );
            END IF;
        END LOOP;
    END IF;
END;
$$;

COMMIT;
\echo MIGRACAO DE RESTRICOES CONCLUIDA.
