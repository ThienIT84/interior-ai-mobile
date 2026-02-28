# Flutter App Setup Guide

## 🚀 Quick Start (Recommended)

### Method 1: WiFi Connection (Easiest)

```powershell
# Auto-detect WSL IP and run
.\run_wifi.bat
```

**What it does:**
1. Detects current WSL IP automatically
2. Updates `lib/config.dart` with correct IP
3. Runs Flutter app

**When to use:** Default method, works most of the time

---

### Method 2: USB Connection (Most Stable)

```powershell
# Setup ADB reverse port forwarding
.\setup_adb.bat

# Then run app normally
.\run_app.bat
```

**What it does:**
1. Forwards port 8000 from phone to PC
2. App uses `localhost:8000` (no IP needed)

**When to use:** WiFi connection issues, or prefer USB

---

## 📱 Prerequisites

### 1. Enable Developer Mode (Android)
1. Settings → About Phone
2. Tap "Build Number" 7 times
3. Go back → Developer Options
4. Enable "USB Debugging"

### 2. Install Flutter
- Flutter SDK installed
- Android SDK configured
- Device connected (USB or WiFi)

### 3. Backend Running
```bash
# In Kiro terminal (WSL)
cd ~/interior_project/backend
~/miniconda3/envs/interior_ai/bin/python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

---

## 🔧 Available Scripts

### Main Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `run_wifi.bat` | Auto-detect IP + run | ⭐ Default method |
| `run_app.bat` | Run with current config | Config already set |
| `setup_adb.bat` | Setup USB connection | WiFi issues |

### Utility Scripts

| Script | Purpose |
|--------|---------|
| `update_wsl_ip.ps1` | Update IP only (no run) |
| `debug_connection.ps1` | Diagnose connection issues |
| `fix_firewall.ps1` | Open port 8000 in Windows Firewall |
| `test_connection.ps1` | Test backend connectivity |

---

## 🐛 Troubleshooting

### Issue 1: "Upload failed - timeout"

**Cause:** Phone can't reach backend

**Solutions:**
1. **Check same WiFi network**
   ```powershell
   # On PC: Check WiFi name
   netsh wlan show interfaces
   
   # On Phone: Settings → WiFi
   # Must be same network!
   ```

2. **Fix Windows Firewall**
   ```powershell
   # Run as Administrator
   .\fix_firewall.ps1
   ```

3. **Test connection**
   ```powershell
   .\debug_connection.ps1
   ```

4. **Switch to USB**
   ```powershell
   .\setup_adb.bat
   # Update config.dart to use localhost
   .\run_app.bat
   ```

---

### Issue 2: "Connection refused"

**Cause:** Backend not running

**Solution:**
```bash
# Start backend in Kiro terminal
cd ~/interior_project/backend
~/miniconda3/envs/interior_ai/bin/python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

---

### Issue 3: WSL IP changed

**Cause:** Windows restart changes WSL IP

**Solution:**
```powershell
# Auto-fix
.\run_wifi.bat

# Or manual
.\update_wsl_ip.ps1
```

---

### Issue 4: "No devices found"

**Cause:** Phone not connected

**Solution:**
```powershell
# Check devices
adb devices

# If empty:
# 1. Reconnect USB cable
# 2. Accept "USB Debugging" prompt on phone
# 3. Run: adb devices again
```

---

## 🔍 Debug Connection Issues

### Step 1: Check Backend
```bash
# In WSL, check if running
curl http://localhost:8000/docs
# Should return HTML
```

### Step 2: Find WSL IP
```powershell
# In PowerShell
wsl hostname -I
# Example output: 172.22.105.141
```

### Step 3: Test from Phone
Open browser on phone:
```
http://172.22.105.141:8000/docs
```
- ✅ If loads → Backend OK, check app config
- ❌ If fails → Firewall or WiFi issue

### Step 4: Run Debug Script
```powershell
.\debug_connection.ps1
```

---

## ⚙️ Configuration

### WiFi Mode (Default)
```dart
// lib/config.dart
static String get baseUrl {
  return "http://172.22.105.141:8000";  // Auto-updated by run_wifi.bat
}
```

### USB Mode (Localhost)
```dart
// lib/config.dart
static String get baseUrl {
  return "http://localhost:8000";  // After setup_adb.bat
}
```

---

## 📊 Connection Methods Comparison

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **WiFi** | No cable, flexible | IP changes, firewall issues | Development |
| **USB** | Stable, fast | Need cable | Testing, demo |

---

## 🎯 Recommended Workflow

### Daily Development
```powershell
# 1. Start backend (in Kiro/WSL)
cd ~/interior_project/backend
~/miniconda3/envs/interior_ai/bin/python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# 2. Run Flutter (in PowerShell)
cd D:\interior_ai\frontend
.\run_wifi.bat
```

### Demo/Presentation
```powershell
# Use USB for stability
.\setup_adb.bat
.\run_app.bat
```

---

## 📝 Notes

- **WSL IP changes** after Windows restart → Use `run_wifi.bat`
- **Firewall** may block first time → Use `fix_firewall.ps1`
- **Same WiFi** required for WiFi mode
- **USB debugging** must be enabled for USB mode
- **Backend must run** on `0.0.0.0:8000` (not `127.0.0.1`)

---

## 🆘 Still Having Issues?

1. Check `debug_connection.ps1` output
2. Verify backend logs in Kiro terminal
3. Try USB mode as fallback
4. Check phone's WiFi settings
5. Restart backend and try again

---

## 📚 Related Files

- `lib/config.dart` - API configuration
- `lib/services/api_service.dart` - API client
- Backend: `~/interior_project/backend/`

---

## ✅ Success Checklist

Before running app:
- [ ] Backend running in Kiro terminal
- [ ] Phone connected (USB or same WiFi)
- [ ] USB debugging enabled (if using USB)
- [ ] Windows Firewall allows port 8000 (if using WiFi)
- [ ] Config.dart has correct URL

Then run:
```powershell
.\run_wifi.bat  # or .\run_app.bat
```
