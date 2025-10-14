# Configuration file for the Sphinx documentation builder.

# -- Project information -----------------------------------------------------
project = 'xeus-ocaml'
copyright = '2025, Davy Cottet'
author = 'Davy Cottet'

# -- General configuration ---------------------------------------------------
extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.intersphinx',
    'breathe', # For Doxygen integration
]

templates_path = ['_templates']

exclude_patterns = []

# -- Options for HTML output -------------------------------------------------
html_theme = 'furo'
html_static_path = ["_static"]
html_css_files = ["pied-piper-admonition.css"]

# -- Furo Theme Options (Optional, but recommended) ---------------------------
# For more options, see: https://pradyunsg.me/furo/customisation/
html_theme_options = {
    "light_css_variables": {
        "color-brand-primary": "#EC670F",
        "color-brand-content": "#EC670F",
    },
    "dark_css_variables": {
        "color-brand-primary": "#F29100",
        "color-brand-content": "#F29100",
    },
    # You can add a logo here if you have one
    # "light_logo": "logo-light.png",
    # "dark_logo": "logo-dark.png",
}

# -- Breathe Configuration (for Doxygen) -------------------------------------
breathe_projects = {
    "xeus-ocaml-cpp": "../build/doxygen/xml/"
}
breathe_default_project = "xeus-ocaml-cpp"

# -- Intersphinx mapping -----------------------------------------------------
intersphinx_mapping = {
    'python': ('https://docs.python.org/3', None),
}