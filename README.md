# UCH Load Optimization Plugins

A collection of performance and optimization plugins for *Ultimate Chicken Horse*, built with BepInEx 5 and Harmony.

Each plugin is maintained in its own directory. A shared root-level build script compiles individual plugins.

## Repository Structure

```text
UCHLoadOptimizationPlugins/
├── build.ps1
├── .gitignore
├── README.md
├── BeehiveFix/
│   ├── Source/
│   │   └── BeehiveFix.cs
│   └── build/
├── SnapshotFix/
│   ├── Source/
│   │   └── SnapshotFix.cs
│   └── build/
└── UCHListenerFix/
    ├── Source/
    │   └── UCHListenerFix.cs
    └── build/
```

## Requirements

- Windows
- PowerShell 5.1 or later
- A compatible C# compiler (`csc.exe`)
- Ultimate Chicken Horse game assemblies
- BepInEx 5 and Harmony reference assemblies

The game and BepInEx assemblies are not included in this repository. You must have access to the required DLLs locally to compile the plugins.

## Building a Plugin

Run commands from the repository root.

Build BeehiveFix:

```powershell
.\build.ps1 -Mod BeehiveFix
```

Build SnapshotFix:

```powershell
.\build.ps1 -Mod SnapshotFix
```

Build UCHListenerFix:

```powershell
.\build.ps1 -Mod UCHListenerFix
```

## Custom Game Installation

If the game is installed in a non-default Steam library, specify its path:

```powershell
.\build.ps1 `
  -Mod BeehiveFix `
  -GamePath "D:\SteamLibrary\steamapps\common\Ultimate Chicken Horse"
```

The script can also support separate paths for the game's Managed assemblies, BepInEx core assemblies, and C# compiler if automatic detection fails.

## Installing a Plugin

If supported by the build script, you can build and install a plugin in one command:

```powershell
.\build.ps1 `
  -Mod BeehiveFix `
  -GamePath "D:\SteamLibrary\steamapps\common\Ultimate Chicken Horse" `
  -Install
```

The DLL is copied to the selected game's `BepInEx/plugins` directory, inside a folder for that plugin.

Alternatively, build the plugin first and manually copy the resulting DLL into your BepInEx plugin directory.

## Adding a New Plugin

1. Create a new directory at the repository root.
2. Create a `Source` directory inside it.
3. Add your plugin's `.cs` source files.
4. Build it by passing the new directory name to `-Mod`.

For example:

```text
NewPlugin/
└── Source/
    └── NewPlugin.cs
```

```powershell
.\build.ps1 -Mod NewPlugin
```

The shared build script should automatically discover the new plugin's source files and create its output directory.
