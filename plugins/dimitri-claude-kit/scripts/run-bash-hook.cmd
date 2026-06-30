@echo off
setlocal
rem run-bash-hook.cmd <script-basename.sh>
rem Resolve the REAL Git Bash by absolute-path probe so hook execution never depends on PATH
rem order (a WSL bash.exe stub in System32 can shadow Git Bash). Shipped INSIDE the plugin, so
rem 'claude plugin update' re-ships it intact -- there is no in-place patch to be wiped.
set "GB="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "GB=%ProgramFiles%\Git\bin\bash.exe"
if not defined GB if exist "%ProgramFiles%\Git\usr\bin\bash.exe" set "GB=%ProgramFiles%\Git\usr\bin\bash.exe"
if not defined GB if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "GB=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined GB if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "GB=%LocalAppData%\Programs\Git\bin\bash.exe"
if not defined GB (
  echo run-bash-hook: Git Bash not found; install Git for Windows. 1>&2
  exit /b 1
)
"%GB%" "%~dp0%~1"
exit /b %ERRORLEVEL%
