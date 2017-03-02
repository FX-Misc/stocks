#!/usr/bin/env bash
psql -d stocks -t -c "select s.title from v_sltp sl join symbols s on s.id = sl.symbol WHERE sl.sl IS NULL AND sl.tp IS NULL order by s.title" > closed.csv
