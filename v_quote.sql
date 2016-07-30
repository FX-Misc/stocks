CREATE OR REPLACE VIEW v_quotes AS
SELECT 
  DISTINCT ON (symbol) 
  symbol,
  bid,
  ask
 FROM 
   quotes
ORDER BY 
  symbol, dt DESC;