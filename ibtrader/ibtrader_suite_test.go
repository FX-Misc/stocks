package ibtrader

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestIbtrader(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Ibtrader Suite")
}
