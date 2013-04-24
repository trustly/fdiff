CREATE LANGUAGE plperlu;

BEGIN;
\i VIEWS/view_views.sql
\i VIEWS/view_functions.sql
\i FUNCTIONS/diff.sql
\i FUNCTIONS/fstage.sql
\i FUNCTIONS/fdiff.sql
COMMIT;
