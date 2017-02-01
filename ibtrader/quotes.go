package ibtrader

import (
	"sync"

	"github.com/apex/log"
	"github.com/gofinance/ib"
)

//Quote struct
type Quote struct {
	Bid, Ask float64
}

//RefreshQuote for symbol
func (c *Client) RefreshQuote(symbol string) {
	c.quoteMU.Lock()

	if ch, ok := c.quoteCh[symbol]; ok {
		c.quoteMU.Unlock()
		<-ch
		return
	}

	ch := make(chan signal)
	c.quoteCh[symbol] = ch

	req := &ib.RequestMarketData{
		Contract: c.NewContract(symbol),
		Snapshot: true,
	}

	quoteID := c.nextID()

	c.quoteReqSym[quoteID] = symbol
	c.quotes[symbol] = &Quote{}
	c.quoteMU.Unlock()

	req.SetID(quoteID)

	// log.Debugf("Quote request for %s - ID %d", req.Symbol, req.ID())

	c.engine.Send(req)

	<-ch
}

//RefreshQuotes all
func (c *Client) RefreshQuotes() {
	type Symbol struct {
		Title string
	}
	var symbols []Symbol

	if err := c.db.Model(&symbols).Select(); err != nil {
		log.Fatalf(err.Error())
	}

	wg := new(sync.WaitGroup)
	wg.Add(len(symbols))

	for _, symbol := range symbols {
		go func(s Symbol) {
			c.RefreshQuote(s.Title)
			wg.Done()
		}(symbol)
	}

	wg.Wait()
	log.Debug("RefreshQuotes Done")
}

func (c *Client) saveQuote(symbol string) {
	c.quoteMU.Lock()
	bid, ask := c.quotes[symbol].Bid, c.quotes[symbol].Ask
	c.quoteMU.Unlock()

	type Symbol struct {
		Title    string
		Bid, Ask float64
	}

	quote := Symbol{symbol, bid, ask}

	_, err := c.db.Model(&quote).
		OnConflict("(title) DO UPDATE").
		Set("bid = ?bid").
		Set("ask = ?ask").
		Insert()

	if err != nil {
		log.Fatal(err.Error())
	}

	return
}
