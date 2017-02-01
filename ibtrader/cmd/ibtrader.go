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
	log.SetLevel(log.DebugLevel)

	ib, err := ibtrader.NewClient()
	if err != nil {
		log.Fatal(err.Error())
	}

	defer ib.Stop()

	ib.RefreshPositions()
	log.Infof("AAPL %v", ib.Position("AAPL"))

	np := ib.NextPositions()

	log.Infof("NextPositions %#v", np)

	for symbol, qua := range np {
		currQua := ib.Position(symbol)
		if orderQua := qua - currQua; orderQua != 0 {
			ib.Order(symbol, int64(orderQua), 0, true)
		}
	}

	time.Sleep(time.Second * 2)
}
