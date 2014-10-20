SET search_path TO 'public', pg_catalog;

CREATE OR REPLACE FUNCTION fstage() RETURNS boolean
    LANGUAGE plpgsql
    SET search_path TO public
    AS $$
BEGIN

RAISE DEBUG 'Creating FunctionsBefore';
CREATE TEMP TABLE FunctionsBefore ON COMMIT DROP AS
SELECT
    FunctionID,
    Schema,
    Name,
    ResultDataType,
    ArgumentDataTypes,
    Type,
    Volatility,
    Owner,
    Language,
    Sourcecode,
    SecurityDefiner,
    ConfigurationParameters
FROM View_Functions;

RAISE DEBUG 'Creating ViewsBefore';
CREATE TEMP TABLE ViewsBefore ON COMMIT DROP AS
SELECT
    ViewID,
    Sourcecode,
    Schema,
    Name,
    Owner
FROM View_Views;

RETURN TRUE;
END;
$$;

ALTER FUNCTION public.fstage() OWNER TO postgres;

