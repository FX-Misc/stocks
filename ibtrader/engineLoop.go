package ibtrader

import (
	"reflect"
	"time"

	"github.com/apex/log"
	"github.com/gofinance/ib"
)

func (c *Client) engineLoop() {
	time.Sleep(time.Second)

	c.engine.SubscribeState(c.engineStateCh)
	c.engine.SubscribeAll(c.replyCh)

	c.engine.Send(&ib.RequestIDs{})

	for {
		select {
		case r := <-c.replyCh:
			log.Debugf("RECEIVE - %s", reflect.TypeOf(r))
			switch r.(type) {

			case (*ib.ErrorMessage):
				r, _ := r.(*ib.ErrorMessage)
				log.Errorf("ID: %v Code:%3d Message:'%v'\n", r.ID(), r.Code, r.Message)

			case (*ib.NextValidID):
				r, _ := r.(*ib.NextValidID)
				log.Debugf("OrderId=%v", r.OrderID)
				c.engReadyCh <- signal{}

			case (*ib.Position):
				r, _ := r.(*ib.Position)
				log.Debugf("Position=%+v", r)

				if r.Contract.SecurityType != "STK" {
					continue
				}

				pos := Position{
					r.Contract.Symbol,
					r.Position,
					float64(int(r.AverageCost*100)) / 100,
				}

				c.posMU.Lock()
				c.positions[r.Contract.Symbol] = pos
				c.posMU.Unlock()

				log.WithFields(log.Fields{
					"Sym": pos.Symbol,
					"Qua": pos.Qua,
					"Avg": pos.Price,
				}).Info("Position")

				c.savePosition(pos)

			case (*ib.TickPrice):
				r, _ := r.(*ib.TickPrice)
				log.Debugf("TickPrice=%#v", r)
				c.quoteMU.Lock()

				symbol, ok := c.quoteReqSym[r.ID()]
				if !ok {
					log.Fatalf("Prices without request - %+v", r)
				}

				switch r.Type {
				case 1:
					c.quotes[symbol].Bid = r.Price
				case 2:
					c.quotes[symbol].Ask = r.Price

					log.WithFields(log.Fields{
						"Sym": symbol,
						"Bid": c.quotes[symbol].Bid,
						"Ask": c.quotes[symbol].Ask,
					}).Info("Quote")

					release(c.quoteCh[symbol])
					go c.saveQuote(symbol)
				default:
				}

				c.quoteMU.Unlock()

			case (*ib.PositionEnd):
				c.posCh <- signal{}

			default:
				log.Debugf("%#v\n", r)
			}

		case newstate := <-c.engineStateCh:
			log.Errorf("ERROR: %v\n", newstate)
			if newstate != ib.EngineExitNormal {
				log.Fatalf("ERROR: %v", c.engine.FatalError())
			}
			return
		}
	}
}

func release(ch chan signal) {
	for {
		select {
		case ch <- signal{}:
		default:
			return
		}
	}
}
