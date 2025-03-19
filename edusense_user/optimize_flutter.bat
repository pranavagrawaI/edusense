@echo off
setlocal EnableDelayedExpansion

echo Cleaning Flutter cache...
flutter clean
flutter pub get

:: Enable ProGuard & Resource Shrinking
(for /f "tokens=*" %%i in ('type android\app\build.gradle') do (
    set "line=%%i"
    set "line=!line:minifyEnabled false=minifyEnabled true!"
    set "line=!line:shrinkResources false=shrinkResources true!"
    echo !line!
)) > android\app\build.gradle.tmp
move /Y android\app\build.gradle.tmp android\app\build.gradle

echo Optimizing images...
for %%F in (assets\*.png assets\*.jpg) do (
    set "webp_out=%%~dpnF.webp"
    cwebp -q 80 "%%F" -o "!webp_out!"
    del "%%F"
)

echo Updating pubspec.yaml to reflect WebP images...
(for /f "tokens=*" %%i in ('type pubspec.yaml') do (
    set "line=%%i"
    set "line=!line:.png=.webp!"
    set "line=!line:.jpg=.webp!"
    echo !line!
)) > pubspec.yaml.tmp
move /Y pubspec.yaml.tmp pubspec.yaml

echo Building optimized APKs...
flutter build apk --split-per-abi

echo Building optimized App Bundle...
flutter build appbundle

echo Optimization complete! Check the build/outputs directory for reduced-size APKs & AAB files.
endlocal
