package driver

import (
	"strings"

	"k8s.io/klog/v2"
)

// extractParentDatasetFromDataset extracts the parentDataset name from a dataset path.
// For dataset "pool/parent/volume", returns "pool/parent".
func extractParentDatasetFromDataset(dataset string) string {
	parts := strings.Split(dataset, "/")
	if len(parts) > 1 {
		// Use the same parent dataset structure as the source volume
		// For dataset "pool/parent/volume", use "pool/parent"
		pool := strings.Join(parts[:len(parts)-1], "/")
		klog.V(4).Infof("Inferred parentDataset %q from snapshot dataset %q", pool, dataset)
		return pool
	}
	return ""
}

// extractPoolFromDataset extracts the pool name from a dataset path.
// For dataset "pool/parent/volume", returns "pool".
func extractPoolFromDataset(dataset string) string {
	parts := strings.Split(dataset, "/")
	if len(parts) > 0 {
		return parts[0]
	}
	return ""
}
