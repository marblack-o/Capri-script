# Capri-script

Asistente **dentro de Roblox** inspirado en Capri (Project Capricorn / *Cyberpunk: Edgerunners*), pensado para charlar y lanzar misiones sobre **el juego en el que estás ahora** (este DataModel).

No es la app de escritorio ni un cliente Android: es un **script de executor** (Delta u otro con `HttpGet` + `loadstring`) que combina:

- **Capri** → personalidad, chat rápido y animaciones ligeras  
- **Groq** → la voz del chat (API key tuya, local)  
- **Project UAI** → herramientas para leer/modificar el juego en misiones (`!...`)

Proyecto **fan, no oficial y open source**: cualquiera puede usarlo, copiarlo, mejorarlo o adaptarlo. No busca ser exclusivo; si se puede mejorar, bienvenido.

---

## Qué hace

| Modo | Comportamiento |
|------|----------------|
| **Chat libre** | Click en Capri → panel → hablas; responde con personalidad (Groq). |
| **Misión** | Mensajes que empiezan con `!` (ej. `!analiza el juego`). Capri aclara solo si hace falta y manda el trabajo a **Project UAI** sobre **este** place. |
| **UI** | Sprite arrastrable, caras por estado (idle / talk / misión / done / error), bob y cut-ins simples. |

- Las misiones entienden que *“el juego”* = la sesión actual de Roblox.  
- En pedidos con panel/UI, el prompt a UAI incluye una spec básica de interfaz.  
- La key de Groq **no va en el repo**: se pide al primer uso y se guarda en el executor (`capri_config.json`).

---

## Requisitos

1. **Executor de Roblox** con al menos:
   - `HttpGet` / `loadstring`
   - Ideal: `writefile` / `readfile` / `isfile` (guardar key y assets)
   - Ideal: `getcustomasset` (sprites locales)
2. **API key de Groq** (tier gratis en [console.groq.com](https://console.groq.com))
3. Para **misiones `!`**: [Project UAI](https://github.com/Project-Ptolemy/ProjectUAI) operativo en el mismo executor
   - Primera vez: setup de storage / password (*Continue without encryption* o vault)
   - Un **provider** configurado en UAI (modelo con tools)

Sin UAI, el **chat de Capri** puede seguir funcionando; las misiones de juego no.

---

## Cómo ejecutarlo

En el executor (partida / place):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/marblack-o/Capri-script/main/loader-allinone.lua"))()
```

1. Si no hay key guardada, aparece el panel **Capri — Setup** → pegas la key de Groq → Continuar.  
2. Click en Capri → chat.  
3. Charla normal, o misión:

```text
!analiza el juego
!lista scripts importantes
!crea un panel de stats del jugador
```

Capri espera a que UAI **termine el turno** (no solo el primer borrador de texto).

---

## Estructura del repo

```text
Capri-script/
├── loader-allinone.lua   ← lo que ejecutas (carga el core)
├── README.md
├── assets/               ← caras / cut-ins (PNG)
└── src/
    ├── capri_part1.lua     ← core partido (se concatena en runtime)
    ├── capri_part2.lua
    └── capri_part3.lua
```

Forkea, cambia URLs si usas otro usuario/repo, y adapta a gusto.

---

## Inspiración y créditos

- **Capri / Project Capricorn** — personaje de *Cyberpunk: Edgerunners* (CD PROJEKT RED, Studio Trigger, Netflix). Este script es un **proyecto fan no oficial**, sin afiliación.
- **[capri-desktop](https://github.com/mochiiwuff/capri-desktop)** (mochiiwuff) — compañera de escritorio que narra agentes de código; de ahí la idea de Capri como presencia + chat + “misión”. Su código tiene licencia propia (PolyForm Noncommercial); el artwork del personaje no es software libre.
- Puertos / builds comunitarias tipo Capri Android — referencia de panel de chat rápido.
- **[Project UAI](https://github.com/Project-Ptolemy/ProjectUAI)** (Project-Ptolemy) — agente con tools dentro de Roblox.

Capri-script solo reutiliza la **idea de experiencia** y assets que tú subas a este repo; respeta siempre los derechos del personaje y las licencias de cada proyecto.

---

## Open source

- Puedes **usar, modificar, forkar y redistribuir** este host.
- Las mejoras de la comunidad son bienvenidas (issues / PR / forks).
- **No subas API keys** al repo.
- Posible publicación futura en directorios tipo ScriptBlox cuando esté más estable; el código seguirá siendo abierto aquí.

---

## Limitaciones honestas

- Solo funciona con **executor** (no es un LocalScript de juego publicado por el creador del place).
- Depende de Groq (chat) y, para misiones, de UAI + provider.
- Las animaciones son ligeras (cambio de frames + tweens), no el motor WebGL de capri-desktop.
- UAI puede pedir setup la primera vez; sin provider las misiones fallan con mensaje orientativo.

---

## Licencia / uso

Fan project de código abierto orientado a uso personal y aprendizaje.  
El personaje Capri y la franquicia Cyberpunk pertenecen a sus titulares.  
Project UAI y capri-desktop tienen sus propios términos: cúmplelos si los usas junto a este script.
