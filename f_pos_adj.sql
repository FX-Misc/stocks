CREATE OR REPLACE FUNCTION public.f_pos_adj(in risk_balance numeric)
  RETURNS TABLE(symbol varchar, qua BIGINT)
AS
$BODY$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(c.symbol, n.symbol)            AS symbol,
    COALESCE(n.qua, 0) - COALESCE(c.qua, 0) AS adjust
  FROM
    v_pos c
    FULL OUTER JOIN f_pos_next(risk_balance) n ON c.symbol = n.symbol
  WHERE
    COALESCE(n.qua, 0) - COALESCE(c.qua, 0) != 0;
END;
$BODY$
LANGUAGE plpgsql VOLATILE;