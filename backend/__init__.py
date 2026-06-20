"""CloakBrowser Manager backend package.

Loads environment variables from a project-root ``.env`` file at import time,
before submodules (``database.py``, ``main.py``) read ``os.environ``.
Falls back silently if python-dotenv is not installed (e.g. in Docker, where
env vars come from the container environment).
"""

from __future__ import annotations

try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:  # pragma: no cover
    pass
