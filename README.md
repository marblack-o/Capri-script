# Capri × Project UAI

Capri (Cyberpunk: Edgerunners 2) como compañera dentro de Roblox, usando **Project UAI** como cerebro y tools.

## Qué incluye

- **Sprite flotante** de Capri (arrastrable)
- **Chat rápido** estilo Capri: click en ella → se despliega el panel → hablas y te responde como Capri
- Personalidad completa (chaos gremlin, teasing, slang de Night City, leal, anti-corpo)
- Integración con **Project UAI** (tools del juego, agentes, etc.)
- Las **API keys se configuran después** de cargar el panel (no van en el código)

## Cómo usarlo

### 1. Sube esto a GitHub

Crea un repo público (ej. `capri-uai`) y sube la carpeta tal cual.

### 2. Cambia la URL del loader

Abre `loader.lua` y cambia esta línea:

```lua
local BASE = "https://raw.githubusercontent.com/TU_USUARIO/capri-uai/main/"
```

por tu usuario/repo real.

### 3. Ejecuta en Delta (o cualquier executor)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/TU_USUARIO/capri-uai/main/loader.lua"))()
```

### 4. Configura las keys

Una vez cargado:

1. Click en el círculo **C** (Capri)
2. Se abre el chat rápido
3. Configura providers / API keys desde la interfaz de Project UAI (si está disponible) o añade tu key cuando el sistema te lo pida

Las keys **no** van dentro del código del repo.

## Estructura

```
capri-uai/
├── loader.lua          ← lo que ejecutas con loadstring
├── README.md
└── src/
    └── host.lua        ← personalidad + UI + integración UAI
```

## Notas

- Si Project UAI no carga, Capri sigue funcionando con respuestas locales de personalidad.
- El panel es una versión ligera inspirada en el chat del APK de Capri Android.
- El sprite actual es un placeholder ("C"). Puedes cambiar la imagen por un asset de Capri si tienes uno.
- Compatible con Delta Executor y ejecutores que soporten `HttpGet` + `loadstring`.

## Créditos

- Capri © CD PROJEKT RED / Trigger (personaje de Cyberpunk: Edgerunners 2)
- Project UAI por Project-Ptolemy
- Este host es un proyecto fan no oficial
