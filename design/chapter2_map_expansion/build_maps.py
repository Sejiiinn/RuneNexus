#!/usr/bin/env python3
"""Export approved source coordinates; never overwrite authoring sources."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from content_design_views import main

if __name__ == "__main__":
    main(2)
