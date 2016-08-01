CREATE OR REPLACE VIEW v_pos AS
WITH pnl as (
  SELECT
    id,
    SUM(qua) OVER s pos,
    CASE
      WHEN (SUM(qua) OVER s)::NUMERIC / qua < 0 THEN qua * (lag(price) OVER s - price)
      ELSE 0
    END pnl
  FROM trades
  WINDOW s AS (PARTITION BY symbol ORDER BY dt)
), calc AS (
    SELECT
      symbol,
      t.id,
      dt,
      SUM(qua) OVER s qua,
      SUM(qua * price + pnl) OVER s / SUM(qua) OVER s price
    FROM
      trades t
      LEFT JOIN pnl ON t.id = pnl.id
    WHERE
      pnl.pos != 0
    WINDOW s AS ( PARTITION BY symbol ORDER BY dt )
)
SELECT
  DISTINCT ON (symbol)
  symbol,
  qua,
  price
FROM
  calc
ORDER BY symbol, dt DESC
