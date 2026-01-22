// Package nvmeof contains NVMe-oF-specific E2E tests for the TrueNAS CSI driver.
package nvmeof

import (
	. "github.com/onsi/ginkgo/v2"
)

var _ = Describe("Name Templating", func() {
	// NVMe-oF has issues with name templating and port binding
	// TODO: Re-enable once NVMe-oF subsystem port binding is fixed

	It("should create volumes with templated names from StorageClass parameters", func() {
		Skip("NVMe-oF name templating skipped - has issues with subsystem port binding")
	})

	It("should create volumes with prefix and suffix from StorageClass parameters", func() {
		Skip("NVMe-oF name templating skipped - has issues with subsystem port binding")
	})
})
