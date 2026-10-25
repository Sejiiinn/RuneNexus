// Package contentregistry exposes content identities generated from the client
// content sources, so the server never maintains its own copy of them.
package contentregistry

import "slices"

// Range is an inclusive integer roll range.
type Range struct {
	Min int
	Max int
}

// GemTypes returns the gem identities in authoring order.
func GemTypes() []string { return slices.Clone(gemTypes[:]) }

func ValidGem(gem string) bool { return slices.Contains(gemTypes[:], gem) }

// TurretTypes returns the turret identities in authoring order.
func TurretTypes() []string { return slices.Clone(turretTypes[:]) }

func ValidTurret(turret string) bool { return slices.Contains(turretTypes[:], turret) }

func ModuleParts() []string { return slices.Clone(moduleParts[:]) }

func ValidModulePart(part string) bool { return slices.Contains(moduleParts[:], part) }

// ModuleGrades returns grades from lowest to highest.
func ModuleGrades() []string { return slices.Clone(moduleGrades[:]) }

func ValidModuleGrade(grade string) bool { return slices.Contains(moduleGrades[:], grade) }

// ModuleFamily returns "" for an unknown turret or part.
func ModuleFamily(turret, part string) string { return moduleFamilies[turret][part] }

// ModulePool returns the option types a part of the turret can roll.
func ModulePool(turret, part string) []string { return slices.Clone(modulePools[turret][part]) }

// ModuleRange applies a part-specific range before the shared option range.
func ModuleRange(option, part, grade string) (Range, bool) {
	if limits, ok := modulePartRanges[part][option][grade]; ok {
		return limits, true
	}
	limits, ok := moduleRanges[option][grade]
	return limits, ok
}
