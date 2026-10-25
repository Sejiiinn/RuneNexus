package save

import "github.com/Sejiiinn/RuneNexus/server/internal/dbgen"

// ValidateClientGenerationFloor rejects a client older than one that already
// claimed this account's writer, because older codecs drop what newer ones
// write. New content only raises CurrentClientCompatibilityVersion; the
// per-feature gates in the *_compatibility.go files are frozen legacy checks
// for saves written before this floor existed and must not grow.
func ValidateClientGenerationFloor(writer dbgen.SaveWriterState, clientVersion int) error {
	if clientVersion < int(writer.ClientGenerationFloor) {
		return ErrClientUpdateRequired
	}
	return nil
}
