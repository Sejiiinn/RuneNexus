package auth

import (
	"errors"
	"strings"
	"testing"
)

func TestValidateNickname(t *testing.T) {
	for _, tc := range []struct {
		input, want string
		valid       bool
	}{
		{"  룬마스터\n", "룬마스터", true},
		{"가나다라마바사아", "가나다라마바사아", true},
		{"abcdefghijklmnop", "abcdefghijklmnop", true},
		{"가나다라12345678", "가나다라12345678", true},
		{"AB_09", "AB_09", true},
		{"가", "", false}, {"a", "", false}, {"", "", false},
		{"가나다라마바사아자", "", false}, {strings.Repeat("a", 17), "", false},
		{"가나다라123456789", "", false}, {"룬 기사", "", false},
		{"룬#1234", "", false}, {"ㄱㄴ", "", false}, {"가", "", false},
		{"éa", "", false}, {"😀a", "", false}, {"가\u200b나", "", false},
	} {
		t.Run(tc.input, func(t *testing.T) {
			got, err := ValidateNickname(tc.input)
			if tc.valid {
				if err != nil || got != tc.want {
					t.Fatalf("ValidateNickname = %q, %v", got, err)
				}
			} else if !errors.Is(err, ErrInvalidNickname) {
				t.Fatalf("error = %v", err)
			}
		})
	}
}
