# AI Interior Design - Flutter App

Mobile app for AI-powered interior design with object removal and AR visualization.

## 🎯 Features

- ✅ **Image Upload**: Camera or gallery
- ✅ **Interactive Segmentation**: Tap to select objects
- ✅ **Object Removal**: AI-powered inpainting (13-15 min)
- ✅ **Progress Tracking**: Real-time job status
- ⏳ **Design Generation**: ControlNet styles (Week 3)
- ⏳ **AR Visualization**: 3D object placement (Week 4)

## 🚀 Quick Start

### Prerequisites
- Flutter SDK installed
- Android device with USB debugging enabled
- Backend running on WSL

### Run App (WiFi - Recommended)

```powershell
# Auto-detect WSL IP and run
.\run_wifi.bat
```

### Run App (USB - Most Stable)

```powershell
# Setup port forwarding
.\setup_adb.bat

# Run app
.\run_app.bat
```

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed instructions.

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── config.dart                  # API configuration
├── models/
│   └── point_model.dart         # Segmentation point model
├── services/
│   └── api_service.dart         # Backend API client
└── screens/
    ├── segmentation_screen.dart # ✅ Tap-to-select UI
    └── inpainting_screen.dart   # ✅ Progress & result
```

## 🔧 Configuration

### API Endpoint

Edit `lib/config.dart`:

```dart
class AppConfig {
  static String get baseUrl {
    // WiFi mode (auto-updated by run_wifi.bat)
    return "http://172.22.105.141:8000";
    
    // USB mode (after setup_adb.bat)
    // return "http://localhost:8000";
  }
}
```

### Timeouts

```dart
static const uploadTimeout = Duration(seconds: 60);  // WiFi upload
static const receiveTimeout = Duration(seconds: 30); // API calls
```

## 📱 User Flow

1. **Select Image** → Camera or gallery
2. **Start Segmentation** → Upload to backend
3. **Tap Object** → Select furniture to remove
4. **View Mask** → Red overlay shows selection
5. **Remove Object** → Submit inpainting job
6. **Wait 13-15 min** → Progress bar with timer
7. **View Result** → Empty room generated
8. **Generate Design** → (Coming in Week 3)

## 🛠️ Available Scripts

| Script | Purpose |
|--------|---------|
| `run_wifi.bat` | ⭐ Auto-detect IP + run |
| `run_app.bat` | Run with current config |
| `setup_adb.bat` | Setup USB connection |
| `debug_connection.ps1` | Diagnose issues |
| `fix_firewall.ps1` | Open port 8000 |
| `test_connection.ps1` | Test backend |
| `update_wsl_ip.ps1` | Update IP only |

## 🐛 Troubleshooting

### "Upload failed - timeout"

```powershell
# Fix 1: Check firewall
.\fix_firewall.ps1

# Fix 2: Debug connection
.\debug_connection.ps1

# Fix 3: Use USB
.\setup_adb.bat
```

### "Connection refused"

Backend not running. Start it:
```bash
cd ~/interior_project/backend
~/miniconda3/envs/interior_ai/bin/python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### WSL IP changed

```powershell
# Auto-fix
.\run_wifi.bat
```

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for more troubleshooting.

## 📊 Performance

| Operation | Time | Notes |
|-----------|------|-------|
| Image Upload | 2-5s | Depends on WiFi/USB |
| SAM Segmentation | 0.5-1s | Per tap |
| Inpainting | 13-15 min | GTX 1650 4GB |

## 🎨 UI Screens

### Segmentation Screen
- Image display with tap detection
- Green numbered markers (1, 2, 3...)
- Red mask overlay (toggleable)
- Undo/Clear buttons
- "Remove Object" action

### Inpainting Screen
- Animated progress indicator
- Timer showing elapsed time
- Status messages
- Result display
- Navigation to generation (Week 3)

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0           # API calls
  image_picker: ^1.0.7   # Camera/gallery
  
dev_dependencies:
  flutter_test:
    sdk: flutter
```

## 🔄 Development Workflow

### 1. Start Backend
```bash
# In Kiro terminal (WSL)
cd ~/interior_project/backend
~/miniconda3/envs/interior_ai/bin/python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 2. Run Flutter
```powershell
# In PowerShell (Windows)
cd D:\interior_ai\frontend
.\run_wifi.bat
```

### 3. Hot Reload
Press `r` in terminal for hot reload during development.

## 📈 Roadmap

- [x] **Week 1**: Image upload + segmentation UI
- [x] **Week 2 (Day 8-9)**: Inpainting integration
- [ ] **Week 2 (Day 10-14)**: UI polish + testing
- [ ] **Week 3**: ControlNet generation UI
- [ ] **Week 4**: AR visualization

## 🎯 Next Features (Week 3)

- [ ] Before/after comparison slider
- [ ] Style selection UI (Modern, Minimalist, Industrial)
- [ ] Multiple design generation
- [ ] Save/share results

## 📝 Notes

- App requires internet connection (WiFi or mobile data)
- Backend must be running before starting app
- USB mode more stable than WiFi
- Inpainting takes 13-15 minutes (show progress to user)
- Results are cached on backend

## 🔗 Related Documentation

- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Detailed setup instructions
- **Backend**: `~/interior_project/backend/README.md`
- **API Docs**: http://localhost:8000/docs (when backend running)

## 🆘 Support

1. Check [SETUP_GUIDE.md](SETUP_GUIDE.md)
2. Run `debug_connection.ps1`
3. Check backend logs in Kiro terminal
4. Try USB mode as fallback

## ✅ Pre-flight Checklist

Before running:
- [ ] Backend running in Kiro terminal
- [ ] Phone connected (USB or same WiFi)
- [ ] USB debugging enabled (if USB mode)
- [ ] Firewall allows port 8000 (if WiFi mode)
- [ ] Config.dart has correct URL

Then:
```powershell
.\run_wifi.bat
```

---

**Current Status**: Week 2 Day 8-9 Complete ✅  
**Next**: Testing & optimization (Week 2 Day 10-14)
