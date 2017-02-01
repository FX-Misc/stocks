package ibtrader

import (
	"github.com/apex/log"
	"github.com/gofinance/ib"
)

//Position struct
type Position struct {
	Symbol string
	Qua    float64
	Price  float64
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
		c.db.Exec(`TRUNCATE positions`)
		c.engine.Send(&ib.RequestPositions{})
		<-c.posCh
		log.Debugf("Positions updated - %#v", c.positions)

		c.posCond.L.Lock()
		c.posBool = false
		c.posCond.Broadcast()
	}
}

func (c *Client) savePosition(pos Position) {
	q := `INSERT INTO positions(symbol,qua,price)
	SELECT id, ?, ? FROM symbols WHERE title = ?`

	_, err := c.db.ExecOne(q, pos.Qua, pos.Price, pos.Symbol)

	if err != nil {
		log.Fatal(err.Error())
	}

	return
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
func (c *Client) Position(symbol string) (qua, price float64) {
	c.posMU.Lock()
	defer c.posMU.Unlock()
	if pos, ok := c.positions[symbol]; ok {
		qua, price = pos.Qua, pos.Price
	}
	return
}
