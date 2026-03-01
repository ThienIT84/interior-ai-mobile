# Quick Start Guide - Task 1.4.2

## Current Situation
You have 91 modified files, but most are auto-generated platform files that should NOT be committed.

## What to Do

### Option 1: Use the Automated Script (Recommended)
```bash
cd /mnt/d/interior_ai/frontend
bash setup_git_and_branch.sh
```

This script will:
1. Stage only important files (lib/, docs, .gitignore, configs)
2. Show you what will be committed (review it!)
3. Commit to main branch
4. Create feature branch `feature/task-1.4.2-mask-refinement`

### Option 2: Manual Steps

```bash
# 1. Stage important files only
git add .gitignore
git add lib/
git add README.md SETUP_GUIDE.md TASK_1.4.2_IMPLEMENTATION_GUIDE.md
git add pubspec.yaml analysis_options.yaml run_wifi.bat

# 2. Review what will be committed
git status

# 3. Commit to main
git commit -m "feat: implement SAM segmentation and inpainting UI

- Interactive SAM segmentation with point selection
- Mask overlay visualization
- Async inpainting with job polling
- Updated .gitignore to exclude platform files

Tasks completed: 1.1-1.3, 2.1-2.2"

# 4. Create feature branch
git checkout -b feature/task-1.4.2-mask-refinement
```

## After Branch Creation

### Implement the Opacity Slider

Edit `lib/screens/segmentation_screen.dart`:

1. Add state variable (line ~30):
```dart
double _maskOpacity = 0.4;
```

2. Add PopupMenuButton in AppBar actions (line ~60):
```dart
PopupMenuButton(
  icon: const Icon(Icons.opacity),
  tooltip: 'Adjust mask opacity',
  itemBuilder: (context) => [
    PopupMenuItem(
      enabled: false,
      child: Column(
        children: [
          const Text('Mask Opacity'),
          Slider(
            value: _maskOpacity,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            label: _maskOpacity.toStringAsFixed(1),
            onChanged: (value) {
              setState(() => _maskOpacity = value);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  ],
),
```

3. Update mask overlay color (line ~200):
```dart
color: Colors.red.withOpacity(_maskOpacity),
```

### Test
```bash
flutter run
```

### Commit Implementation
```bash
git add lib/screens/segmentation_screen.dart
git commit -m "feat: add mask opacity slider for task 1.4.2

- Add opacity state variable (default 0.4)
- Add PopupMenuButton with slider in AppBar
- Update mask overlay to use dynamic opacity
- Range: 0.0-1.0 with 10 divisions

Task 1.4.2 completed"
```

### Merge Back to Main
```bash
git checkout main
git merge feature/task-1.4.2-mask-refinement
git branch -d feature/task-1.4.2-mask-refinement
```

## Important Notes

✅ **DO commit**: lib/, docs, .gitignore, pubspec.yaml, analysis_options.yaml
❌ **DON'T commit**: android/, ios/, windows/, linux/, macos/, web/, test/

The updated `.gitignore` will prevent platform files from being committed in the future.
