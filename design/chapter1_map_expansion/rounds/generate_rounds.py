#!/usr/bin/env python3
"""Export a chapter source view; --check validates without writing snapshots."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from content_design_views import main

if __name__ == "__main__":
    main(1)
