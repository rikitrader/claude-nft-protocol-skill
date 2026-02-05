"""Entry point: python3 -m engine"""
import sys
from pathlib import Path

# Ensure the skill directory is on sys.path so 'engine' package resolves
skill_dir = Path(__file__).resolve().parent.parent
if str(skill_dir) not in sys.path:
    sys.path.insert(0, str(skill_dir))

from engine.cli import main

if __name__ == "__main__":
    main()
