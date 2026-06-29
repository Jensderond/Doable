# Doable — common commands
# Run `just` with no args to list available recipes.

project := "Doable.xcodeproj"
scheme := "Doable"

# List available recipes
default:
    @just --list

# Build the app (Debug). Auto-installs + re-signs into /Applications via build phase.
build config="Debug":
    xcodebuild -project {{project}} -scheme {{scheme}} -configuration {{config}} build

# Build, then launch the installed app from /Applications
run config="Debug": (build config)
    open /Applications/Doable.app

# Run the DoableCore unit tests
test:
    cd Core && swift test

# Clean build artifacts
clean:
    xcodebuild -project {{project}} -scheme {{scheme}} clean
