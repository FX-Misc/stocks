package ibtrader

import (
	"os"

	"github.com/apex/log"
	"github.com/apex/log/handlers/text"
	"github.com/joho/godotenv"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Helpers", func() {

	Context("Helpers", func() {

		godotenv.Load()

		log.SetHandler(text.New(os.Stdout))
		log.SetLevel(log.DebugLevel)

		It("Should request price", func() {
			ib, err := NewClient()
			Expect(err).To(Succeed())
			defer ib.Stop()
			ib.RefreshQuote("AAPL")
		})

		It("Should request prices for all symbols", func() {
			ib, err := NewClient()
			Expect(err).To(Succeed())
			defer ib.Stop()
			ib.RefreshQuotes()
		})
	})
})
