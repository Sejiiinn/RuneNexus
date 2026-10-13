package coretree

import "testing"

func TestExpandedCatalogShape(t *testing.T) {
	catalog := Catalogs[CurrentRevision]
	if CurrentRevision != 5 || len(catalog.Nodes) != 60 || len(catalog.StartingNodes) != 6 {
		t.Fatalf("unexpected catalog: revision=%d nodes=%d starts=%d", CurrentRevision, len(catalog.Nodes), len(catalog.StartingNodes))
	}
	edges := 0
	for id, node := range catalog.Nodes {
		if len(node.RankCosts) != node.MaxRank { t.Fatalf("rank costs: %s", id) }
		for _, neighbor := range node.Neighbors {
			reverse := false
			for _, candidate := range catalog.Nodes[neighbor].Neighbors { if candidate == id { reverse = true } }
			if !reverse { t.Fatalf("asymmetric edge: %s -> %s", id, neighbor) }
			edges++
		}
	}
	// CORE is display-only: the six CORE-to-start edges are implicit.
	if edges / 2 + len(catalog.StartingNodes) != 89 { t.Fatalf("edges including CORE = %d", edges / 2 + len(catalog.StartingNodes)) }
	if len(Catalogs[4].Nodes) != 21 { t.Fatal("legacy catalog was replaced") }
}

func TestAllocationUsesIncrementalCostsAndActualBudget(t *testing.T) {
	for _, tc := range []struct { name string; revision int; ranks map[string]int; points int; valid bool }{
		{"empty", 5, nil, 0, true},
		{"exact incremental", 5, map[string]int{"S1":5}, 9, true},
		{"final cost is not total", 5, map[string]int{"S1":5}, 3, false},
		{"rank two cannot relay", 5, map[string]int{"S1":2,"A03":1}, 60, false},
		{"one neighbor suffices", 5, map[string]int{"S1":3,"A03":1}, 5, true},
		{"alternate neighbor suffices", 5, map[string]int{"S6":3,"A02":1}, 5, true},
		{"disconnected cycle", 5, map[string]int{"A01":3,"A02":3}, 60, false},
		{"invalid node", 5, map[string]int{"CORE":1}, 60, false},
		{"invalid rank", 5, map[string]int{"S1":6}, 60, false},
		{"negative rank", 5, map[string]int{"S1":-1}, 60, false},
		{"unknown revision", 6, nil, 0, false},
		{"legacy", 4, map[string]int{"attackHaste":3,"attackPrecompute":1}, 5, true},
		{"legacy id in expanded", 5, map[string]int{"attackHaste":1}, 60, false},
	} {
		t.Run(tc.name, func(t *testing.T) { if err := ValidateAllocation(tc.revision, tc.ranks, tc.points); (err == nil) != tc.valid { t.Fatalf("valid=%v err=%v", tc.valid, err) } })
	}
	all := make(map[string]int)
	for id, node := range Catalogs[5].Nodes { all[id] = node.MaxRank }
	spent, err := SpentPoints(5, all)
	if err != nil || spent <= 60 { t.Fatalf("expanded budget=%d err=%v", spent, err) }
	if err := ValidateAllocation(5, all, spent); err != nil { t.Fatal(err) }
	if err := ValidateAllocation(5, all, spent-1); err == nil { t.Fatal("overspend accepted") }
}

func TestTerminalNodeNeverPropagates(t *testing.T) {
	// A synthetic catalog isolates the terminal rule independently of rank-one
	// keystones, which also cannot reach the normal relay threshold.
	Catalogs[99] = Catalog{StartingNodes: []string{"start"}, Nodes: map[string]Node{
		"start": {MaxRank:3, RankCosts:[]int{1,1,1}, Neighbors:[]string{"end"}},
		"end": {MaxRank:3, RankCosts:[]int{1,1,1}, Neighbors:[]string{"start","beyond"}, Terminal:true},
		"beyond": {MaxRank:1, RankCosts:[]int{1}, Neighbors:[]string{"end"}},
	}}
	t.Cleanup(func() { delete(Catalogs, 99) })
	if err := ValidateAllocation(99, map[string]int{"start":3,"end":3}, 6); err != nil { t.Fatal(err) }
	if err := ValidateAllocation(99, map[string]int{"start":3,"end":3,"beyond":1}, 7); err == nil { t.Fatal("terminal propagated") }
}
