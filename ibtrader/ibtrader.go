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

	//Positions

	posMU     *sync.Mutex
	posCh     chan signal
	posCond   *sync.Cond
	posBool   bool
	positions map[string]Position

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
	c.positions = make(map[string]Position)
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

	//TODO rate limited engine.Send() decorator

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
