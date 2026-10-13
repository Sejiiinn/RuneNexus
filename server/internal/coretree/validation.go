package coretree

import "fmt"

// SpentPoints uses incremental rank costs, not the price of the final rank.
// Revisions before four use the preserved legacy catalog.
func SpentPoints(revision int, ranks map[string]int) (int, error) {
	catalog, ok := Catalogs[catalogRevision(revision)]
	if !ok {
		return 0, fmt.Errorf("unsupported core tree revision %d", revision)
	}
	spent := 0
	for id, rank := range ranks {
		node, ok := catalog.Nodes[id]
		if !ok || rank < 0 || rank > node.MaxRank || rank > len(node.RankCosts) {
			return 0, fmt.Errorf("invalid core tree rank %s:%d", id, rank)
		}
		for _, cost := range node.RankCosts[:rank] {
			spent += cost
		}
	}
	return spent, nil
}

// ValidateAllocation traverses outward from all six starts. An invested node
// is legal when at least one reachable, nonterminal neighbor has rank >= 3.
// Unreachable cycles cannot unlock each other, and keystones never relay access.
func ValidateAllocation(revision int, ranks map[string]int, totalPoints int) error {
	spent, err := SpentPoints(revision, ranks)
	if err != nil {
		return err
	}
	if totalPoints < 0 || spent > totalPoints {
		return fmt.Errorf("core tree spends %d of %d points", spent, totalPoints)
	}
	catalog := Catalogs[catalogRevision(revision)]
	reachable := make(map[string]bool, len(catalog.Nodes))
	queue := append([]string(nil), catalog.StartingNodes...)
	for _, id := range queue {
		reachable[id] = true
	}
	for i := 0; i < len(queue); i++ {
		id := queue[i]
		node := catalog.Nodes[id]
		if node.Terminal || ranks[id] < 3 {
			continue
		}
		for _, neighbor := range node.Neighbors {
			if !reachable[neighbor] {
				reachable[neighbor] = true
				queue = append(queue, neighbor)
			}
		}
	}
	for id, rank := range ranks {
		if rank > 0 && !reachable[id] {
			return fmt.Errorf("unreachable core tree node %s", id)
		}
	}
	return nil
}

func catalogRevision(revision int) int {
	if revision >= 0 && revision <= 4 {
		return 4
	}
	return revision
}
