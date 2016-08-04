CREATE OR REPLACE VIEW v_pos AS
WITH RECURSIVE pos AS
  ( SELECT * FROM (
          SELECT DISTINCT ON (symbol)
               t.*,  0::numeric  AS pnl,
                     qua         AS pos,
                     price       AS p_price
           FROM public.trades AS t
           ORDER BY symbol, dt
         ) AS starting
    UNION ALL
    SELECT
        n.*,
        c.pnl,
        p.pos + n.qua,
        CASE
          WHEN p.pos > 0 AND n.qua > 0 THEN (p.p_price * p.pos + n.price * n.qua) / (p.pos + n.qua)
          WHEN p.pos < 0 AND n.qua < 0 THEN (p.p_price * p.pos + n.price * n.qua) / (p.pos + n.qua)
          WHEN p.pos / n.qua < 0 AND p.pos > n.qua THEN p.p_price
          WHEN p.pos / n.qua < 0 AND p.pos < n.qua THEN n.price
          ELSE 0
        END
    FROM
        pos AS p,
        LATERAL
        ( SELECT t.* FROM trades AS t
          WHERE t.symbol = p.symbol AND t.dt > p.dt ORDER BY t.dt  LIMIT 1
        ) AS n,
        LATERAL (
          SELECT
            CASE
              WHEN p.pos < 0 AND n.qua > 0 AND -p.pos > n.qua THEN n.qua * (p.p_price - n.price)
              WHEN p.pos < 0 AND n.qua > 0 AND -p.pos < n.qua THEN p.pos * (p.p_price - n.price)
              WHEN p.pos > 0 AND n.qua < 0 AND p.pos > -n.qua THEN n.qua * (p.p_price - n.price)
              WHEN p.pos > 0 AND n.qua < 0 AND p.pos < -n.qua THEN p.pos * (p.p_price - n.price)
              ELSE 0
            END pnl,
            p.pos * p.price cb
        ) AS c
  )
SELECT symbol, qua::BIGINT, price FROM (
  SELECT
    DISTINCT ON (symbol)
    symbol,
    pos qua,
    p_price price
  FROM pos
    WHERE qua != 0
  ORDER BY symbol, dt DESC
) as tmp
WHERE tmp.qua != 0
