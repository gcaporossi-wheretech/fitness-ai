"""E2E test fixtures: shared auth helpers for cross-service tests.

These tests run against individual service test databases (SQLite)
to verify the API contracts without requiring Docker Compose.
"""

from __future__ import annotations

import asyncio

import pytest


@pytest.fixture(scope="session")
def event_loop():
    """Create an event loop for the test session."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()
