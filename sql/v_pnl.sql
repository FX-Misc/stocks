CREATE OR REPLACE VIEW v_pnl AS
SELECT
  p.symbol,
  CASE
      WHEN p.qua > 0 THEN p.qua * (q.bid - p.price)
      ELSE p.qua * (q.ask - p.price)
  END pnl
FROM
  v_pos p
  LEFT JOIN v_quotes q ON p.symbol = q.symbol