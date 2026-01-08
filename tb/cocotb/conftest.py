"""
Cocotb test configuration
"""

import os
import pytest


def pytest_collection_modifyitems(items):
    """Add smoke marker to smoke tests"""
    for item in items:
        if "smoke" in item.name:
            item.add_marker(pytest.mark.smoke)
