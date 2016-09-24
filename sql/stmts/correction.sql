UPDATE
  waves
SET
  wave = 'correction'::wave
FROM
  waves w
  JOIN waves sw ON
                  w.symbol = sw.symbol
                  AND w.id != sw.id
                  AND sw.start_dt >= w.start_dt
                  AND sw.finish_dt <= w.finish_dt
                  AND w.degree = sw.degree + 1
WHERE
  w.id = waves.id
  AND w.wave = 'impulse'
  AND sw.part = 'b';

SELECT * FROM waves;