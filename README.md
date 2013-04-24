# fdiff

Tool to reduce risk for human errors when deploying functions and views in a PostgreSQL database.

## USAGE

    BEGIN;

    -- Temp store state of all views/functions
    SELECT fstage();

    -- Deploy changes to schema
    -- CREATE OR REPLACE FUNCTION ...
    -- CREATE OR REPLACE VIEW ...

    -- Show a diff of changes made
    SELECT fdiff();

    -- If the changes are expected, go ahead and commit
    COMMIT;

## EXAMPLE

    $ psql
    psql (9.1.9)
    Type "help" for help.
    
    amazon=# BEGIN;
    BEGIN
    amazon=#* select fstage();
     fstage 
    --------
     t
    (1 row)
    
    amazon=#* \i /Users/joel/schema/public/FUNCTIONS/process_order.sql
    SET
    CREATE FUNCTION
    ALTER FUNCTION
    amazon=#* select fdiff();
                                                     fdiff                                                  
    --------------------------------------------------------------------------------------------------------
                                                                                                           +
                                                                                                           +
     +-------------------------------+                                                                     +
     | Updated or replaced functions |                                                                     +
     +-------------------------------+                                                                     +
                                                                                                           +
     Schema................: public                                                                        +
     Name..................: process_order                                                                 +
     Argument data types...: _orderid bigint                                                               +
     Result data type......: boolean                                                                       +
     Language..............: plpgsql                                                                       +
     Type..................: normal                                                                        +
     Volatility............: STABLE                                                                        +
     Owner.................: amazon                                                                        +
     20 c     OR Orders.ShippingDate IS NOT NULL                                                           +
     20 c     OR Orders.ShippingDate > now() - interval '2 month'                                          +
                                                                                                           +
                                                                                                           +
                                                                                                           +
     
    (1 row)
    
    amazon=#* COMMIT;
    COMMIT

## INSTALL

    ./install.sh
