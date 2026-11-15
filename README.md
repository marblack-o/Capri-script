# Capri-script (modular v7)

Asistente **dentro de Roblox** (executor) inspirado en Capri y conectado a **Project UAI**.

Open source: usa, modifica y mejora libremente. No subas API keys al repo.

## Ejecutar

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/marblack-o/Capri-script/main/loader-allinone.lua"))()
```

Requisitos: executor con `HttpGet`/`loadstring`; ideal `writefile`/`getcustomasset`.  
Chat Capri: **Groq key** (local). Hacks: **Project UAI** + provider.

## Estructura

```text
loader-allinone.lua   → bootstrap
src/
  Config.lua          → capri_config.json
  Theme.lua           → colores / UI helpers
  Assets.lua          → assets/ del repo
  UAIBridge.lua       → UAI ensure, providers, misiones, show()
  Visual.lua          → sprite cuerpo+cara, expresiones
  UI_Chat.lua         → workbench (chats, providers, archivos, atajos UAI)
  Hack.lua            → ventana hack + prompt
  App.lua             → orquestación
assets/               → PNG Capri
```

## Flujo

- Click en Capri → workbench centrado (borde **verde** chat / **amarillo** UAI).
- `!analiza el juego` → ventana hack (arrastrable, ✕) + UAI `request.await`.
- Providers: guardar key → `uai.providers.save` + `setActive` (fallback si Free offline).
- Atajos: UAI chat / providers / logs; pestaña Archivos.

## Inspiración

- [capri-desktop](https://github.com/mochiiwuff/capri-desktop) (mochiiwuff) — presencia y caras.
- [Project UAI](https://github.com/Project-Ptolemy/ProjectUAI) — agente y tools en Roblox.
- Capri © CDPR / Trigger / Netflix — fan project no oficial.
