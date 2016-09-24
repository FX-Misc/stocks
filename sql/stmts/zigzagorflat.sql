CREATE OR REPLACE FUNCTION f_corrections() RETURNS void AS
$BODY$
DECLARE
  ru INT DEFAULT 1;
BEGIN

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

    WHILE ru != 0 LOOP
        WITH times AS (
        UPDATE
          waves
        SET
          wave = CASE
                 WHEN sw.wave IN ('impulse', 'leading', 'ending')
                   THEN 'zigzag' :: wave
                 ELSE 'flat' :: wave
                 END
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
          AND w.wave = 'correction'
          AND sw.part = 'a'
        RETURNING 1
      )
      SELECT count(*) INTO ru from times;
    END LOOP;
END
$BODY$
LANGUAGE plpgsql;


select f_corrections();

