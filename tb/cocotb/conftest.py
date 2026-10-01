"""
Cocotb test configuration
"""

import os
import pytest


def pytest_configure(config):
    config.addinivalue_line("markers", "smoke: fast subset for CI smoke runs")


def pytest_collection_modifyitems(items):
    """Add smoke marker to smoke tests"""
    for item in items:
        if "smoke" in item.name:
            item.add_marker(pytest.mark.smoke)
