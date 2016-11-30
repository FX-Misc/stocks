package motivewave_test

import (
	"os"

	"github.com/apex/log"
	"github.com/apex/log/handlers/text"
	"github.com/joho/godotenv"

	"github.com/santacruz123/stocks/motivewave"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Functions", func() {
	godotenv.Load()
	log.SetHandler(text.New(os.Stdout))
	log.SetLevel(log.DebugLevel)

	path := os.Getenv("PATH_MWML")

	It("Import", func() {
		mw := motivewave.NewMarkup("SPY")
		Expect(mw.ImportMWML(path)).Should(Succeed())
	})

	It("SaveWaves", func() {
		mw := motivewave.NewMarkup("SPY")
		Expect(mw.ImportMWML(path)).Should(Succeed())
		Expect(mw.SaveWaves()).Should(Succeed())
	})

	It("SaveSLTP", func() {
		mw := motivewave.NewMarkup("SPY")
		Expect(mw.ImportMWML(path)).Should(Succeed())
		Expect(mw.SaveSLTP()).Should(Succeed())
	})
})
