CREATE OR REPLACE FUNCTION public.f_pos_next(in risk_balance numeric)
  RETURNS TABLE(symbol int, qua BIGINT)
AS
$BODY$
BEGIN
  RETURN QUERY
  WITH risk_curr AS (
    SELECT
      s.symbol,
      ABS(p.qua * (sl-price)) risk_curr,
      p.qua curr_qua
    FROM
      v_sltp s
      LEFT JOIN positions p ON p.symbol = s.symbol
  ), risk_dist AS (
    SELECT
      s.symbol,
      CASE
          WHEN bid > sl THEN ask - sl
          ELSE bid - sl
      END risk_dist
    FROM
      v_sltp s
      LEFT JOIN symbols q ON s.symbol = q.id
    WHERE
      s.sl IS NOT NULL AND s.tp IS NOT NULL
  ), calc AS (
    SELECT
      s.symbol,
      COALESCE(CASE
        WHEN risk_fut.risk > risk_curr THEN f_comm_qua(risk_fut.risk - risk_curr, risk_dist) + curr_qua
        WHEN risk_fut.risk < risk_curr THEN trunc(curr_qua * risk_fut.risk / risk_curr)::BIGINT
        WHEN risk_fut.risk = risk_curr THEN curr_qua
      END, f_comm_qua(risk_fut.risk, risk_dist)) qua
    FROM
      v_sltp s
      LEFT JOIN f_risk(risk_balance) risk_fut ON s.symbol = risk_fut.symbol
      LEFT JOIN risk_curr ON s.symbol = risk_curr.symbol
      LEFT JOIN risk_dist ON s.symbol = risk_dist.symbol
    WHERE
      sl IS NOT NULL AND tp IS NOT NULL
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