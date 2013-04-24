SET search_path TO 'public', pg_catalog;

CREATE FUNCTION fstage() RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN

RAISE DEBUG 'Creating FunctionsBefore';
CREATE TEMP TABLE FunctionsBefore ON COMMIT DROP AS
SELECT * FROM View_Functions;

RAISE DEBUG 'Creating ViewsBefore';
CREATE TEMP TABLE ViewsBefore ON COMMIT DROP AS
SELECT * FROM View_Views;

RETURN TRUE;
END;
$$;

ALTER FUNCTION public.fstage() OWNER TO postgres;

