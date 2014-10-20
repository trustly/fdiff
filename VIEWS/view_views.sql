SET search_path TO 'public', pg_catalog;

CREATE OR REPLACE VIEW view_views AS
     SELECT
         pg_class.oid AS ViewID,
         pg_get_viewdef(pg_class.oid, TRUE) AS Sourcecode,
         pg_namespace.nspname AS Schema,
         pg_class.relname AS Name,
         pg_catalog.pg_get_userbyid(pg_class.relowner) AS Owner
     FROM pg_class
     INNER JOIN pg_namespace ON (pg_namespace.oid = pg_class.relnamespace)
     WHERE pg_class.relkind = 'v'
     AND pg_namespace.nspname NOT IN ('pg_catalog','information_schema')
     ORDER BY 1;

ALTER TABLE public.view_views OWNER TO postgres;
