# QSET Documentation Hub

The central documentation hub for Queen's Space Engineering Team, built with [Sphinx](https://www.sphinx-doc.org/) and the [Read the Docs theme](https://sphinx-rtd-theme.readthedocs.io/).

## 🚀 Live Site

Deployed automatically via GitHub Actions to GitHub Pages on every push to `main`.

## 🛠️ Local Development

### Prerequisites

- Python 3.10+
- pip

### Setup

```bash
# Install dependencies
pip install -r requirements.txt

# Build the docs
sphinx-build -b html docs docs/_build/html

# Or use the convenience script (Windows)
make html
```

### Preview Locally

After building, open `docs/_build/html/index.html` in your browser:

```bash
# Windows — builds and opens in browser
make serve
```

Or just double-click `docs/_build/html/index.html` after running the build.

### Clean Build

```bash
make clean
make html
```

## 📦 Deployment

This project deploys automatically to **GitHub Pages** via GitHub Actions:

1. Push changes to the `main` branch
2. The workflow builds the Sphinx docs
3. The built HTML is deployed to GitHub Pages

### First-Time GitHub Pages Setup

1. Go to your repo's **Settings → Pages**
2. Under **Source**, select **GitHub Actions**
3. Push to `main` — the workflow will handle the rest

## 📁 Project Structure

```
QSET_Doc/
├── .github/workflows/deploy.yml   # GitHub Actions deployment
├── docs/
│   ├── _static/custom.css          # Custom theme styling
│   ├── _build/html/                # Built output (gitignored)
│   ├── subteams/                   # Subteam documentation
│   │   ├── adcs/
│   │   ├── obc/
│   │   ├── ground/
│   │   ├── comms/
│   │   ├── eps/
│   │   ├── mech/
│   │   ├── spaceschool/
│   │   └── payload/
│   ├── conf.py                     # Sphinx configuration
│   └── index.rst                   # Landing page
├── requirements.txt
├── make.bat                        # Windows build helper
└── .gitignore
```
