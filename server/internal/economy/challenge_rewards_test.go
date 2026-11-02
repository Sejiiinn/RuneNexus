package economy

import "testing"

func TestStageChallengeRewardTable(t *testing.T) {
	for _, tc := range []struct {
		stage    int
		hard     bool
		diamonds int64
		tickets  int64
		granted  bool
	}{
		{1, false, 100, 0, true}, // 1-1
		{2, true, 0, 5, true},    // 1-2
		{16, false, 0, 4, true},  // 1-6
		{6, true, 300, 0, true},  // 2-1
		{5, false, 100, 0, true}, // 1-5 normal keeps diamonds
		{5, true, 0, 0, false},   // 1-5 hard is a core point
		{20, true, 0, 0, false},  // 1-10 hard is a core point
		{20, false, 0, 4, true},  // 1-10 normal keeps tickets
		{12, true, 0, 7, true},   // 3-2
		{30, false, 0, 6, true},  // 3-10
		{99, false, 0, 0, false}, // unknown
	} {
		reward, granted := stageChallengeReward(tc.stage, tc.hard)
		if granted != tc.granted || reward.Diamonds != tc.diamonds || reward.ModuleTickets != tc.tickets {
			t.Fatalf("stage %d hard=%v: %+v %v", tc.stage, tc.hard, reward, granted)
		}
	}
	if key := stageChallengeRewardKey(15, true); key != "stage:15:challenge:hard" {
		t.Fatalf("key %q", key)
	}
}

func TestStageChallengeAchievedNeedsClear(t *testing.T) {
	raw := []byte(`{"clearedStageNumbers":[3,4],"challengeStageNumbers":[3,9],"hardChallengeStageNumbers":[4]}`)
	for _, tc := range []struct {
		stage int
		hard  bool
		want  bool
	}{{3, false, true}, {3, true, false}, {4, false, true}, {4, true, true}, {9, false, false}} {
		if got := stageChallengeAchieved(raw, tc.stage, tc.hard); got != tc.want {
			t.Fatalf("stage %d hard=%v: %v", tc.stage, tc.hard, got)
		}
	}
}
