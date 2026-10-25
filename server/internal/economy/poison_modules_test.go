package economy

import (
	"slices"
	"testing"
)

func TestPoisonModuleUnlockIsNewContent(t *testing.T) {
	for _, tc := range []struct {
		name, progression string
		allowed           bool
	}{
		{"locked before 2-8", `{"progressionVersion":1,"clearedStageNumbers":[22]}`, false},
		{"opens on 2-8", `{"progressionVersion":1,"clearedStageNumbers":[23]}`, true},
		{"grandfathered right is ignored", `{"progressionVersion":1,"grandfatherUnlocks":["turret:poison"]}`, false},
		{"legacy clears are ignored", `{"clearedStageNumbers":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]}`, false},
		{"legacy save with the real clear", `{"clearedStageNumbers":[23]}`, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := turretUnlocked("poison", []byte(tc.progression)); got != tc.allowed {
				t.Fatalf("allowed=%v want %v", got, tc.allowed)
			}
		})
	}
}

func TestPoisonModuleCatalog(t *testing.T) {
	core := optionPool("poison", "core")
	if !slices.Equal(core, []string{"damageIncrease", "splashRadiusIncrease", "damageOverTimeIncrease", "poisonDurationIncrease"}) {
		t.Fatalf("poison core pool: %v", core)
	}
	if !slices.Equal(optionPool("poison", "barrel"), optionPool("arrow", "barrel")) || !slices.Equal(optionPool("poison", "frame"), optionPool("arrow", "frame")) {
		t.Fatal("poison barrel and frame must share the common pools")
	}
	if familyFor("poison", "core") != "venomCore" || familyFor("poison", "barrel") != "mortarBarrel" || familyFor("poison", "frame") != "sealedFrame" {
		t.Fatal("poison module families changed")
	}
	if moduleRange("poisonDurationIncrease", "core", "unique") != moduleRange("burnDurationIncrease", "core", "unique") {
		t.Fatal("poison duration shares the burn duration ranges")
	}
	valid := generatedModule{TurretType: "poison", Part: "core", Family: "venomCore", Grade: "rare", Options: []moduleOption{{Type: "poisonDurationIncrease", Value: 20}}}
	if err := validateModule(valid); err != nil {
		t.Fatal(err)
	}
	// Burn duration belongs to the flame turret and never rolls on poison.
	burn := valid
	burn.Options = []moduleOption{{Type: "burnDurationIncrease", Value: 20}}
	if validateModule(burn) == nil {
		t.Fatal("poison core accepted burn duration")
	}
	for draw := int64(0); draw < 200; draw++ {
		module, err := generateModule("poison", draw)
		if err != nil || validateModule(module) != nil || module.TurretType != "poison" {
			t.Fatalf("generated poison module invalid: %+v %v", module, err)
		}
	}
}
