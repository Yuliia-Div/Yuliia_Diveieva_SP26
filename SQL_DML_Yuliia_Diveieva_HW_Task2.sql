CREATE TABLE table_to_delete AS
               SELECT 'veeeeeeery_long_string' || x AS col
               FROM generate_series(1,(10^7)::int) x;
-------------------------------------------------------------------------
 SELECT *, pg_size_pretty(total_bytes) AS total,
                                    pg_size_pretty(index_bytes) AS INDEX,
                                    pg_size_pretty(toast_bytes) AS toast,
                                    pg_size_pretty(table_bytes) AS TABLE
               FROM ( SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
                               FROM (SELECT c.oid,nspname AS table_schema,
                                                               relname AS TABLE_NAME,
                                                              c.reltuples AS row_estimate,
                                                              pg_total_relation_size(c.oid) AS total_bytes,
                                                              pg_indexes_size(c.oid) AS index_bytes,
                                                              pg_total_relation_size(reltoastrelid) AS toast_bytes
                                              FROM pg_class c
                                              LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
                                              WHERE relkind = 'r'
                                              ) a
                                    ) a
               WHERE table_name LIKE '%table_to_delete%';  
---------------------------------------------------------------------------------------------------
DELETE FROM table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0;

-- 3. Deleting process takes 44 sec. The table still consumes 575 MB. 

VACUUM FULL VERBOSE table_to_delete;

-- After vacuuming table takes 383 MB + row_estimate shows correct result now
DROP TABLE public.table_to_delete;

CREATE TABLE public.table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x;
---------------------------------------------------------------------------------------------------

TRUNCATE table_to_delete;
-- 4.Execute time here is 0.108s and space, taken by the table, is 8192B. As well as row_estimate is -1.

---------------------------------------------------------------------------------------------------
/*  					  Before	Delete 		Truncate
5.Space consumption:       573MB	 573MB		  8KB
  Execution time:                     44s         0,1s
The difference in execution time is drastic. While "Delete" checks every row and marks it for deleting (but doesn't 
actually delete it), which takes a lot of time, "Truncate" just deletes the old table and creates a new empty one.
"VACUUM FULL" allows you to completely delete ghost data by deleting the old table and creating a new one with the 
relevant data.
"Rollback" is possible for both operations in Postgres.
If we talk about performance and storage, "Delete" allows us to filter data but causes a big load in the process of 
performing the query and further work if we don't use "vacuum".  "Trancate" works fast but it requires a block for 
others, who are using the table.
*/
