# escape=`

FROM python:3.9-windowsservercore-ltsc2022 AS runtime

SHELL ["powershell.exe", "-NoLogo", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ENV PYTHONDONTWRITEBYTECODE=1 `
    PYTHONUNBUFFERED=1 `
    PYTHONIOENCODING=utf-8 `
    PYTHONUTF8=1 `
    TERM=dumb `
    NO_COLOR=1 `
    CLICOLOR=0 `
    FORCE_COLOR=0 `
    PLCREX_VENDOR_PATH=C:\app\vendor\PLCreX

ENV PLCREX_HELP_COMMAND="C:\app\.venv-plcrex\Scripts\python.exe -m plcrex --help"

WORKDIR C:\app

COPY backend\requirements.txt C:\app\backend\requirements.txt
RUN python -m pip install --upgrade pip setuptools wheel; `
    python -m pip install --no-cache-dir -r C:\app\backend\requirements.txt

COPY .venv-plcrex\Lib\site-packages C:\app\plcrex-site-packages
COPY vendor C:\app\vendor

RUN if (-not (Test-Path C:\app\vendor\PLCreX\requirements.txt)) { throw 'vendor\PLCreX is missing. Run just pull-plcrex before building the image.' }; `
    python -m venv C:\app\.venv-plcrex; `
    C:\app\.venv-plcrex\Scripts\python.exe -m pip install --upgrade pip wheel; `
    C:\app\.venv-plcrex\Scripts\python.exe -m pip install --upgrade 'setuptools>=65,<80'; `
    if (-not (Test-Path C:\app\plcrex-site-packages\pyeda\boolalg\espresso.cp39-win_amd64.pyd)) { throw '.venv-plcrex is missing compiled pyeda binaries. Run just pull-plcrex on the host before building the image.' }; `
    Copy-Item C:\app\plcrex-site-packages\* C:\app\.venv-plcrex\Lib\site-packages\ -Recurse -Force; `
    Remove-Item -Recurse -Force C:\app\.venv-plcrex\Lib\site-packages\__editable__.plcrex-2.0.0.pth -ErrorAction SilentlyContinue; `
    Remove-Item -Recurse -Force C:\app\.venv-plcrex\Lib\site-packages\__editable___plcrex_2_0_0_finder.py -ErrorAction SilentlyContinue; `
    C:\app\.venv-plcrex\Scripts\python.exe -m pip install --no-build-isolation --no-deps C:\app\vendor\PLCreX; `
    Remove-Item -Recurse -Force C:\app\plcrex-site-packages

COPY backend C:\app\backend
COPY frontend\dist C:\app\frontend\dist

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "backend.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
