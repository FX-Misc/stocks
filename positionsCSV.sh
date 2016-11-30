#!/usr/bin/env bash
psql -d stocks -t -c "select symbols.title from v_sltp left join symbols on symbols.id = v_sltp.symbol order by symbols.title" > positions.csv
