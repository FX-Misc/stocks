package main

import (
	"database/sql"
	"math"
	"os"
	"strconv"
	"time"

	"github.com/apex/log"
	"github.com/apex/log/handlers/text"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq"

	"github.com/gofinance/ib"
)

var (
	engine      *ib.Engine
	orderID     int64
	engineReady = make(chan bool)
	positionEnd = make(chan bool)
	ibPositions = make(map[ib.PositionKey]*ib.Position)
	riskAmount  uint64
	gateway     string
)

//NextID getting ID
func NextID() int64 {
	orderID++
	return orderID
}

//NewContract const
func NewContract(symbol string) ib.Contract {
	return ib.Contract{
		Symbol:       symbol,
		SecurityType: "STK", //STK CFD
		Exchange:     "SMART",
		Currency:     "USD",
	}
}

//NewOrder const
func NewOrder(gtc bool) (ib.Order, error) {
	order, err := ib.NewOrder()

	order.TIF = "DAY"
	if gtc {
		order.TIF = "GTC"
	}

	return order, err
}

func order(symbol string, qua int64, price float64, gtc bool) {

	request := ib.PlaceOrder{
		Contract: NewContract(symbol),
	}

	request.Order, _ = NewOrder(gtc)

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

	request.SetID(NextID())

	engine.Send(&request)
	log.Infof("%s %d %s @ %s", request.Order.Action, request.Order.TotalQty, symbol, priceLog)
}

func getCurrentPositions() {
	ibPositions = make(map[ib.PositionKey]*ib.Position)
	engine.Send(&ib.RequestPositions{})
	<-positionEnd
}

func engineLoop(ibmanager *ib.Engine) {
	engs := make(chan ib.EngineState)
	rc := make(chan ib.Reply)

	engine.SubscribeState(engs)
	engine.SubscribeAll(rc)

	engine.Send(&ib.RequestIDs{})

	for {
		select {
		case r := <-rc:
			//log.Printf("%s - RECEIVE %v",  reflect.TypeOf(r))
			switch r.(type) {

			case (*ib.ErrorMessage):
				r := r.(*ib.ErrorMessage)
				log.Errorf("ID: %v Code:%3d Message:'%v'\n", r.ID(), r.Code, r.Message)

			case (*ib.NextValidID):
				r := r.(*ib.NextValidID)
				orderID = r.OrderID
				log.Debugf("OrderId=%v", orderID)
				engineReady <- true

			case (*ib.Position):
				pos := r.(*ib.Position)
				log.Debugf("Position=%+v", pos)
				ibPositions[pos.Key] = pos

			case (*ib.PositionEnd):
				positionEnd <- true

			default:
				log.Debugf("%#v\n", r)
			}

		case newstate := <-engs:
			log.Errorf("ERROR: %v\n", newstate)
			if newstate != ib.EngineExitNormal {
				log.Fatalf("ERROR: %v", engine.FatalError())
			}
			return
		}
	}
}

type position struct {
	Symbol string
	Qua    int64
}

func getNextPositions(riskAmount uint64) (positions []position, err error) {

	db, err := sql.Open("postgres", "")
	if err != nil {
		return
	}

	defer db.Close()

	query := `SELECT
      s.title symbol,
			x.qua
    FROM
      f_pos_next($1::INT) as x
      LEFT JOIN symbols  as s ON x.symbol = s.id`

	rows, err := db.Query(query, riskAmount)

	if err != nil {
		log.Fatal(err.Error())
	}

	defer rows.Close()

	for rows.Next() {

		positions = append(positions)

		var symbol string
		var qua int64

		if err := rows.Scan(&symbol, &qua); err != nil {
			log.Fatal(err.Error())
		}

		positions = append(positions, position{symbol, qua})
	}

	if err := rows.Err(); err != nil {
		log.Fatal(err.Error())
	}

	return
}

func getIBPositionAmountBySymbol(symbol string) float64 {
	for k := range ibPositions {
		if ibPositions[k].Contract.Symbol == symbol && ibPositions[k].Contract.SecurityType == "STK" {
			return ibPositions[k].Position
		}
	}
	return 0
}

func main() {
	godotenv.Load()

	gateway = os.Getenv("IBGATEWAY")

	if s, err := strconv.Atoi(os.Getenv("RISK_AMT")); err == nil {
		riskAmount = uint64(s)
	}

	log.SetHandler(text.New(os.Stdout))
	log.SetLevel(log.InfoLevel)

	var err error
	engine, err = ib.NewEngine(ib.EngineOptions{Gateway: gateway})

	go func() {
		time.Sleep(time.Second)
		go engineLoop(engine)
	}()

	if err != nil {
		log.Fatalf("error creating engine %v ", err)
	}

	defer engine.Stop()

	if engine.State() != ib.EngineReady {
		log.Fatalf("Engine is not ready")
	}

	<-engineReady

	getCurrentPositions()

	log.Infof("Risk amount = %v", riskAmount)

	nextPositions, err := getNextPositions(riskAmount)

	for _, pos := range nextPositions {
		currQua := getIBPositionAmountBySymbol(pos.Symbol)
		if orderQua := pos.Qua - int64(currQua); orderQua != 0 {
			order(pos.Symbol, orderQua, 0, true)
		}
	}

	time.Sleep(time.Second * 2)
}
