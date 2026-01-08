"""
Unit test configuration
"""

import pytest


def pytest_configure(config):
    """Configure pytest"""
    config.addinivalue_line("markers", "smoke: mark test as a smoke test")
