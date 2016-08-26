CREATE OR REPLACE VIEW v_sltp AS
SELECT DISTINCT ON (symbol) 
  symbol,
  sl,
  tp,
  lvg
FROM sltp
ORDER BY symbol, dt DESC