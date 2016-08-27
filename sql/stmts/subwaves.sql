INSERT INTO waves (
  symbol,
  mw_id,
  mw_parent,
  degree,
  wave,
  part,
  start_dt,
  start_price,
  finish_dt,
  finish_price
)
SELECT
  $1::INT symbol,
  $2::INT mw_id,
  $3::INT mw_parent,
  id-1 degree,
  $5::wave wave,
  $6::part part,
  to_timestamp($7::INT) start_dt,
  $8::NUMERIC start_price,
  to_timestamp($9::INT) finish_dt,
  $10::NUMERIC finish_price
FROM
  degrees
WHERE
  title = $4::TEXT
ON CONFLICT (
  symbol,
  start_dt,
  start_price,
  finish_dt,
  finish_price
) DO UPDATE SET
  mw_id = CASE WHEN waves.mw_id = 0 THEN EXCLUDED.mw_id ELSE waves.mw_id END,
  part = COALESCE(waves.part, EXCLUDED.part)