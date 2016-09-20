package motivewave_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestMotivewave(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Motivewave Suite")
}
