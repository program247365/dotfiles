gch() {
  git branch | sk | xargs git checkout
}

gcode() {
  cd `lsd -ld code/*/*  | awk '{ print $11 }' | sk`
}

mzk () {
  find $HOME/.kevin/listen -type f \( -name "*.mp3" -o -name "*.wav" \) | sk --height 40% --reverse | tr '\n' '\0' | xargs -0 $HOME/.kevin/bin/looper play --url
}

npmr() {
  npm run | sk | xargs npm run
}

calculate-xcode() {
  # Check derived data size
  du -sh ~/Library/Developer/Xcode/DerivedData

  # Check all Xcode-related storage
  du -sh ~/Library/Developer/Xcode/*
}

clean-xcode() {
  echo "🧹 Starting Xcode cleanup..."
  echo ""

  # Show initial sizes
  echo "📊 Current Xcode storage usage:"
  calculate-xcode
  echo ""

  # Store initial size for comparison
  local initial_size=$(du -sk ~/Library/Developer/Xcode 2>/dev/null | cut -f1)

  echo "🗑️  Cleaning up Xcode files..."
  echo ""

  # Derived Data
  if [[ -d ~/Library/Developer/Xcode/DerivedData ]]; then
    local derived_size=$(du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null | cut -f1)
    echo "  • Removing DerivedData ($derived_size)..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/*
    echo "    ✅ DerivedData cleared"
  else
    echo "  • DerivedData directory not found (skipping)"
  fi

  # Module Cache (already covered by DerivedData/* but being explicit)
  if [[ -d ~/Library/Developer/Xcode/DerivedData/ModuleCache ]]; then
    echo "  • Clearing ModuleCache..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache/*
    echo "    ✅ ModuleCache cleared"
  fi

  # Device Support
  local ios_support_size="0B"
  local watchos_support_size="0B"

  if [[ -d ~/Library/Developer/Xcode/iOS\ DeviceSupport ]]; then
    ios_support_size=$(du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport 2>/dev/null | cut -f1)
    echo "  • Removing iOS DeviceSupport ($ios_support_size)..."
    rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/*
    echo "    ✅ iOS DeviceSupport cleared"
  else
    echo "  • iOS DeviceSupport directory not found (skipping)"
  fi

  if [[ -d ~/Library/Developer/Xcode/watchOS\ DeviceSupport ]]; then
    watchos_support_size=$(du -sh ~/Library/Developer/Xcode/watchOS\ DeviceSupport 2>/dev/null | cut -f1)
    echo "  • Removing watchOS DeviceSupport ($watchos_support_size)..."
    rm -rf ~/Library/Developer/Xcode/watchOS\ DeviceSupport/*
    echo "    ✅ watchOS DeviceSupport cleared"
  else
    echo "  • watchOS DeviceSupport directory not found (skipping)"
  fi

  # Simulators
  echo "  • Cleaning unavailable simulators..."
  local sim_output=$(xcrun simctl delete unavailable 2>&1)
  if [[ $? -eq 0 ]]; then
    echo "    ✅ Unavailable simulators removed"
    if [[ -n "$sim_output" && "$sim_output" != *"No devices"* ]]; then
      echo "    📱 Simulator cleanup details:"
      echo "$sim_output" | sed 's/^/      /'
    fi
  else
    echo "    ⚠️  Failed to clean simulators: $sim_output"
  fi

  # Archives note
  echo "  • Archives preserved (use 'rm -rf ~/Library/Developer/Xcode/Archives/*' if needed)"

  echo ""
  echo "📊 Final Xcode storage usage:"
  calculate-xcode

  # Calculate space freed
  local final_size=$(du -sk ~/Library/Developer/Xcode 2>/dev/null | cut -f1)
  local space_freed=$((initial_size - final_size))

  if [[ $space_freed -gt 0 ]]; then
    local space_freed_mb=$((space_freed / 1024))
    local space_freed_gb=$((space_freed_mb / 1024))

    if [[ $space_freed_gb -gt 0 ]]; then
      echo "💾 Space freed: ${space_freed_gb}GB"
    elif [[ $space_freed_mb -gt 0 ]]; then
      echo "💾 Space freed: ${space_freed_mb}MB"
    else
      echo "💾 Space freed: ${space_freed}KB"
    fi
  else
    echo "💾 No significant space freed"
  fi

  echo ""
  echo "✨ Xcode cleanup complete!"
}
