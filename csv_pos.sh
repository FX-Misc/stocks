#!/usr/bin/env bash
psql -d stocks -t -c "select symbols.title from positions join symbols on symbols.id = positions.symbol order by symbols.title" > positions.csv
