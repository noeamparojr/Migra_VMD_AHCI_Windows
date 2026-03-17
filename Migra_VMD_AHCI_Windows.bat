@echo off
setlocal EnableDelayedExpansion
title Assistente de Migracao VMD/RST e AHCI
color 0F
cd /d "%~dp0"

:: ==========================================
:: CONFIGURACOES E VARIAVEIS GERAIS
:: ==========================================
:: Forca UTF-8 para o prompt, evitando crash com acentos (ç, ã)
chcp 65001 >nul

:: Log datado (um arquivo por dia)
set "D_LOG=%DATE:/=-%"
set "D_LOG=!D_LOG: =_!"
set "LOG_FILE=VMD_Log_!D_LOG!.txt"

set "STATE_FILE=VMD_State.ini"
set "TEMP_BL=%TEMP%\vmd_bl_status.txt"
set "TEMP_CMD=%TEMP%\vmd_cmd_out.txt"
set "TEMP_VBS=%TEMP%\vmd_elevate.vbs"

:: Cria/inicia o log se nao existir
if not exist "%LOG_FILE%" echo === LOG DE MIGRACAO VMD === > "%LOG_FILE%"

:: ==========================================
:: 1. VERIFICACAO E AUTOELEVACAO PARA ADMIN
:: ==========================================
:: Troca do 'net session' para 'fltmc' (mais confiavel no Win 11)
fltmc >nul 2>&1
if %errorlevel% neq 0 (
    echo [%DATE% %TIME%] Solicitando privilegios de Administrador via VBScript... >> "%LOG_FILE%"
    echo Set UAC = CreateObject^("Shell.Application"^) > "%TEMP_VBS%"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%TEMP_VBS%"
    "%TEMP_VBS%"
    del "%TEMP_VBS%" >nul 2>&1
    exit /b
)

:: ==========================================
:: 2. LEITURA DE ESTADO PERSISTENTE
:: ==========================================
set "CURRENT_STEP=1"
set "BIOS_DONE=0"
set "LAST_ACTION=Nenhuma"
set "TARGET_MODE=Nenhum"

if exist "%STATE_FILE%" (
    for /f "tokens=1,2 delims==" %%A in (%STATE_FILE%) do (
        set "%%A=%%B"
    )
)

:: ==========================================
:: 3. DETECCAO DE AMBIENTE (WINDOWS DRIVE)
:: ==========================================
set "WIN_DRIVE=%SystemDrive%"

:: ==========================================
:: 4. DETECCAO AVANCADA DE STATUS (SAFE MODE E SAFOBOOT)
:: ==========================================
set "SB_CONFIGURED=NAO"
bcdedit | findstr /i "safeboot" >nul
if !errorlevel! equ 0 set "SB_CONFIGURED=SIM"

:: Deteccao Real de Safe Mode pelo Registro (Evita remocao precoce)
set "IN_SAFE_MODE=NAO"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Option" >nul 2>&1
if !errorlevel! equ 0 set "IN_SAFE_MODE=SIM"

:: ==========================================
:: 4.5. DETECCAO DE STATUS DO INTEL VMD/RST
:: ==========================================
set "VMD_STATUS=DESATIVADO (AHCI/NVMe)"
:: Busca apenas por controladores de armazenamento conectados com nomes especificos do VMD
:: Isso evita o "falso positivo" gerado por servicos em background ou outras siglas parecidas
pnputil /enum-devices /connected | findstr /i /c:"RST VMD" /c:"Volume Management Device" /c:"Intel(R) VMD" >nul
if !errorlevel! equ 0 set "VMD_STATUS=ATIVO"

:: ==========================================
:: 5. PARSER DE BITLOCKER (ROBUSTO PT-BR/EN)
:: ==========================================
manage-bde -status %WIN_DRIVE% > "%TEMP_BL%" 2>&1

set "BL_STATUS=DESCONHECIDO"

:: Checagem de INATIVO (Baseado no seu Log real PT-BR e padroes EN)
:: Usando palavras sem acento para garantir estabilidade do parser
findstr /i /c:"Descriptografado" /c:"Desativada" /c:"Nenhum" /c:"Off" "%TEMP_BL%" >nul
if !errorlevel! equ 0 set "BL_STATUS=INATIVO"

:: Checagem de SUSPENSO
findstr /i /c:"Suspenso" /c:"Suspended" "%TEMP_BL%" >nul
if !errorlevel! equ 0 set "BL_STATUS=SUSPENSO"

:: Checagem de ATIVO (Totalmente Criptografado, Ativado, On)
findstr /i /c:"Totalmente Criptografado" /c:"Ativado" /c:"On" "%TEMP_BL%" >nul
if !errorlevel! equ 0 (
    :: Garante que nao sobrescreva se achou "Suspenso" na mesma tela
    if not "!BL_STATUS!"=="SUSPENSO" set "BL_STATUS=ATIVO"
)

:: Limpeza do temporario do BitLocker
del "%TEMP_BL%" >nul 2>&1

:: ==========================================
:: 6. INTERFACE GUIADA E DASHBOARD
:: ==========================================
:DASHBOARD
cls
echo =====================================================
echo    ASSISTENTE GUIADO: CONFIGURACAO DE CONTROLADORA
echo =====================================================
echo.
echo [INFORMACOES DO SISTEMA]
echo - Unidade Windows:        %WIN_DRIVE%
echo - Status Intel VMD/RST:   %VMD_STATUS%
echo - Status BitLocker:       %BL_STATUS%
echo - Flag bcdedit Safeboot:  %SB_CONFIGURED%
echo - Windows em Safe Mode:   %IN_SAFE_MODE%
echo.
echo [CONTROLE DE FLUXO]
echo - Etapa Atual:            Fase %CURRENT_STEP%
echo - Passagem pela BIOS:     %BIOS_DONE%
echo - Modo Alvo:              %TARGET_MODE%
echo.

:: LOGICA CONSERVADORA DE PROXIMA ACAO
if "%CURRENT_STEP%"=="1" goto OPCOES_FASE1

if "%CURRENT_STEP%"=="2" (
    if "%BIOS_DONE%"=="1" (
        if "%IN_SAFE_MODE%"=="SIM" (
            goto OPCOES_FASE2
        ) else (
            goto AVISO_SAFE_MODE
        )
    ) else (
        goto OPCOES_FASE1
    )
)

:OPCOES_FASE1
echo [MENU PRINCIPAL - FASE 1]
echo Escolha a operacao que deseja realizar:
echo.
echo  [1] DESATIVAR Intel VMD / RST (Migrar para AHCI)
echo      - Recomendado para instalar macOS (Hackintosh) ou Linux.
echo.
echo  [2] ATIVAR Intel VMD / RST (Reverter)
echo      - Recomendado para voltar ao padrao de fabrica do Windows.
echo.
echo  [S] Sair do Assistente
echo.
echo =====================================================
if "%VMD_STATUS%"=="ATIVO" (
    echo   SUGESTAO: O VMD esta ATIVO. Pressione [1] para Desativar.
) else (
    echo   SUGESTAO: O VMD esta DESATIVADO. Pressione [2] para Reativar.
)
echo =====================================================
echo.
choice /c 12S /n /m "Escolha uma opcao [1, 2 ou S]: "
if errorlevel 3 exit /b
if errorlevel 2 goto EXEC_FASE1_ENABLE
if errorlevel 1 goto EXEC_FASE1_DISABLE

:OPCOES_FASE2
color 0E
echo [FASE 2 - RETORNO DA BIOS]
echo O que sera feito agora:
echo  [X] Remover a tag de Modo de Seguranca do Boot
echo  [X] Reiniciar o PC normalmente
echo.
echo =====================================================
echo   SUGESTAO DO ASSISTENTE: INICIAR A FASE 2
echo =====================================================
echo.
choice /c 2RS /n /m "Pressione [2] p/ Executar Fase 2, [R] p/ Refazer Fase 1 ou [S] Sair: "
if errorlevel 3 exit /b
if errorlevel 2 (
    set "CURRENT_STEP=1"
    set "BIOS_DONE=0"
    set "TARGET_MODE=Nenhum"
    goto DASHBOARD
)
if errorlevel 1 goto EXEC_FASE2

:AVISO_SAFE_MODE
color 0C
echo [ATENCAO: INCONSISTENCIA DETECTADA]
echo O script indica que voce ja deveria ter ido a BIOS (Fase 2),
echo mas o Windows NAO esta rodando no Modo de Seguranca Real.
echo.
echo Se voce ainda nao alterou a configuracao na BIOS, reinicie e faca isso.
echo Se o Windows carregou normal sem Safe Mode, a Fase 1 falhou.
echo.
choice /c RS /n /m "Pressione [R] para Refazer a Fase 1 ou [S] para Sair: "
if errorlevel 2 exit /b
if errorlevel 1 (
    set "CURRENT_STEP=1"
    set "BIOS_DONE=0"
    set "TARGET_MODE=Nenhum"
    goto DASHBOARD
)

:: ==========================================
:: EXECUCOES (SEM DUPLICACAO DE SAIDA TELA/LOG)
:: ==========================================

:EXEC_FASE1_DISABLE
set "TARGET_MODE=AHCI"
set "BIOS_MSG=Localize a opcao "Intel VMD", "Intel RST" ou "RAID" e DESATIVE-A (Mude para AHCI)."
goto EXEC_FASE1_COMMON

:EXEC_FASE1_ENABLE
set "TARGET_MODE=VMD"
set "BIOS_MSG=Localize a opcao de Armazenamento/SATA e ATIVE o "Intel VMD", "Intel RST" ou "RAID"."
goto EXEC_FASE1_COMMON

:EXEC_FASE1_COMMON
cls
echo [%DATE% %TIME%] === INICIANDO FASE 1 (Alvo: %TARGET_MODE%) === >> "%LOG_FILE%"

if "%BL_STATUS%"=="ATIVO" (
    echo --^> Suspendendo BitLocker na unidade %WIN_DRIVE%...
    echo [%DATE% %TIME%] ACAO: Suspendendo BitLocker >> "%LOG_FILE%"
    manage-bde -protectors -disable %WIN_DRIVE% > "%TEMP_CMD%" 2>&1
    type "%TEMP_CMD%"
    type "%TEMP_CMD%" >> "%LOG_FILE%"
    del "%TEMP_CMD%" >nul 2>&1
) else (
    echo --^> BitLocker Inativo ou Suspenso. Nenhuma acao necessaria.
    echo [%DATE% %TIME%] ACAO: BitLocker ignorado (Status: %BL_STATUS%) >> "%LOG_FILE%"
)
echo. >> "%LOG_FILE%"

echo --^> Configurando boot para Modo de Seguranca (safeboot minimal)...
echo [%DATE% %TIME%] ACAO: Configurando bcdedit safeboot >> "%LOG_FILE%"
bcdedit /set {current} safeboot minimal > "%TEMP_CMD%" 2>&1
type "%TEMP_CMD%"
type "%TEMP_CMD%" >> "%LOG_FILE%"
del "%TEMP_CMD%" >nul 2>&1
echo. >> "%LOG_FILE%"

:: Salva o estado de forma ampliada
(
echo CURRENT_STEP=2
echo BIOS_DONE=1
echo LAST_ACTION=Reboot_to_BIOS
echo TARGET_MODE=%TARGET_MODE%
) > "%STATE_FILE%"
echo [%DATE% %TIME%] ESTADO: VMD_State.ini atualizado. >> "%LOG_FILE%"

echo.
echo =====================================================
echo TUDO PRONTO PARA A BIOS!
echo =====================================================
echo O PC sera reiniciado em 10 segundos direto para a BIOS.
echo.
echo LEMBRETE IMPORTANTE PARA A BIOS:
echo 1. Acesse as configuracoes avancadas da sua placa-mae.
echo 2. Busque por configuracoes de Armazenamento (Storage), VMD ou System Agent.
echo 3. %BIOS_MSG%
echo 4. Salve as alteracoes e saia (geralmente teclando F10).
echo 5. O Windows iniciara em Modo de Seguranca automaticamente.
echo =====================================================
pause

echo --^> Agendando reinicializacao (Firmware)...
shutdown /r /fw /t 10
if !errorlevel! neq 0 (
    echo [AVISO] Reinicio direto para BIOS nao suportado. Fazendo reinicio normal.
    echo FIQUE APERTANDO F2 ou DEL para entrar na BIOS manualmente!
    shutdown /r /t 10
)
exit /b

:EXEC_FASE2
cls
color 0A
echo [%DATE% %TIME%] === INICIANDO FASE 2 === >> "%LOG_FILE%"

echo --^> Removendo configuracao de Modo de Seguranca...
echo [%DATE% %TIME%] ACAO: Removendo bcdedit safeboot >> "%LOG_FILE%"
bcdedit /deletevalue {current} safeboot > "%TEMP_CMD%" 2>&1
type "%TEMP_CMD%"
type "%TEMP_CMD%" >> "%LOG_FILE%"
del "%TEMP_CMD%" >nul 2>&1
echo. >> "%LOG_FILE%"

:: Limpeza final
if exist "%STATE_FILE%" del "%STATE_FILE%"
echo [%DATE% %TIME%] ESTADO: VMD_State.ini removido. Fluxo Concluido. >> "%LOG_FILE%"

echo.
echo =====================================================
echo MIGRACAO CONCLUIDA COM SUCESSO!
echo =====================================================
echo O Windows agora esta configurado para iniciar normalmente
if "%TARGET_MODE%"=="AHCI" (
    echo utilizando o driver AHCI / NVMe nativo, sem VMD.
) else (
    echo utilizando a controladora Intel VMD / RST.
)
echo.
echo O computador sera reiniciado em 5 segundos.
echo =====================================================
pause

shutdown /r /t 5
exit /b