@echo off
title Instalador Inteligente - Sincronizacao Lobinho
setlocal enabledelayedexpansion

:: 1. PEDE ADMIN
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    goto UACPrompt
) else ( goto gotAdmin )
:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B
:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%~dp0"

cls
echo ======================================================
echo    BUSCANDO O MELHOR SERVIDOR PARA SUA REDE...
echo ======================================================
echo.

:: 2. LISTA DE SERVIDORES (HTTPS)
set "servers=google.com cloudflare.com microsoft.com apple.com amazon.com facebook.com github.com wikipedia.org netflix.com uol.com.br"
set "winner="

for %%s in (%servers%) do (
    if not defined winner (
        echo [ TESTANDO ] https://%%s ...
        for /f "tokens=*" %%t in ('powershell -command "$sw = [diagnostics.stopwatch]::StartNew(); try { $res = Invoke-WebRequest -Uri 'https://%%s' -Method Head -UseBasicParsing -TimeoutSec 15; $sw.Stop(); if($sw.Elapsed.TotalSeconds -lt 15) { echo $sw.Elapsed.TotalSeconds } else { echo 'FAIL' } } catch { echo 'FAIL' }"') do (
            set "runtime=%%t"
        )
        if not "!runtime!"=="FAIL" (
            echo [+] Respondendo em !runtime! segundos.
            set "winner=%%s"
            goto :FoundWinner
        ) else (
            echo [!] Tempo excedido ou erro em %%s.
        )
    )
)

:FoundWinner
if not defined winner (
    echo.
    powershell -Command "Write-Host 'ERRO: Nenhum servidor respondeu em menos de 15s.' -ForegroundColor Red"
    pause
    exit
)

echo.
powershell -Command "Write-Host 'VENCEDOR: https://%winner% selecionado!' -ForegroundColor Green"

:: 3. CRIACAO DA PASTA
if not exist "C:\sincronizardata" md "C:\sincronizardata"

:: 4. CRIACAO DO PS1
(
echo $url = "https://%winner%"
echo try {
echo     $sw = [diagnostics.stopwatch]::StartNew(^)
echo     $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 20
echo     $sw.Stop(^)
echo     $httpDate = $response.Headers.Date
echo     $date = [DateTime]::ParseExact($httpDate, "ddd, dd MMM yyyy HH:mm:ss 'GMT'", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal^)
echo     Set-Date -Date $date
echo     exit [int]$sw.Elapsed.TotalSeconds
echo } catch {
echo     exit 99
echo }
) > "C:\sincronizardata\sincronizar.ps1"

:: 5. CRIACAO DO SINCRONIZAR.BAT
(
echo @echo off
echo powershell -ExecutionPolicy Bypass -File "C:\sincronizardata\sincronizar.ps1"
echo exit
) > "C:\sincronizardata\sincronizar.bat"

:: 6. CRIACAO DO VERIFICADOR.BAT (LINHA POR LINHA PARA EVITAR CRASH)
set "v=C:\sincronizardata\verificador.bat"
echo @echo off > "%v%"
echo title Verificador de Sincronizacao - Lobinho >> "%v%"
echo cls >> "%v%"
echo echo [ CHECK-UP DO SISTEMA ] >> "%v%"
echo echo. >> "%v%"
echo echo 1. Pasta C:\sincronizardata... >> "%v%"
echo if exist "C:\sincronizardata" (echo [ OK ]) else (echo [ ERRO ]) >> "%v%"
echo echo 2. Arquivos de Script... >> "%v%"
echo if exist "C:\sincronizardata\sincronizar.ps1" (echo [ OK ]) else (echo [ ERRO ]) >> "%v%"
echo echo 3. Tarefa Agendada... >> "%v%"
echo schtasks /query /tn "SincronizarHorarioLobinho" ^>nul 2^>^&1 >> "%v%"
echo if %%errorlevel%% equ 0 (echo [ OK ]) else (echo [ ERRO ]) >> "%v%"
echo echo. >> "%v%"
echo echo [ TESTE DE VELOCIDADE ATUAL ] >> "%v%"
echo echo Sincronizando agora... >> "%v%"
echo powershell -ExecutionPolicy Bypass -File "C:\sincronizardata\sincronizar.ps1" >> "%v%"
echo set "result=%%errorlevel%%" >> "%v%"
echo if %%result%% lss 15 ( >> "%v%"
echo     powershell -Command "Write-Host 'STATUS: OK (Tempo: %%result%%s)' -ForegroundColor Green" >> "%v%"
echo ) else if %%result%% leq 20 ( >> "%v%"
echo     powershell -Command "Write-Host 'STATUS: DEMORADO (Tempo: %%result%%s)' -ForegroundColor Yellow" >> "%v%"
echo ) else ( >> "%v%"
echo     powershell -Command "Write-Host 'STATUS: SERVIDOR ERRADO/TIMEOUT (Erro ou >20s)' -ForegroundColor Red" >> "%v%"
echo ) >> "%v%"
echo echo. >> "%v%"
echo pause >> "%v%"

:: 7. CRIA TAREFA NO AGENDADOR
schtasks /delete /tn "SincronizarHorarioLobinho" /f >nul 2>&1
schtasks /create /tn "SincronizarHorarioLobinho" /tr "C:\sincronizardata\sincronizar.bat" /sc onlogon /rl highest /f

echo.
echo Tudo pronto! Verifique a pasta C:\sincronizardata
pause