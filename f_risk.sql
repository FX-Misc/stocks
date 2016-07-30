CREATE OR REPLACE FUNCTION public.f_risk(in risk_balance numeric)
  RETURNS TABLE(symbol varchar, risk numeric)
AS
$BODY$
BEGIN
  RETURN QUERY
  SELECT
    s.symbol,
    trunc(risk_balance * s.lvg / SUM(s.lvg) OVER ()) risk
  FROM
    v_sltp s
  WHERE
    sl IS NOT NULL AND tp IS NOT NULL;
END;
$BODY$
LANGUAGE plpgsql VOLATILE;