package ibtrader

import (
	"os"

	pg "gopkg.in/pg.v5"

	"github.com/apex/log"
	"github.com/apex/log/handlers/text"
	"github.com/joho/godotenv"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Position", func() {

	Context("Position", func() {

		godotenv.Load()

		log.SetHandler(text.New(os.Stdout))
		log.SetLevel(log.DebugLevel)

		It("Should save", func() {

			opt, err := pg.ParseURL(os.Getenv("PG"))
			Expect(err).To(Succeed())
			ib := Client{
				db: pg.Connect(opt),
			}

			ib.db.Exec(`TRUNCATE positions`)

			pos := Position{
				Symbol: "AAPL",
				Qua:    -100,
				Price:  112,
			}

			ib.savePosition(pos)
		})
	})
})
