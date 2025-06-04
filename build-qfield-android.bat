@echo off
setlocal

REM === CONFIGURACIÓN ===
set "PROJECT_DIR=D:\Users\USER\Documents\GitHub\QField"
set "BUILD_DIR=%PROJECT_DIR%\build-android"

set "QT_ANDROID=C:\Users\USER\aqt\6.5.0\android_arm64_v8a"
set "QT_DESKTOP=C:\Users\USER\aqt\6.5.0\mingw_64"
set "NDK_DIR=C:\Users\USER\AppData\Local\Android\Sdk\ndk\29.0.13113456"
set "TOOLCHAIN_FILE=%NDK_DIR%\build\cmake\android.toolchain.cmake"

REM === LIMPIEZA DE BUILDS ANTERIORES ===
echo [INFO] Limpiando configuraciones anteriores...
rmdir /S /Q "%BUILD_DIR%" 2>nul
mkdir "%BUILD_DIR%"

REM === COMPROBACIONES RÁPIDAS ===
echo [INFO] Verificando rutas de Qt Desktop y Qt Android...

REM 1) android.toolchain.cmake
if not exist "%TOOLCHAIN_FILE%" (
    echo [ERROR] No se encontró android.toolchain.cmake en:
    echo    %TOOLCHAIN_FILE%
    exit /b 1
)

REM 2) Qt6Config.cmake (Android)
if not exist "%QT_ANDROID%\lib\cmake\Qt6\Qt6Config.cmake" (
    echo [ERROR] No se encontró Qt6Config.cmake en Qt Android:
    echo    %QT_ANDROID%\lib\cmake\Qt6\Qt6Config.cmake
    exit /b 1
)

REM 3) Qt6CoreConfig.cmake (Desktop)
if not exist "%QT_DESKTOP%\lib\cmake\Qt6Core\Qt6CoreConfig.cmake" (
    echo [ERROR] No se encontró Qt6CoreConfig.cmake en Qt Desktop:
    echo    %QT_DESKTOP%\lib\cmake\Qt6Core\Qt6CoreConfig.cmake
    exit /b 1
)

REM 4) Qt6ConcurrentConfig.cmake (Desktop)
if not exist "%QT_DESKTOP%\lib\cmake\Qt6Concurrent\Qt6ConcurrentConfig.cmake" (
    echo [ERROR] No se encontró Qt6ConcurrentConfig.cmake en Qt Desktop:
    echo    %QT_DESKTOP%\lib\cmake\Qt6Concurrent\Qt6ConcurrentConfig.cmake
    exit /b 1
)

REM 5) Qt6WidgetsConfig.cmake (Desktop)
if not exist "%QT_DESKTOP%\lib\cmake\Qt6Widgets\Qt6WidgetsConfig.cmake" (
    echo [ERROR] No se encontró Qt6WidgetsConfig.cmake en Qt Desktop:
    echo    %QT_DESKTOP%\lib\cmake\Qt6Widgets\Qt6WidgetsConfig.cmake
    exit /b 1
)

REM 6) Qt6ZlibPrivateConfig.cmake (Desktop)
if not exist "%QT_DESKTOP%\lib\cmake\Qt6ZlibPrivate\Qt6ZlibPrivateConfig.cmake" (
    echo [ERROR] No se encontró Qt6ZlibPrivateConfig.cmake en Qt Desktop:
    echo    %QT_DESKTOP%\lib\cmake\Qt6ZlibPrivate\Qt6ZlibPrivateConfig.cmake
    echo.
    echo -> Asegúrate de instalar el módulo "ZlibPrivate" en tu Qt Desktop.
    exit /b 1
)

echo [INFO] Todas las rutas necesarias existen. Continuando con CMake...

REM === CONFIGURACIÓN DE CMAKE ===
echo.
echo [INFO] Ejecutando configuración con CMake...
cmake -S "%PROJECT_DIR%" -B "%BUILD_DIR%" ^
    -G "Ninja" ^
    -DCMAKE_TOOLCHAIN_FILE="%TOOLCHAIN_FILE%" ^
    -DQt6Core_DIR="%QT_DESKTOP%\lib\cmake\Qt6Core" ^
    -DQt6Concurrent_DIR="%QT_DESKTOP%\lib\cmake\Qt6Concurrent" ^
    -DQt6Widgets_DIR="%QT_DESKTOP%\lib\cmake\Qt6Widgets" ^
    -DQt6ZlibPrivate_DIR="%QT_DESKTOP%\lib\cmake\Qt6ZlibPrivate" ^
    -DQt6_DIR="%QT_ANDROID%\lib\cmake\Qt6" ^
    -DQT_HOST_PATH="%QT_DESKTOP%" ^
    -DCMAKE_PREFIX_PATH="%QT_DESKTOP%;%QT_ANDROID%" ^
    -DCMAKE_SYSTEM_NAME=Android ^
    -DANDROID_ABI=arm64-v8a ^
    -DANDROID_PLATFORM=android-21 ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DWITH_VCPKG=OFF

if errorlevel 1 (
    echo [ERROR] Falló la configuración con CMake.
    exit /b 1
)

REM === COMPILACIÓN ===
echo.
echo [INFO] Compilando el proyecto...
cmake --build "%BUILD_DIR%"

if errorlevel 1 (
    echo [ERROR] Falló la compilación.
    exit /b 1
)

echo.
echo [OK] ✅ Compilación exitosa.
exit /b 0
