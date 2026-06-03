@ECHO OFF

pushd %~dp0

REM Command file for Sphinx documentation

if "%1" == "" goto help
if "%1" == "help" goto help
if "%1" == "html" goto html
if "%1" == "clean" goto clean
if "%1" == "serve" goto serve

goto help

:help
echo.
echo   Usage:
echo     make html    - Build the HTML documentation
echo     make clean   - Remove the build directory
echo     make serve   - Build and serve locally (opens browser)
echo.
goto end

:html
sphinx-build -b html docs docs/_build/html
if errorlevel 1 goto end
echo.
echo Build finished. Open docs\_build\html\index.html in your browser.
goto end

:clean
rmdir /s /q docs\_build 2>nul
echo Build directory cleaned.
goto end

:serve
sphinx-build -b html docs docs/_build/html
if errorlevel 1 goto end
echo.
echo Build finished. Opening in browser...
start "" "docs\_build\html\index.html"
goto end

:end
popd
