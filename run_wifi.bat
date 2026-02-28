@echo off
REM Setup kết nối không dây giữa Flutter và Backend
REM Dùng ADB reverse để phone truy cập backend qua localhost

echo === AI Interior Design - Wireless Setup ===
echo.

REM Step 1: Check ADB devices
echo [1/3] Checking connected devices...
adb devices
echo.

REM Step 2: Setup ADB reverse
echo [2/3] Setting up ADB reverse port forwarding...
adb reverse tcp:8000 tcp:8000

if %ERRORLEVEL% EQU 0 (
    echo      ADB reverse OK!
    echo      Phone localhost:8000 --^> PC localhost:8000 --^> WSL backend
    echo.
    echo [3/3] Starting Flutter app...
    echo.
    echo ============================================
    echo   App URL: http://localhost:8000
    echo   Backend chạy trên WSL, ADB reverse forward
    echo   Không cần biết IP!
    echo ============================================
    echo.
    flutter run
) else (
    echo.
    echo ERROR: ADB reverse failed!
    echo.
    echo Nếu dùng Wireless ADB:
    echo   1. Trên điện thoại: Settings ^> Developer Options ^> Wireless Debugging
    echo   2. Lấy IP:Port từ màn hình Wireless Debugging
    echo   3. Chạy: adb connect ^<IP^>:^<PORT^>
    echo   4. Chạy lại script này
    echo.
    echo Nếu dùng USB:
    echo   1. Cắm cáp USB
    echo   2. Chấp nhận "USB Debugging" trên điện thoại
    echo   3. Chạy lại script này
    echo.
    pause
)
