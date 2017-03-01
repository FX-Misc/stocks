CREATE OR REPLACE FUNCTION public.f_pos_next(in risk_balance numeric)
  RETURNS TABLE(symbol int, qua BIGINT)
AS
$BODY$
BEGIN
  RETURN QUERY
  WITH r_cur AS (
--     CREATE TEMPORARY TABLE r_cur AS
    SELECT
      s.id symbol,
      COALESCE(CASE
        WHEN p.qua > 0 THEN (s.bid - p.price) * p.qua
        ELSE (p.price - s.ask) * -p.qua
      END, 0) r_cur,
      COALESCE(p.qua,0) qua
    FROM
      symbols s
      LEFT JOIN positions p ON p.symbol = s.id
  ), r_dis AS (
--     CREATE TEMPORARY TABLE r_dis AS
    SELECT
      s.symbol,
      CASE
          WHEN bid > sl THEN ask - sl
          ELSE bid - sl
      END r_dis
    FROM
      v_sltp s
      JOIN symbols q ON s.symbol = q.id
    WHERE
      s.sl IS NOT NULL AND s.tp IS NOT NULL
  ), calc AS (
    SELECT
      s.symbol,
      TRUNC(CASE
        WHEN r_cur.qua != 0 THEN
          CASE
            WHEN r_fut.risk + r_cur.r_cur < 0 THEN r_fut.risk / r_dis.r_dis - r_cur.qua
            ELSE
              CASE
                WHEN r_cur.r_cur > 0 THEN r_fut.risk / r_dis.r_dis
                ELSE (r_fut.risk + r_cur.r_cur) / r_dis.r_dis
              END
          END
        ELSE r_fut.risk / r_dis.r_dis
      END) qua
    FROM
      v_sltp s
      LEFT JOIN symbols ss ON s.symbol = ss.id
      LEFT JOIN f_risk(risk_balance) r_fut ON s.symbol = r_fut.symbol
      LEFT JOIN r_cur ON s.symbol = r_cur.symbol
      LEFT JOIN r_dis ON s.symbol = r_dis.symbol
    WHERE
      sl IS NOT NULL AND tp IS NOT NULL
      AND ss.bid != 0 AND ss.ask != 0
  )
  SELECT
    calc.symbol,
    calc.qua
  FROM
      calc
  WHERE
    calc.qua != 0;
END;
$BODY$
LANGUAGE plpgsql VOLATILE;