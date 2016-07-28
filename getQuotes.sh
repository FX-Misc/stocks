#!/usr/bin/env bash

set -e

PGDATABASE=stocks

QUOTES="`psql -c "SELECT
  string_agg(t.symbol, '+') symbols
FROM (
  SELECT
    DISTINCT symbol
  FROM
    trades
  UNION
  SELECT
    DISTINCT symbol
  FROM
    sltp
) as t
" -A -t -d $PGDATABASE`"
wget -q "http://finance.yahoo.com/d/quotes.csv?s=$QUOTES&f=sba" -O quotes.csv
pgfutter --db $PGDATABASE --schema public --table tmp_quotes csv --fields=symbol,bid,ask quotes.csv >> /dev/null
unlink quotes.csv
psql -q -c "INSERT INTO quotes(dt, symbol,bid,ask) SELECT now(), symbol,bid::numeric,ask::numeric FROM tmp_quotes" -d $PGDATABASE
psql -q -c "DROP TABLE tmp_quotes" -d $PGDATABASE



