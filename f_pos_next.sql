CREATE OR REPLACE FUNCTION public.f_pos_next(in risk_balance numeric)
  RETURNS TABLE(symbol varchar, qua BIGINT)
AS
$BODY$
BEGIN
  RETURN QUERY
  SELECT
    s.symbol,
    trunc( CASE
      WHEN risk - coalesce(p_risk,0) > 0 THEN (risk - coalesce(p_risk,0)) / r_dist + coalesce(p.qua,0)
      ELSE risk / r_dist
    END )::BIGINT qua
  FROM
    (
      SELECT
        s.symbol,
        sl,
        tp,
        risk_balance / count(*) OVER () risk
      FROM
        v_sltp s
      WHERE
        sl IS NOT NULL AND tp IS NOT NULL
    ) as s
    LEFT JOIN v_quotes q ON s.symbol = q.symbol
    LEFT JOIN v_pos p ON p.symbol = s.symbol
    LEFT JOIN (
      SELECT
        p.symbol,
        ABS(p.qua * (p.price - s.sl))::BIGINT p_risk
      FROM
        v_pos p
        LEFT JOIN v_sltp s ON p.symbol = s.symbol
      WHERE
        sl IS NOT NULL AND tp IS NOT NULL
    ) as pr ON s.symbol = pr.symbol
    LEFT JOIN LATERAL (
      SELECT
        q.symbol,
        CASE
          WHEN bid > sl THEN ask - sl
          ELSE bid - sl
        END r_dist
    ) as rd ON s.symbol = rd.symbol
    WHERE trunc((risk - coalesce(p_risk,0)) / r_dist + coalesce(p.qua,0)) != 0;
END;
$BODY$
LANGUAGE plpgsql VOLATILE;