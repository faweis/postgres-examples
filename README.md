# Postgres Indexes and other stuff


In database systems, **B-tree**, **hash**, and **BRIN** (and more) are all types of indexes, but they differ significantly in their structure, use cases, and performance characteristics. Understanding these differences is crucial for optimizing database performance through appropriate index selection.<br>
Here’s a brief overview.

### B-tree Index
- **Structure**: A B-tree index is a balanced tree structure that keeps data sorted and allows searches, sequential access, insertions, and deletions in logarithmic time. The "B" in B-tree stands for balanced or broad, indicating that the tree is wide and shallow, minimizing disk reads.
- **Use Cases**: B-tree indexes are the most common type of index and are well-suited for a wide range of queries, including equality searches, range queries, and ordering results. They are effective for both unique and non-unique values.
- **Performance**: Provides excellent performance for a broad range of operations, particularly because they keep data sorted, allowing for efficient range scans.
### Hash Index
- **Structure**: A hash index uses a hash table where keys are processed through a hash function. The outcome of the function determines where the key-value pairs are stored in the index. It’s designed for efficient direct lookup.
- **Use Cases**: Hash indexes are optimized for **equality searches** (i.e., finding the exact match). They are not suitable for range queries or ordering results since the hash function does not preserve the order of keys.
- **Performance**: Provides very fast data retrieval for equality searches but lacks the versatility of B-trees. Not suitable for finding ranges of values or supporting ordering operations.
### BRIN
- **Structure:** A BRIN index stores summaries of the values stored in contiguous blocks (ranges) of a table. Instead of indexing every single row, BRIN indexes "summarize" blocks of rows. This approach is efficient for very large tables where data is naturally ordered or can be ordered by some criteria.
- **Use Cases:** BRIN indexes are ideal for large tables with a natural or **physical ordering** of rows, such as timestamps in a logging table. They are used to quickly filter down the blocks that need to be scanned for a query, significantly reducing I/O for range queries.
- **Performance:** Offers significant performance benefits for large datasets with naturally ordered data, especially when the index can fit into memory. However, they are less effective for tables without some form of ordering or where data is frequently updated in a way that disrupts the physical order.
### GIN Indexes
Purpose: GIN indexes are optimized for handling cases where the indexed column contains multiple values per row. They are particularly well-suited for indexing array data and full-text search vectors.
- **Structure:** GIN indexes are generalized inverted indexes that store a list of keys for each row, allowing for efficient indexing of multiple values in a single column.
- **Use Cases:** GIN indexes are ideal for full-text search, indexing JSONB objects in which you query for key/value containment, and indexing large arrays where you often query for element presence.
- **Performance:** GIN indexes are highly efficient for read-heavy operations, especially for queries that involve containment (@>), overlap (&&), or text search operations. However, they can be slower to update than GiST indexes because GIN indexes have to add or remove multiple index entries for a single record update.
### GiST Indexes
- **Structure:** GiST indexes are generalized search trees.
- **Performance:** GiST indexes generally offer faster write performance compared to GIN indexes, making them suitable for workloads with a higher proportion of write operations. However, for certain types of queries, GiST indexes may not be as fast as GIN indexes.
- **Use Cases** : GiST indexes are commonly used for spatial data queries, such as those enabled by the PostGIS extension. They're also used for range data types, nearest-neighbor searches, and other scenarios where a more generalized search tree can provide efficient querying.
### XXX Indexes ...

## Try it out
### Let's create a table per index with some data.
```plpgsql
-- Table for BTREE indexes
CREATE TABLE idx_btree (
  id TEXT NOT NULL DEFAULT gen_random_uuid(),
  ts TIMESTAMP WITHOUT TIME ZONE
);

-- Table for HASH indexes
CREATE TABLE idx_hash (
  id TEXT NOT NULL DEFAULT gen_random_uuid(),
  ts TIMESTAMP WITHOUT TIME ZONE
);

-- Table for BRIN indexes
CREATE TABLE idx_brin (
  id TEXT NOT NULL DEFAULT gen_random_uuid(),
  ts TIMESTAMP WITHOUT TIME ZONE
);
```
Insert data some data...
```plpgsql
-- Insert data into idx_btree
INSERT INTO idx_btree (ts)
SELECT generate_series(
    '1800-01-01 00:00:00'::timestamp,
    '2024-12-31 23:00:00'::timestamp,
    '1 HOUR'::interval
);

-- Insert data into idx_hash
INSERT INTO idx_hash (ts)
SELECT generate_series(
    '1800-01-01 00:00:00'::timestamp,
    '2024-12-31 23:00:00'::timestamp,
    '1 HOUR'::interval
);

-- Insert data into idx_brin
INSERT INTO idx_brin (ts)
SELECT generate_series(
    '1800-01-01 00:00:00'::timestamp,
    '2024-12-31 23:00:00'::timestamp,
    '1 HOUR'::interval
);
```

Let's create the indexes
```plpgsql
-- Indexes for idx_btree
CREATE INDEX idx_btree_id_idx ON idx_btree USING btree(id);
CREATE INDEX idx_btree_ts_idx ON idx_btree USING btree(ts);

-- Indexes for idx_hash
CREATE INDEX idx_hash_id_idx ON idx_hash USING hash(id);
CREATE INDEX idx_hash_ts_idx ON idx_hash USING hash(ts);

-- Indexes for idx_brin
CREATE INDEX idx_brin_id_idx ON idx_brin USING brin(id);
CREATE INDEX idx_brin_ts_idx ON idx_brin USING brin(ts);
```

Update the indexes (Should not be necessary, as we just created them)
```plpgsql
VACUUM ANALYZE;
```
Also helpful could be
- `REINDEX` or `REINDEX TABLE table_name;`
- `CLUSTER table_name USING idx_name;`

### Check the size of the index.
```plpgsql
SELECT
    pg_size_pretty(pg_relation_size('idx_btree_id_idx')) AS idx_btree_id_size,
    pg_size_pretty(pg_relation_size('idx_btree_ts_idx')) AS idx_btree_ts_size,
    pg_size_pretty(pg_relation_size('idx_hash_id_idx')) AS idx_hash_id_size,
    pg_size_pretty(pg_relation_size('idx_hash_ts_idx')) AS idx_hash_ts_size,
    pg_size_pretty(pg_relation_size('idx_brin_id_idx')) AS idx_brin_id_size,
    pg_size_pretty(pg_relation_size('idx_brin_ts_idx')) AS idx_brin_ts_size;
```

### Analyze the performance
```plpgsql
explain select "id", "ts" from idx_btree where "id" = '12334566';
explain select "id", "ts" from idx_hash where "id" = '12334566';
explain select "id", "ts" from idx_brin where "id" = '12334566';

explain analyze select "id", "ts" from idx_btree where "ts" between '2002-01-01T10:00:00' and '2002-01-10T11:00:00';
explain analyze select "id", "ts" from idx_hash where "ts" between '2002-01-01T10:00:00' and '2002-01-10T11:00:00';
explain analyze select "id", "ts" from idx_brin where "ts" between '2002-01-01T10:00:00' and '2002-01-10T11:00:00';  -- Improves at large datasets, e.g. log tables.

explain analyze select "id", "ts" from idx_btree where "ts" = '2002-01-01T10:00:00'::TIMESTAMP;
explain analyze select "id", "ts" from idx_hash where "ts" = '2002-01-01T10:00:00'::TIMESTAMP;
explain analyze select "id", "ts" from idx_brin where "ts" = '2002-01-01T10:00:00'::TIMESTAMP;  -- Improves at large datasets, e.g. log tables.

CREATE INDEX idx_btree_ts_idx_partial ON idx_btree USING btree(ts) where "ts" > '2023-01-01T00:00:00';
explain analyze select "id", "ts" from idx_btree where "ts" = '2002-01-01T10:00:00'::TIMESTAMP;
explain analyze select "id", "ts" from idx_btree where "ts" = '2023-02-01T10:00:00'::TIMESTAMP;
```
*\*Note: Due to the amount of data here, the `ANALYZE` part is not always representative here.*

## Some other indexes for special purposes.
#### Indexing JSONB data
```plpgsql
CREATE TABLE idx_jsonb (
  id SERIAL PRIMARY KEY,
  data JSONB
);
```
Insert some data
```plpgsql
DO $$
BEGIN
  FOR i IN 1..1000 LOOP
    INSERT INTO idx_jsonb (data)
    VALUES (jsonb_build_object('Bug', 'Value ' || i, 'Error ' || i, i));
  END LOOP;
END$$;
```
Create an index on the `Bug` key.
```plpgsql
CREATE INDEX idx_jsonb_firstname ON idx_jsonb ((data->>'Bug'));
```
*\*Creates a B-tree index on the `Bug` key.*<br><br>
Check the query plan.
```plpgsql
EXPLAIN SELECT * FROM idx_jsonb WHERE data->>'Bug' = 'Value 69';
EXPLAIN SELECT * FROM idx_jsonb WHERE data->>'Error' = '69';
```

#### Indexing Arrays
```plpgsql
CREATE TABLE idx_array (
  id SERIAL PRIMARY KEY,
  data TEXT[]
);
```
Insert some data
```plpgsql
DO $$
BEGIN
  FOR i IN 1..1000 LOOP
    INSERT INTO idx_array (data)
    VALUES (ARRAY['Value ' || i, 'Error ' || i]);
  END LOOP;
END$$;
```
Create an index on the `data` column.
```plpgsql
CREATE INDEX idx_array_data ON idx_array USING GIN (data);
```
Check the query plan.
```plpgsql
EXPLAIN SELECT * FROM idx_array WHERE data @> ARRAY['Value 69'];
```

#### Indexing Geometric Data
```plpgsql
CREATE TABLE idx_geom (
  id SERIAL PRIMARY KEY,
  data BOX
);
```
Insert some data
```plpgsql
DO $$
BEGIN
  FOR i IN 1..1000 LOOP
    INSERT INTO idx_geom (data)
    VALUES (BOX(POINT(0, 0), POINT(1, 1)));
  END LOOP;
END$$;
```
Create an index on the `data` column.
```plpgsql
CREATE INDEX idx_geom_data ON idx_geom USING GIST (data);
```
Check the query plan.
```plpgsql
EXPLAIN SELECT * FROM idx_geom WHERE data @> BOX(POINT(0, 0), POINT(1, 1));
```

#### Composite Indexes
```plpgsql
CREATE TABLE idx_composite (
  id SERIAL PRIMARY KEY,
  data1 TEXT,
  data2 TEXT
);
```
Insert some data
```plpgsql
DO $$
BEGIN
  FOR i IN 1..1000 LOOP
    INSERT INTO idx_composite (data1, data2)
    VALUES ('Value ' || i, 'Error ' || i);
  END LOOP;
END$$;
```
Create an index on the `data1` and `data2` columns.
```plpgsql
CREATE INDEX idx_composite_data ON idx_composite (data1, data2);
```
Check the query plan.
```plpgsql
EXPLAIN SELECT * FROM idx_composite WHERE data1 = 'Value 69' AND data2 = 'Error 69';
EXPLAIN SELECT * FROM idx_composite WHERE data2 = 'Error 70';
```

- Index on expression (e.g., lower(column))
- Partial index (e.g., where column > value)
- Index with included columns
- Unique index
- ...

#### Exclusion Constraints
```plpgsql
CREATE TABLE idx_gist (
  id SERIAL PRIMARY KEY,
  location_id text default '1',
  ts_range tsrange NOT null,
  status text default 'successful'
);
```
Insert some timeranges.
```plpgsql
INSERT INTO idx_gist (ts_range)
SELECT tsrange(gs, gs + '1 hour'::interval, '[)')
FROM generate_series(
    '2023-01-01 00:00:00'::timestamp,
    '2024-12-31 23:00:00'::timestamp,
    '1 hour'::interval
) AS gs;
```

Add an exclusion CONSTRAINT
```plpgsql
ALTER TABLE idx_gist ADD CONSTRAINT no_overlapping_timespans
  EXCLUDE USING gist (
    "ts_range" WITH &&,
    "location_id" with =
  )
  WHERE (status = 'successful');
```
Insert a new timerange
```plpgsql
insert into idx_gist ("ts_range") values (tsrange('2020-01-01T10:00:00', '2021-01-01T00:00:00', '[)'));
```
Try to insert a conflicting timerange
```plpgsql
insert into idx_gist ("ts_range") values (tsrange('2021-01-01T10:00:00', '2022-01-01T00:00:00', '[)'));
insert into idx_gist ("ts_range") values (tsrange('2021-06-01T10:00:00', '2022-06-01T00:00:00', '[)'));
```

## Check the usage of indexes
This is very helpful for debugging together with the `EXPLAIN` command.
```plpgsql
SELECT 
    relname AS table_name, 
    indexrelname AS index_name, 
    idx_scan, 
    idx_tup_read, 
    idx_tup_fetch
FROM 
    pg_stat_user_indexes
JOIN 
    pg_indexes ON pg_indexes.indexname = pg_stat_user_indexes.indexrelname
ORDER BY 
    relname, 
    indexrelname;
```
## CTEs
Materialized
```plpgsql
EXPLAIN WITH january as MATERIALIZED (
  SELECT * FROM idx_btree WHERE extract('month'FROM "ts") = 1
)
SELECT * FROM january j1 JOIN january j2 USING("ts") JOIN january j3 USING("ts") JOIN january j4 USING("ts") JOIN january j5 USING("ts")
WHERE extract('year' FROM "ts") = 2022;
```
Not materialized
```plpgsql
EXPLAIN WITH january as not MATERIALIZED (
  SELECT * FROM idx_btree WHERE extract('month'FROM "ts") = 1
)
SELECT * FROM january j1 JOIN january j2 USING("ts") JOIN january j3 USING("ts") JOIN january j4 USING("ts") JOIN january j5 USING("ts")
WHERE extract('year' FROM "ts") = 2022;
```

## Some other things
### The query planner in timeranges.
```plpgsql
explain select * from 
  generate_series(
    '2023-01-01 00:00:00'::timestamp,
    '2024-12-31 23:00:00'::timestamp,
    '1 hour'::interval
) fee
```
Solution
```plpgsql
explain select * from (
  SELECT '2023-11-01T00:00:00'::TIMESTAMP + ('1 DAY'::INTERVAL)*x.i::INTEGER dt
  FROM generate_series(0,EXTRACT(DAY FROM '2023-11-30T00:00:00'::TIMESTAMP - '2023-11-01T00:00:00'::TIMESTAMP)::INTEGER) as x(i)
) fee
```

### Time functions in postgres
```plpgsql
CREATE TABLE times (
  ts_now TIMESTAMP,
  ts_clock_timestamp TIMESTAMP
);
```
Create function that inserts both.
```plpgsql
CREATE OR REPLACE FUNCTION insert_current_time() RETURNS void AS $$
BEGIN
  -- Insert the current time into the table using different functions
  INSERT INTO times (ts_now, ts_clock_timestamp)
  VALUES (NOW(), CLOCK_TIMESTAMP());
 
  PERFORM pg_sleep(2);
  -- Insert the current time into the table using different functions
  INSERT INTO times (ts_now, ts_clock_timestamp)
  VALUES (NOW(), CLOCK_TIMESTAMP());
END;
$$ LANGUAGE plpgsql;
```

```plpgsql
SELECT insert_current_time();
```
```plpgsql
select * from times;
```


