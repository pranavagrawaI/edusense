@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: --------------------------------------
:: 1. Clean Flutter cache and run pub get
:: --------------------------------------
echo Cleaning Flutter cache...
flutter clean
flutter pub get

:: --------------------------------------
:: 2. Detect Gradle build file and enable minify/shrink
:: --------------------------------------
if exist "android\app\build.gradle.kts" (
    echo Found Kotlin DSL (build.gradle.kts). Attempting to enable minify & shrinkResources...
    call :enableMinifyKts
) else if exist "android\app\build.gradle" (
    echo Found Groovy DSL (build.gradle). Attempting to enable minify & shrinkResources...
    call :enableMinifyGroovy
) else (
    echo No build.gradle or build.gradle.kts found in android\app. Skipping minify changes.
)

:: --------------------------------------
:: 3. Recursively convert PNG/JPG to WebP
:: --------------------------------------
echo Optimizing images to WebP...
for /r assets %%F in (*.png *.jpg) do (
    call :convertToWebp "%%F"
)

:: --------------------------------------
:: 4. Update pubspec.yaml references from .png/.jpg to .webp
:: --------------------------------------
echo Updating pubspec.yaml to reflect WebP images...
(for /f "usebackq tokens=*" %%I in ("pubspec.yaml") do (
    set "line=%%I"
    set "line=!line:.png=.webp!"
    set "line=!line:.jpg=.webp!"
    echo !line!
)) > pubspec.yaml.tmp
move /Y pubspec.yaml.tmp pubspec.yaml > nul

:: --------------------------------------
:: 5. Build APKs (split by ABI) & App Bundle
:: --------------------------------------
echo Building optimized APKs...
flutter build apk --split-per-abi

echo Building optimized App Bundle...
flutter build appbundle

echo Optimization complete!
endlocal
exit /b 0

:: --------------------------------------
:: Function: enableMinifyGroovy
:: Description: Sets minifyEnabled=true and shrinkResources=true in Groovy DSL
:: --------------------------------------
:enableMinifyGroovy
set "foundReleaseBlock=0"
(for /f "usebackq tokens=*" %%G in ("android\app\build.gradle") do (
    set "line=%%G"

    :: We look for "release {" block, then set minifyEnabled / shrinkResources inside it
    if "!line!"=="        release {" (
        set "foundReleaseBlock=1"
    )

    if "!foundReleaseBlock!"=="1" (
        if "!line!"=="            minifyEnabled false" (
            set "line=            minifyEnabled true"
        )
        if "!line!"=="            shrinkResources false" (
            set "line=            shrinkResources true"
        )
        :: If we hit the closing bracket of the release block, stop searching
        if "!line!"=="        }" (
            set "foundReleaseBlock=0"
        )
    )

    echo !line!
)) > "android\app\build.gradle.tmp"
move /Y "android\app\build.gradle.tmp" "android\app\build.gradle" > nul
exit /b 0

:: --------------------------------------
:: Function: enableMinifyKts
:: Description: Sets minifyEnabled=true and shrinkResources=true in Kotlin DSL
:: --------------------------------------
:enableMinifyKts
set "foundReleaseBlock=0"
(for /f "usebackq tokens=*" %%G in ("android\app\build.gradle.kts") do (
    set "line=%%G"

    :: Looks for "release {" in Kotlin DSL
    if "!line!"=="        create("release") {" (
        set "foundReleaseBlock=1"
    ) else if "!line!"=="        release {" (
        set "foundReleaseBlock=1"
    )

    if "!foundReleaseBlock!"=="1" (
        :: Replace minifyEnabled and shrinkResources in the release block
        if "!line!"=="            isMinifyEnabled = false" (
            set "line=            isMinifyEnabled = true"
        )
        if "!line!"=="            isShrinkResources = false" (
            set "line=            isShrinkResources = true"
        )
        :: End searching after the release block ends
        if "!line!"=="        }" (
            set "foundReleaseBlock=0"
        )
    )

    echo !line!
)) > "android\app\build.gradle.kts.tmp"
move /Y "android\app\build.gradle.kts.tmp" "android\app\build.gradle.kts" > nul
exit /b 0

:: --------------------------------------
:: Function: convertToWebp
:: Description: Converts a PNG/JPG file to WebP using cwebp at quality=80, then deletes the original file.
:: --------------------------------------
:convertToWebp
set "originalFile=%~1"

rem Replace extension with .webp
set "webpFile=%originalFile:.png=.webp%"
set "webpFile=%webpFile:.jpg=.webp%"

echo Converting %originalFile% to %webpFile% ...
cwebp -q 80 "%originalFile%" -o "%webpFile%"
if exist "%webpFile%" (
    del "%originalFile%"
)
exit /b 0
