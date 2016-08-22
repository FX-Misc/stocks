#!/usr/bin/env bash

set -e

PGDATABASE=stocks

pgfutter --db $PGDATABASE --schema public --table tmp_trades csv ~/Jts/trades.csv >> /dev/null
#unlink ~/Jts/trades.csv

psql -q -c "INSERT INTO symbols(title) SELECT UPPER(symbol) FROM tmp_trades ON CONFLICT DO NOTHING" -d $PGDATABASE

psql -q -c "INSERT INTO trades(id, dt, symbol, price, qua, comm)
SELECT
  id,
  to_timestamp(date || time, 'YYYYMMDDHH24:MI:SS') dt,
  (SELECT id FROM symbols WHERE title = symbol),
  price::NUMERIC,
  CASE
    WHEN action = 'SLD' THEN -1 * quantity::INTEGER
    ELSE quantity::INTEGER
  END qua,
  commission::NUMERIC
FROM
  tmp_trades
ON CONFLICT DO NOTHING
" -d $PGDATABASE
psql -q -c "DROP TABLE tmp_trades" -d $PGDATABASE



