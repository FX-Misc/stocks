package main

import (
	"os"
	"time"

	"github.com/apex/log"
	"github.com/apex/log/handlers/text"
	"github.com/joho/godotenv"

	"github.com/santacruz123/stocks/ibtrader"
)

func main() {
	godotenv.Load()

	log.SetHandler(text.New(os.Stdout))
	log.SetLevel(log.InfoLevel)

	ib, err := ibtrader.NewClient()
	if err != nil {
		log.Fatal(err.Error())
	}

	defer ib.Stop()

	ib.RefreshPositions()
	ib.RefreshQuotes()

	np := ib.NextPositions()

	log.Infof("NextPositions %#v", np)

	for symbol, qua := range np {
		currQua, _ := ib.Position(symbol)
		if orderQua := qua - currQua; orderQua != 0 {
			ib.Order(symbol, int64(orderQua), 0, true)
		}
	}

	time.Sleep(time.Second * 2)
}
