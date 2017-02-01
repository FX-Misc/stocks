package ibtrader

import (
	"math"
	"os"
	"strconv"
	"sync"
	"sync/atomic"

	"github.com/apex/log"
	"github.com/gofinance/ib"

	"gopkg.in/pg.v5"
)

type signal struct{}

//Quote struct
type Quote struct {
	Bid, Ask float64
}

//Client struct
type Client struct {
	db *pg.DB

	engine        *ib.Engine
	engineStateCh chan ib.EngineState
	engReadyCh    chan signal
	replyCh       chan ib.Reply

	orderID    int64
	dryRun     bool
	riskAmount uint64

	positions map[string]float64

	//Positions

	posMU   *sync.Mutex
	posCh   chan signal
	posCond *sync.Cond
	posBool bool

	//Quotes

	quoteCh     map[string]chan signal
	quoteReqSym map[int64]string
	quoteMU     *sync.Mutex
	quotes      map[string]*Quote
}

//NewClient for Interactive brokers communications
func NewClient() (c *Client, err error) {

	c = &Client{}

	if os.Getenv("DRY") != "" {
		c.dryRun = true
	}

	if s, err := strconv.Atoi(os.Getenv("RISK")); err == nil {
		c.riskAmount = uint64(s)
	}

	c.posMU = &sync.Mutex{}
	c.posCh = make(chan signal)
	c.positions = make(map[string]float64)
	c.posCond = &sync.Cond{L: &sync.Mutex{}}

	c.quoteMU = &sync.Mutex{}

	c.quoteCh = make(map[string]chan signal)
	c.quoteReqSym = make(map[int64]string)
	c.quotes = make(map[string]*Quote)
	c.engReadyCh = make(chan signal)

	opt, err := pg.ParseURL(os.Getenv("PG"))
	if err != nil {
		return
	}

	c.db = pg.Connect(opt)

	gateway := os.Getenv("IB_GATEWAY")

	if gateway == "" {
		gateway = "localhost:7497"
	}

	c.engine, err = ib.NewEngine(ib.EngineOptions{
		Gateway: gateway,
	})

	if err != nil {
		return
	}

	c.engineStateCh = make(chan ib.EngineState)
	c.replyCh = make(chan ib.Reply)

	go c.engineLoop()

	<-c.engReadyCh

	return
}

//Stop IB client
func (c *Client) Stop() {
	c.engine.Stop()
}

//RefreshPositions in one thread - others wait for result
func (c *Client) RefreshPositions() {
	c.posCond.L.Lock()
	defer c.posCond.L.Unlock()

	if c.posBool {
		c.posCond.Wait()
	} else {
		c.posBool = true
		c.posCond.L.Unlock()

		c.engine.Send(&ib.RequestPositions{})
		<-c.posCh
		log.Debugf("Positions updated - %#v", c.positions)

		c.posCond.L.Lock()
		c.posBool = false
		c.posCond.Broadcast()
	}
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

func (c *Client) saveQuote(symbol string) {
	c.quoteMU.Lock()
	bid, ask := c.quotes[symbol].Bid, c.quotes[symbol].Ask
	c.quoteMU.Unlock()

	_, err := c.db.Exec(
		`UPDATE symbols SET bid = ?, ask = ? WHERE title = ?`, bid, ask, symbol,
	)

	if err != nil {
		log.Fatal(err.Error())
	}

	return
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

func (c *Client) nextID() int64 {
	return atomic.AddInt64(&c.orderID, 1)
}

//NewContract const
func (c *Client) NewContract(symbol string) ib.Contract {
	return ib.Contract{
		Symbol:       symbol,
		SecurityType: "STK", //STK CFD
		Exchange:     "SMART",
		Currency:     "USD",
	}
}

func (c *Client) newOrder(gtc bool) (order ib.Order) {
	order, _ = ib.NewOrder()

	order.TIF = "DAY"
	if gtc {
		order.TIF = "GTC"
	}

	return
}

//Order send
func (c *Client) Order(symbol string, qua int64, price float64, gtc bool) {

	request := ib.PlaceOrder{
		Contract: c.NewContract(symbol),
	}

	request.Order = c.newOrder(gtc)

	if qua < 0 {
		request.Order.Action = "SELL"
	} else {
		request.Order.Action = "BUY"
	}

	request.Order.TotalQty = int64(math.Abs(float64(qua)))

	priceLog := ""

	if price == 0 {
		request.Order.OrderType = "MKT"
		priceLog = request.Order.OrderType
	} else {
		request.Order.OrderType = "LMT"
		request.Order.LimitPrice = price
		priceLog = strconv.FormatFloat(price, 'f', 2, 64)
	}

	request.SetID(c.nextID())

	if !c.dryRun {
		c.engine.Send(&request)
	}

	log.Infof("%s %d %s @ %s", request.Order.Action, request.Order.TotalQty, symbol, priceLog)
}

//NextPositions getter
func (c *Client) NextPositions() (pos map[string]float64) {
	pos = make(map[string]float64)

	type Position struct {
		Symbol string
		Qua    float64
	}

	var tmp []Position
	_, err := c.db.Query(&tmp, `SELECT
			s.title symbol,
			x.qua
	  FROM
	    f_pos_next(?) as x
	    LEFT JOIN symbols  as s ON x.symbol = s.id`, c.riskAmount)

	if err != nil {
		log.Fatal(err.Error())
	}

	for _, one := range tmp {
		pos[one.Symbol] = one.Qua
	}

	return
}

//Position by symbol
func (c *Client) Position(symbol string) float64 {
	c.posMU.Lock()
	defer c.posMU.Unlock()
	if qua, ok := c.positions[symbol]; ok {
		return qua
	}
	return 0
}
