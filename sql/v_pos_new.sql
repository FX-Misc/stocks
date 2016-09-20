SELECT
  t.id, t.price, t.qua,
  SUM(t2.qua) qua2
FROM
  trades t
  LEFT JOIN trades t2 ON t.symbol = t2.symbol AND t2.dt < t.dt
WHERE
  t.symbol = 'FB'
GROUP BY
  t.id, t.price, t.qua
ORDER BY
  t.dt