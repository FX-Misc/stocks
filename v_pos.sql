CREATE OR REPLACE VIEW v_pos AS
 SELECT
   trades.symbol,
    sum(trades.qua) AS qua,
    sum(trades.qua * trades.price) / sum(trades.qua) AS price
  FROM trades
  GROUP BY trades.symbol
 HAVING sum(trades.qua) <> 0;