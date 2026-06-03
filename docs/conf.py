# Configuration file for the Sphinx documentation builder.

project = 'QSET Documentation Hub'
copyright = '2026, QSET'
author = 'QSET'

# -- General configuration ---------------------------------------------------
extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.viewcode',
    'sphinx.ext.napoleon',
    'sphinxcontrib.mermaid',
    'sphinx_design',
    'sphinx_copybutton',
    'sphinx_needs',
]

# -- Sphinx-Needs Configuration ----------------------------------------------
needs_types = [
    dict(directive="req", title="Requirement", prefix="REQ_", color="#BFD8D2", style="node"),
    dict(directive="spec", title="Specification", prefix="SPEC_", color="#FEDCD2", style="node"),
    dict(directive="test", title="Test Case", prefix="TEST_", color="#DF744A", style="node"),
]

needs_links = {
    "satisfies": {
        "incoming": "is satisfied by",
        "outgoing": "satisfies",
    },
    "verifies": {
        "incoming": "is verified by",
        "outgoing": "verifies",
    },
}

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

# -- Options for HTML output -------------------------------------------------
html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']

html_css_files = [
    'custom.css',
]
