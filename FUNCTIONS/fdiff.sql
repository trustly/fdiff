SET search_path TO 'public', pg_catalog;

CREATE OR REPLACE FUNCTION fdiff(OUT changes text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
_DeployID integer;
_FunctionID oid;
_RemovedFunctionID oid;
_NewFunctionID oid;
_RemovedViewID oid;
_NewViewID oid;
_Schema text;
_FunctionName text;
_Diff text;
_ record;
_CountRemoved integer;
_CountNew integer;
_ReplacedFunctions integer[][];
BEGIN

RAISE DEBUG 'Creating FunctionsAfter';
CREATE TEMP TABLE FunctionsAfter ON COMMIT DROP AS
SELECT * FROM View_Functions;

RAISE DEBUG 'Creating AllFunctions';
CREATE TEMP TABLE AllFunctions ON COMMIT DROP AS
SELECT FunctionID, Schema, Name FROM FunctionsAfter
UNION
SELECT FunctionID, Schema, Name FROM FunctionsBefore;

RAISE DEBUG 'Creating NewFunctions';
CREATE TEMP TABLE NewFunctions ON COMMIT DROP AS
SELECT FunctionID FROM FunctionsAfter
EXCEPT
SELECT FunctionID FROM FunctionsBefore;

RAISE DEBUG 'Creating RemovedFunctions';
CREATE TEMP TABLE RemovedFunctions ON COMMIT DROP AS
SELECT FunctionID FROM FunctionsBefore
EXCEPT
SELECT FunctionID FROM FunctionsAfter;

RAISE DEBUG 'Creating ReplacedFunctions';
CREATE TEMP TABLE ReplacedFunctions (
RemovedFunctionID oid,
NewFunctionID oid
) ON COMMIT DROP;

FOR _ IN SELECT DISTINCT FunctionsAfter.Schema, FunctionsAfter.Name
FROM RemovedFunctions, NewFunctions, FunctionsBefore, FunctionsAfter
WHERE FunctionsBefore.FunctionID  = RemovedFunctions.FunctionID
AND   FunctionsAfter.FunctionID   = NewFunctions.FunctionID
AND   FunctionsBefore.Schema      = FunctionsAfter.Schema
AND   FunctionsBefore.Name        = FunctionsAfter.Name
LOOP
    SELECT COUNT(*) INTO _CountRemoved FROM RemovedFunctions
    INNER JOIN FunctionsBefore USING (FunctionID)
    WHERE FunctionsBefore.Schema = _.Schema AND FunctionsBefore.Name = _.Name;

    SELECT COUNT(*) INTO _CountNew FROM NewFunctions
    INNER JOIN FunctionsAfter USING (FunctionID)
    WHERE FunctionsAfter.Schema = _.Schema AND FunctionsAfter.Name = _.Name;

    IF _CountRemoved = 1 AND _CountNew = 1 THEN
        -- Exactly one function removed with identical name as a new function

        SELECT RemovedFunctions.FunctionID INTO STRICT _RemovedFunctionID FROM RemovedFunctions
        INNER JOIN FunctionsBefore USING (FunctionID)
        WHERE FunctionsBefore.Schema = _.Schema AND FunctionsBefore.Name = _.Name;

        SELECT NewFunctions.FunctionID INTO STRICT _NewFunctionID FROM NewFunctions
        INNER JOIN FunctionsAfter USING (FunctionID)
        WHERE FunctionsAfter.Schema = _.Schema AND FunctionsAfter.Name = _.Name;

        INSERT INTO ReplacedFunctions (RemovedFunctionID,NewFunctionID) VALUES (_RemovedFunctionID,_NewFunctionID);
    END IF;
END LOOP;

RAISE DEBUG 'Deleting ReplacedFunctions from RemovedFunctions';
DELETE FROM RemovedFunctions WHERE FunctionID IN (SELECT RemovedFunctionID FROM ReplacedFunctions);

RAISE DEBUG 'Deleting ReplacedFunctions from NewFunctions';
DELETE FROM NewFunctions     WHERE FunctionID IN (SELECT NewFunctionID     FROM ReplacedFunctions);

RAISE DEBUG 'Creating ChangedFunctions';

CREATE TEMP TABLE ChangedFunctions ON COMMIT DROP AS
SELECT AllFunctions.FunctionID FROM AllFunctions
INNER JOIN FunctionsBefore ON (FunctionsBefore.FunctionID = AllFunctions.FunctionID)
INNER JOIN FunctionsAfter  ON (FunctionsAfter.FunctionID  = AllFunctions.FunctionID)
WHERE FunctionsBefore.Schema         <> FunctionsAfter.Schema
OR FunctionsBefore.Name              <> FunctionsAfter.Name
OR FunctionsBefore.ResultDataType    <> FunctionsAfter.ResultDataType
OR FunctionsBefore.ArgumentDataTypes <> FunctionsAfter.ArgumentDataTypes
OR FunctionsBefore.Type              <> FunctionsAfter.Type
OR FunctionsBefore.Volatility        <> FunctionsAfter.Volatility
OR FunctionsBefore.Owner             <> FunctionsAfter.Owner
OR FunctionsBefore.Language          <> FunctionsAfter.Language
OR FunctionsBefore.Sourcecode        <> FunctionsAfter.Sourcecode
;

Changes := '';

RAISE DEBUG 'Removed functions...';

FOR _ IN
SELECT
    RemovedFunctions.FunctionID,
    FunctionsBefore.Schema                                     AS SchemaBefore,
    FunctionsBefore.Name                                       AS NameBefore,
    FunctionsBefore.ArgumentDataTypes                          AS ArgumentDataTypesBefore,
    FunctionsBefore.ResultDataType                             AS ResultDataTypeBefore,
    FunctionsBefore.Language                                   AS LanguageBefore,
    FunctionsBefore.Type                                       AS TypeBefore,
    FunctionsBefore.Volatility                                 AS VolatilityBefore,
    FunctionsBefore.Owner                                      AS OwnerBefore,
    length(FunctionsBefore.Sourcecode)                         AS SourcecodeLength,
    ROW_NUMBER() OVER (),
    COUNT(*) OVER ()
FROM RemovedFunctions
INNER JOIN FunctionsBefore USING (FunctionID)
ORDER BY 2,3,4,5,6,7,8,9,10
LOOP
    IF _.row_number = 1 THEN
        Changes := Changes || '+-------------------+' || E'\n';
        Changes := Changes || '| Removed functions |' || E'\n';
        Changes := Changes || '+-------------------+' || E'\n\n';
    END IF;
    Changes := Changes || 'Schema................- ' || _.SchemaBefore || E'\n';
    Changes := Changes || 'Name..................- ' || _.NameBefore || E'\n';
    Changes := Changes || 'Argument data types...- ' || _.ArgumentDataTypesBefore || E'\n';
    Changes := Changes || 'Result data type......- ' || _.ResultDataTypeBefore || E'\n';
    Changes := Changes || 'Language..............- ' || _.LanguageBefore || E'\n';
    Changes := Changes || 'Type..................- ' || _.TypeBefore || E'\n';
    Changes := Changes || 'Volatility............- ' || _.VolatilityBefore || E'\n';
    Changes := Changes || 'Owner.................- ' || _.OwnerBefore || E'\n';
    Changes := Changes || 'Source code (chars)...- ' || _.SourcecodeLength || E'\n';
    IF _.row_number = _.count THEN
        Changes := Changes || E'\n\n';
    END IF;
END LOOP;

RAISE DEBUG 'New functions...';

FOR _ IN
SELECT
    NewFunctions.FunctionID,
    FunctionsAfter.Schema                                     AS SchemaAfter,
    FunctionsAfter.Name                                       AS NameAfter,
    FunctionsAfter.ArgumentDataTypes                          AS ArgumentDataTypesAfter,
    FunctionsAfter.ResultDataType                             AS ResultDataTypeAfter,
    FunctionsAfter.Language                                   AS LanguageAfter,
    FunctionsAfter.Type                                       AS TypeAfter,
    FunctionsAfter.Volatility                                 AS VolatilityAfter,
    FunctionsAfter.Owner                                      AS OwnerAfter,
    length(FunctionsAfter.Sourcecode)                         AS SourcecodeLength,
    ROW_NUMBER() OVER (),
    COUNT(*) OVER ()
FROM NewFunctions
INNER JOIN FunctionsAfter USING (FunctionID)
ORDER BY 2,3,4,5,6,7,8,9,10
LOOP
    IF _.row_number = 1 THEN
        Changes := Changes || '+---------------+' || E'\n';
        Changes := Changes || '| New functions |' || E'\n';
        Changes := Changes || '+---------------+' || E'\n\n';
    END IF;
    Changes := Changes || 'Schema................+ ' || _.SchemaAfter || E'\n';
    Changes := Changes || 'Name..................+ ' || _.NameAfter || E'\n';
    Changes := Changes || 'Argument data types...+ ' || _.ArgumentDataTypesAfter || E'\n';
    Changes := Changes || 'Result data type......+ ' || _.ResultDataTypeAfter || E'\n';
    Changes := Changes || 'Language..............+ ' || _.LanguageAfter || E'\n';
    Changes := Changes || 'Type..................+ ' || _.TypeAfter || E'\n';
    Changes := Changes || 'Volatility............+ ' || _.VolatilityAfter || E'\n';
    Changes := Changes || 'Owner.................+ ' || _.OwnerAfter || E'\n';
    Changes := Changes || 'Source code (chars)...+ ' || _.SourcecodeLength || E'\n';
    IF _.row_number = _.count THEN
        Changes := Changes || E'\n\n';
    END IF;
END LOOP;
Changes := Changes || E'\n\n';

RAISE DEBUG 'Updated or replaced functions...';

FOR _ IN
WITH innerQ AS (
SELECT
    ChangedFunctions.FunctionID,
    FunctionsBefore.Schema                                     AS SchemaBefore,
    FunctionsBefore.Name                                       AS NameBefore,
    FunctionsBefore.ArgumentDataTypes                          AS ArgumentDataTypesBefore,
    FunctionsBefore.ResultDataType                             AS ResultDataTypeBefore,
    FunctionsBefore.Language                                   AS LanguageBefore,
    FunctionsBefore.Type                                       AS TypeBefore,
    FunctionsBefore.Volatility                                 AS VolatilityBefore,
    FunctionsBefore.Owner                                      AS OwnerBefore,
    FunctionsAfter.Schema                                      AS SchemaAfter,
    FunctionsAfter.Name                                        AS NameAfter,
    FunctionsAfter.ArgumentDataTypes                           AS ArgumentDataTypesAfter,
    FunctionsAfter.ResultDataType                              AS ResultDataTypeAfter,
    FunctionsAfter.Language                                    AS LanguageAfter,
    FunctionsAfter.Type                                        AS TypeAfter,
    FunctionsAfter.Volatility                                  AS VolatilityAfter,
    FunctionsAfter.Owner                                       AS OwnerAfter,
    Diff(FunctionsBefore.Sourcecode,FunctionsAfter.Sourcecode) AS Diff
FROM ChangedFunctions
INNER JOIN FunctionsBefore ON (FunctionsBefore.FunctionID = ChangedFunctions.FunctionID)
INNER JOIN FunctionsAfter  ON (FunctionsAfter.FunctionID  = ChangedFunctions.FunctionID)
UNION ALL
SELECT
    FunctionsAfter.FunctionID,
    FunctionsBefore.Schema                                     AS SchemaBefore,
    FunctionsBefore.Name                                       AS NameBefore,
    FunctionsBefore.ArgumentDataTypes                          AS ArgumentDataTypesBefore,
    FunctionsBefore.ResultDataType                             AS ResultDataTypeBefore,
    FunctionsBefore.Language                                   AS LanguageBefore,
    FunctionsBefore.Type                                       AS TypeBefore,
    FunctionsBefore.Volatility                                 AS VolatilityBefore,
    FunctionsBefore.Owner                                      AS OwnerBefore,
    FunctionsAfter.Schema                                      AS SchemaAfter,
    FunctionsAfter.Name                                        AS NameAfter,
    FunctionsAfter.ArgumentDataTypes                           AS ArgumentDataTypesAfter,
    FunctionsAfter.ResultDataType                              AS ResultDataTypeAfter,
    FunctionsAfter.Language                                    AS LanguageAfter,
    FunctionsAfter.Type                                        AS TypeAfter,
    FunctionsAfter.Volatility                                  AS VolatilityAfter,
    FunctionsAfter.Owner                                       AS OwnerAfter,
    Diff(FunctionsBefore.Sourcecode,FunctionsAfter.Sourcecode) AS Diff
FROM ReplacedFunctions
INNER JOIN FunctionsBefore ON (FunctionsBefore.FunctionID = ReplacedFunctions.RemovedFunctionID)
INNER JOIN FunctionsAfter  ON (FunctionsAfter.FunctionID  = ReplacedFunctions.NewFunctionID)
)
SELECT innerQ.*, ROW_NUMBER() OVER (), COUNT(*) OVER () FROM innerQ ORDER BY 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
LOOP
    IF _.row_number = 1 THEN
        Changes := Changes || '+-------------------------------+' || E'\n';
        Changes := Changes || '| Updated or replaced functions |' || E'\n';
        Changes := Changes || '+-------------------------------+' || E'\n\n';
    END IF;

    IF _.SchemaBefore = _.SchemaAfter THEN
        Changes := Changes || 'Schema................: ' || _.SchemaAfter || E'\n';
    ELSE
        Changes := Changes || 'Schema................- ' || _.SchemaBefore || E'\n';
        Changes := Changes || 'Schema................+ ' || _.SchemaAfter || E'\n';
    END IF;

    IF _.NameBefore = _.NameAfter THEN
        Changes := Changes || 'Name..................: ' || _.NameAfter || E'\n';
    ELSE
        Changes := Changes || 'Name..................- ' || _.NameBefore || E'\n';
        Changes := Changes || 'Name..................+ ' || _.NameAfter || E'\n';
    END IF;

    IF _.ArgumentDataTypesBefore = _.ArgumentDataTypesAfter THEN
        Changes := Changes || 'Argument data types...: ' || _.ArgumentDataTypesAfter || E'\n';
    ELSE
        Changes := Changes || 'Argument data types...- ' || _.ArgumentDataTypesBefore || E'\n';
        Changes := Changes || 'Argument data types...+ ' || _.ArgumentDataTypesAfter || E'\n';
    END IF;

    IF _.ResultDataTypeBefore = _.ResultDataTypeAfter THEN
        Changes := Changes || 'Result data type......: ' || _.ResultDataTypeAfter || E'\n';
    ELSE
        Changes := Changes || 'Result data type......- ' || _.ResultDataTypeBefore || E'\n';
        Changes := Changes || 'Result data type......+ ' || _.ResultDataTypeAfter || E'\n';
    END IF;

    IF _.LanguageBefore = _.LanguageAfter THEN
        Changes := Changes || 'Language..............: ' || _.LanguageAfter || E'\n';
    ELSE
        Changes := Changes || 'Language..............- ' || _.LanguageBefore || E'\n';
        Changes := Changes || 'Language..............+ ' || _.LanguageAfter || E'\n';
    END IF;

    IF _.TypeBefore = _.TypeAfter THEN
        Changes := Changes || 'Type..................: ' || _.TypeAfter || E'\n';
    ELSE
        Changes := Changes || 'Type..................- ' || _.TypeBefore || E'\n';
        Changes := Changes || 'Type..................+ ' || _.TypeAfter || E'\n';
    END IF;

    IF _.VolatilityBefore = _.VolatilityAfter THEN
        Changes := Changes || 'Volatility............: ' || _.VolatilityAfter || E'\n';
    ELSE
        Changes := Changes || 'Volatility............- ' || _.VolatilityBefore || E'\n';
        Changes := Changes || 'Volatility............+ ' || _.VolatilityAfter || E'\n';
    END IF;

    IF _.OwnerBefore = _.OwnerAfter THEN
        Changes := Changes || 'Owner.................: ' || _.OwnerAfter || E'\n';
    ELSE
        Changes := Changes || 'Owner.................- ' || _.OwnerBefore || E'\n';
        Changes := Changes || 'Owner.................+ ' || _.OwnerAfter || E'\n';
    END IF;

    Changes := Changes || _.Diff || E'\n\n';
END LOOP;



-------------
--- Views ---
-------------



RAISE DEBUG 'Creating ViewsAfter';
CREATE TEMP TABLE ViewsAfter ON COMMIT DROP AS
SELECT * FROM View_Views;

RAISE DEBUG 'Creating AllViews';
CREATE TEMP TABLE AllViews ON COMMIT DROP AS
SELECT ViewID, Schema, Name FROM ViewsAfter
UNION
SELECT ViewID, Schema, Name FROM ViewsBefore;

RAISE DEBUG 'Creating NewViews';
CREATE TEMP TABLE NewViews ON COMMIT DROP AS
SELECT ViewID FROM ViewsAfter
EXCEPT
SELECT ViewID FROM ViewsBefore;

RAISE DEBUG 'Creating RemovedViews';
CREATE TEMP TABLE RemovedViews ON COMMIT DROP AS
SELECT ViewID FROM ViewsBefore
EXCEPT
SELECT ViewID FROM ViewsAfter;

RAISE DEBUG 'Creating ReplacedViews';
CREATE TEMP TABLE ReplacedViews (
RemovedViewID oid,
NewViewID oid
) ON COMMIT DROP;

FOR _ IN SELECT DISTINCT ViewsAfter.Schema, ViewsAfter.Name
FROM RemovedViews, NewViews, ViewsBefore, ViewsAfter
WHERE ViewsBefore.ViewID  = RemovedViews.ViewID
AND   ViewsAfter.ViewID   = NewViews.ViewID
AND   ViewsBefore.Schema  = ViewsAfter.Schema
AND   ViewsBefore.Name    = ViewsAfter.Name
LOOP
    SELECT COUNT(*) INTO _CountRemoved FROM RemovedViews
    INNER JOIN ViewsBefore USING (ViewID)
    WHERE ViewsBefore.Schema = _.Schema AND ViewsBefore.Name = _.Name;

    SELECT COUNT(*) INTO _CountNew FROM NewViews
    INNER JOIN ViewsAfter USING (ViewID)
    WHERE ViewsAfter.Schema = _.Schema AND ViewsAfter.Name = _.Name;

    IF _CountRemoved = 1 AND _CountNew = 1 THEN
        -- Exactly one view removed with identical name as a new view

        SELECT RemovedViews.ViewID INTO STRICT _RemovedViewID FROM RemovedViews
        INNER JOIN ViewsBefore USING (ViewID)
        WHERE ViewsBefore.Schema = _.Schema AND ViewsBefore.Name = _.Name;

        SELECT NewViews.ViewID INTO STRICT _NewViewID FROM NewViews
        INNER JOIN ViewsAfter USING (ViewID)
        WHERE ViewsAfter.Schema = _.Schema AND ViewsAfter.Name = _.Name;

        INSERT INTO ReplacedViews (RemovedViewID,NewViewID) VALUES (_RemovedViewID,_NewViewID);
    END IF;
END LOOP;

RAISE DEBUG 'Deleting ReplacedViews from RemovedViews';
DELETE FROM RemovedViews WHERE ViewID IN (SELECT RemovedViewID FROM ReplacedViews);

RAISE DEBUG 'Deleting ReplacedViews from NewViews';
DELETE FROM NewViews     WHERE ViewID IN (SELECT NewViewID     FROM ReplacedViews);

RAISE DEBUG 'Creating ChangedViews';

CREATE TEMP TABLE ChangedViews ON COMMIT DROP AS
SELECT AllViews.ViewID FROM AllViews
INNER JOIN ViewsBefore ON (ViewsBefore.ViewID = AllViews.ViewID)
INNER JOIN ViewsAfter  ON (ViewsAfter.ViewID  = AllViews.ViewID)
WHERE ViewsBefore.Schema         <> ViewsAfter.Schema
OR ViewsBefore.Name              <> ViewsAfter.Name
OR ViewsBefore.Sourcecode        <> ViewsAfter.Sourcecode
OR ViewsBefore.Owner             <> ViewsAfter.Owner
;

RAISE DEBUG 'Removed views...';

FOR _ IN
SELECT
    RemovedViews.ViewID,
    ViewsBefore.Schema                                     AS SchemaBefore,
    ViewsBefore.Name                                       AS NameBefore,
    ViewsBefore.Owner                                      AS OwnerBefore,
    length(ViewsBefore.Sourcecode)                         AS SourcecodeLength,
    ROW_NUMBER() OVER (),
    COUNT(*) OVER ()
FROM RemovedViews
INNER JOIN ViewsBefore USING (ViewID)
ORDER BY 2,3,4,5
LOOP
    IF _.row_number = 1 THEN
        Changes := Changes || '+---------------+' || E'\n';
        Changes := Changes || '| Removed views |' || E'\n';
        Changes := Changes || '+---------------+' || E'\n\n';
    END IF;
    Changes := Changes || 'Schema................- ' || _.SchemaBefore || E'\n';
    Changes := Changes || 'Name..................- ' || _.NameBefore || E'\n';
    Changes := Changes || 'Owner.................- ' || _.OwnerBefore || E'\n';
    Changes := Changes || 'Source code (chars)...- ' || _.SourcecodeLength || E'\n';
    IF _.row_number = _.count THEN
        Changes := Changes || E'\n\n';
    END IF;
END LOOP;

RAISE DEBUG 'New views...';

FOR _ IN
SELECT
    NewViews.ViewID,
    ViewsAfter.Schema                                     AS SchemaAfter,
    ViewsAfter.Name                                       AS NameAfter,
    ViewsAfter.Owner                                      AS OwnerAfter,
    length(ViewsAfter.Sourcecode)                         AS SourcecodeLength,
    ROW_NUMBER() OVER (),
    COUNT(*) OVER ()
FROM NewViews
INNER JOIN ViewsAfter USING (ViewID)
ORDER BY 2,3,4,5
LOOP
    IF _.row_number = 1 THEN
        Changes := Changes || '+-----------+' || E'\n';
        Changes := Changes || '| New views |' || E'\n';
        Changes := Changes || '+-----------+' || E'\n\n';
    END IF;
    Changes := Changes || 'Schema................+ ' || _.SchemaAfter || E'\n';
    Changes := Changes || 'Name..................+ ' || _.NameAfter || E'\n';
    Changes := Changes || 'Owner.................+ ' || _.OwnerAfter || E'\n';
    Changes := Changes || 'Source code (chars)...+ ' || _.SourcecodeLength || E'\n';
    IF _.row_number = _.count THEN
        Changes := Changes || E'\n\n';
    END IF;
END LOOP;

RAISE DEBUG 'Updated or replaced views...';

FOR _ IN
WITH innerQ AS (
SELECT
    ChangedViews.ViewID,
    ViewsBefore.Schema                                     AS SchemaBefore,
    ViewsBefore.Name                                       AS NameBefore,
    ViewsBefore.Owner                                      AS OwnerBefore,
    ViewsAfter.Schema                                      AS SchemaAfter,
    ViewsAfter.Name                                        AS NameAfter,
    ViewsAfter.Owner                                       AS OwnerAfter,
    Diff(ViewsBefore.Sourcecode,ViewsAfter.Sourcecode) AS Diff
FROM ChangedViews
INNER JOIN ViewsBefore ON (ViewsBefore.ViewID = ChangedViews.ViewID)
INNER JOIN ViewsAfter  ON (ViewsAfter.ViewID  = ChangedViews.ViewID)
UNION ALL
SELECT
    ViewsAfter.ViewID,
    ViewsBefore.Schema                                     AS SchemaBefore,
    ViewsBefore.Name                                       AS NameBefore,
    ViewsBefore.Owner                                      AS OwnerBefore,
    ViewsAfter.Schema                                      AS SchemaAfter,
    ViewsAfter.Name                                        AS NameAfter,
    ViewsAfter.Owner                                       AS OwnerAfter,
    Diff(ViewsBefore.Sourcecode,ViewsAfter.Sourcecode) AS Diff
FROM ReplacedViews
INNER JOIN ViewsBefore ON (ViewsBefore.ViewID = ReplacedViews.RemovedViewID)
INNER JOIN ViewsAfter  ON (ViewsAfter.ViewID  = ReplacedViews.NewViewID)
)
SELECT innerQ.*, ROW_NUMBER() OVER (), COUNT(*) OVER () FROM innerQ ORDER BY 2,3,4,5,6,7,8
LOOP
    IF _.row_number = 1 THEN
        Changes := Changes || '+---------------------------+' || E'\n';
        Changes := Changes || '| Updated or replaced views |' || E'\n';
        Changes := Changes || '+---------------------------+' || E'\n\n';
    END IF;
    IF _.SchemaBefore = _.SchemaAfter THEN
        Changes := Changes || 'Schema................: ' || _.SchemaAfter || E'\n';
    ELSE
        Changes := Changes || 'Schema................- ' || _.SchemaBefore || E'\n';
        Changes := Changes || 'Schema................+ ' || _.SchemaAfter || E'\n';
    END IF;

    IF _.NameBefore = _.NameAfter THEN
        Changes := Changes || 'Name..................: ' || _.NameAfter || E'\n';
    ELSE
        Changes := Changes || 'Name..................- ' || _.NameBefore || E'\n';
        Changes := Changes || 'Name..................+ ' || _.NameAfter || E'\n';
    END IF;

    IF _.OwnerBefore = _.OwnerAfter THEN
        Changes := Changes || 'Owner.................: ' || _.OwnerAfter || E'\n';
    ELSE
        Changes := Changes || 'Owner.................- ' || _.OwnerBefore || E'\n';
        Changes := Changes || 'Owner.................+ ' || _.OwnerAfter || E'\n';
    END IF;

    Changes := Changes || _.Diff || E'\n\n';
END LOOP;

RETURN;
END;
$$;

ALTER FUNCTION public.fdiff(OUT changes text) OWNER TO postgres;
