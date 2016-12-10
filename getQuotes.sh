#!/usr/bin/env bash

export PGDATABASE=stocks
export DB_NAME=stocks

QUOTES=`psql -c "SELECT string_agg(title, '+') symbols FROM symbols" -A -t`
wget -q "http://finance.yahoo.com/d/quotes.csv?s=$QUOTES&f=sba" -O quotes.csv
pgfutter --schema public --table tmp_quotes csv --fields=symbol,bid,ask quotes.csv >> /dev/null
unlink quotes.csv
psql -q -c "INSERT
  INTO symbols(title, bid, ask)
SELECT
  symbol,bid::numeric,
  ask::numeric
FROM
  tmp_quotes
WHERE
  bid != 'N/A' AND ask != 'N/A'
ON CONFLICT (title) DO UPDATE SET
  bid = EXCLUDED.bid,
  ask = EXCLUDED.ask"
psql -q -c "DROP TABLE tmp_quotes"