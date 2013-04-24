SET search_path TO 'public', pg_catalog;

CREATE VIEW view_functions AS
     SELECT p.oid AS functionid, n.nspname AS schema, p.proname AS name, pg_get_function_result(p.oid) AS resultdatatype, pg_get_function_arguments(p.oid) AS argumentdatatypes, 
        CASE
            WHEN p.proisagg THEN 'agg'::text
            WHEN p.proiswindow THEN 'window'::text
            WHEN p.prorettype = 'trigger'::regtype::oid THEN 'trigger'::text
            ELSE 'normal'::text
        END AS type, 
        CASE
            WHEN p.provolatile = 'i'::"char" THEN 'IMMUTABLE'::text
            WHEN p.provolatile = 's'::"char" THEN 'STABLE'::text
            WHEN p.provolatile = 'v'::"char" THEN 'VOLATILE'::text
            ELSE NULL::text
        END AS volatility, pg_get_userbyid(p.proowner) AS owner, l.lanname AS language, p.prosrc AS sourcecode
   FROM pg_proc p
   LEFT JOIN pg_namespace n ON n.oid = p.pronamespace
   LEFT JOIN pg_language l ON l.oid = p.prolang
  WHERE pg_function_is_visible(p.oid) AND n.nspname <> 'pg_catalog'::name AND n.nspname <> 'information_schema'::name
  ORDER BY p.oid;

ALTER TABLE public.view_functions OWNER TO postgres;
