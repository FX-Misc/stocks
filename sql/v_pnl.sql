CREATE OR REPLACE VIEW v_pnl AS
SELECT
  p.symbol,
  s.title,
  CASE
      WHEN p.qua > 0 THEN p.qua * (s.bid - p.price)
      ELSE p.qua * (s.ask - p.price)
  END pnl
FROM
  positions p
  LEFT JOIN symbols s ON p.symbol = s.id