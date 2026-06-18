# MC Hacking Workshop

We are writing a **Fabric mod** — a Java program that runs inside the Minecraft client and lets us intercept and modify the game's behaviour from within. The mod runs on your local machine. The server doesn't need to know about it.

---

## Setup

**Prerequisites:** Java 21, IntelliJ IDEA, Git

1. Clone the repo and open it in IntelliJ. Let Gradle finish importing (first run downloads Minecraft — takes a few minutes).

2. Generate Minecraft sources so you can browse them in the IDE:
   ```
   Gradle panel → Tasks → fabric → genSources
   ```
   After this, **Ctrl+Click** any Minecraft class or method to read its source. Essential for research.

3. Run the client: select **`Minecraft Client`** in the Run/Debug dropdown and press Run.

---

## How it works

Open `src/client/java/com/example/client/ExampleModClient.java`:

```java
public class ExampleModClient implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        // runs once at startup
    }
}
```

Fabric reads `fabric.mod.json` and calls this class at startup. `onInitializeClient()` is where you **register listeners** — you tell Fabric *"when X happens, call my code"*. The actual code runs later when X occurs.

```
onInitializeClient()          ← runs ONCE at startup
    └── event.register(...)   ← "when X happens, run this"
            └── your lambda   ← runs LATER, whenever X happens
```

The core research skill is finding the right event. The workflow:

1. Describe what you want: *"do something when the player joins a world"*
2. Browse the [Fabric API source](https://github.com/FabricMC/fabric-api/tree/1.21.11) or [docs](https://docs.fabricmc.net/develop/events)
3. Find the event, read its Javadoc to confirm the callback signature
4. Register a listener

When no Fabric event covers what you need, use a **Mixin** to inject code directly into any Minecraft method. → [Mixin intro](https://fabricmc.net/wiki/tutorial:mixin_introduction)

---

## Part 1 — Message on join

**Goal:** Display a message in chat when the player joins a world.

**Hook:** `ClientPlayConnectionEvents.JOIN` — fires when the client connects to a server or loads singleplayer. Found by searching the networking events module for join-related events. [Source](https://github.com/FabricMC/fabric-api/blob/1.21.11/fabric-networking-api-v1/src/client/java/net/fabricmc/fabric/api/client/networking/v1/ClientPlayConnectionEvents.java)

```java
ClientPlayConnectionEvents.JOIN.register((handler, sender, client) -> {
    client.player.displayClientMessage(
        Component.literal("Velkommen til MC Hacking! 🎉"),
        false // false = chat, true = action bar
    );
});
```

Build (`Ctrl+F9`), run, load a world. The message appears in chat.

**How to find `displayClientMessage`:** Ctrl+Click `client.player` → opens `LocalPlayer` in the decompiled source → browse available methods.

---

## Part 2 — Keybinding

**Goal:** Press a key to send a chat message.

**Hooks:** Two parts — register the key once, poll for presses every tick. → [Key Mappings tutorial](https://docs.fabricmc.net/develop/key-mappings)

```java
// Register once at startup
var myKey = KeyBindingHelper.registerKeyBinding(new KeyMapping(
    "key.examplemod.send_message",
    InputConstants.Type.KEYSYM,
    GLFW.GLFW_KEY_R,
    category
));

// Poll every tick
ClientTickEvents.END_CLIENT_TICK.register(client -> {
    if (client.player == null) return;
    while (myKey.consumeClick()) {
        client.player.displayClientMessage(Component.literal("Hack the planet!"), false);
        // client.getConnection().sendChat("visible to everyone");
    }
});
```

`consumeClick()` — true once per press (drains queue).  
`isDown()` — true every tick while held.

---

## Reference

### Docs

| Resource | URL |
|---|---|
| Fabric Docs | https://docs.fabricmc.net/develop/ |
| Events | https://docs.fabricmc.net/develop/events |
| Key Mappings | https://docs.fabricmc.net/develop/key-mappings |
| Mixin intro | https://fabricmc.net/wiki/tutorial:mixin_introduction |
| SpongePowered Mixin wiki | https://github.com/SpongePowered/Mixin/wiki |

### Fabric API source (1.21.11)

| Class | Link |
|---|---|
| `ClientPlayConnectionEvents` | [GitHub](https://github.com/FabricMC/fabric-api/blob/1.21.11/fabric-networking-api-v1/src/client/java/net/fabricmc/fabric/api/client/networking/v1/ClientPlayConnectionEvents.java) |
| `ClientTickEvents` | [GitHub](https://github.com/FabricMC/fabric-api/blob/1.21.11/fabric-lifecycle-events-v1/src/client/java/net/fabricmc/fabric/api/client/event/lifecycle/v1/ClientTickEvents.java) |
| `KeyBindingHelper` | [GitHub](https://github.com/FabricMC/fabric-api/blob/1.21.11/fabric-key-binding-api-v1/src/client/java/net/fabricmc/fabric/api/client/keybinding/v1/KeyBindingHelper.java) |
| Full fabric-api (1.21.11) | [GitHub](https://github.com/FabricMC/fabric-api/tree/1.21.11) |

### Useful APIs

| | |
|---|---|
| `client.player.displayClientMessage(Component, bool)` | Show text locally |
| `client.getConnection().sendChat(String)` | Send to server chat |
| `client.setCameraEntity(Entity)` | Move the camera to any entity |
| `player.setDeltaMovement(x, y, z)` | Set player velocity |
| `player.getDeltaMovement()` | Get current velocity |
| `Component.literal(String)` | Plain text component |

### Mappings

Run `./gradlew genSources`, then use **Ctrl+N** in IntelliJ to browse all decompiled Minecraft classes. This is the fastest way to discover what's available.

| | |
|---|---|
| Mojang mappings | bundled — used by default in this project |
| Yarn mappings | https://github.com/FabricMC/yarn/tree/1.21.11 |
| Minecraft Wiki | https://minecraft.wiki |
