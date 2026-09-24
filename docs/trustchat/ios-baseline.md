# TrustChat iOS — Baseline técnico (IT-01)

**Código:** TRUSTCHAT-IOS-BASELINE  
**Versión:** 1.0  
**Fecha:** 25 de septiembre de 2026  
**Tarea:** IT-01 de `TRUSTCHAT-IOS-TASKS.md` v1.0 (Spec v1.2)  
**Rama de trabajo:** `mvp0`  
**Alcance:** estado verificado del fork antes de cualquier cambio de marca, red o seguridad. Todo lo que figura aquí fue comprobado con los comandos de la sección 8 sobre esta máquina; nada se infiere de la documentación upstream.

## 1. Repositorio

| Campo | Valor |
|---|---|
| Ruta local | `/Users/links/git/trustchat-ios` |
| `origin` | `https://github.com/gleotta/trustchat-ios.git` |
| `upstream` | `https://github.com/simplex-chat/simplex-chat.git` |
| Rama de demo | `mvp0`, creada desde `main` en `f15d8bab0` |
| Commit de código baseline | `f15d8bab09cf32555a59e5463d0e6d1af32c19bf` («First change») |
| Commit validado en `README.trustchat.md` | `683fd675550c9a29b2b8c94c475c81007ac06a2b` (upstream, «scripts: re-init submodules in reproduce builds») |
| Diferencia entre ambos | Solo `README.trustchat.md` (nuevo) y una línea quitada en `SimpleX SE.xcscheme`. Sin cambios en código, core ni proyecto. El baseline validado sigue vigente. |
| Tag upstream más cercano | `v7.0.2` (`git describe`: `v7.0.2-4-g…`) |
| Submódulos | `apps/multiplatform/external/nanohttpd/upstream` en `efb2ebf8` (solo desktop; no interviene en iOS) |

Regla del sprint: no hacer merge ni rebase de `upstream` en `mvp0` ni en `main` hasta después de la demo del 27/09.

## 2. Herramientas

| Herramienta | Versión verificada |
|---|---|
| macOS | 15.7.9 (24G830), Mac Intel `x86_64` |
| Xcode | 26.3 (17C529), `/Applications/Xcode.app/Contents/Developer` |
| Nix | 2.35.2, con `nix-command flakes` habilitado por línea de comandos |
| GHC del core | 9.6.3 (según nombre de biblioteca `-ghc9.6.3.a`) |
| `mac2ios` | `$HOME/.local/bin/mac2ios`, sha256 `5275ef65e5faa2e161ca4c4fa5e091917ffb482572d1734662fc48657b7f8d54` |
| Simuladores disponibles | iPhone 17, 17 Pro, 17 Pro Max, Air, 16e (iOS 26.3.1) |

## 3. Proyecto Xcode

| Campo | Valor |
|---|---|
| Proyecto | `apps/ios/SimpleX.xcodeproj` (sin workspace) |
| Targets | `SimpleX (iOS)`, `SimpleXChat` (framework), `SimpleX NSE`, `SimpleX SE`, `Tests iOS` |
| Schemes compartidos | `SimpleX (iOS)`, `SimpleX NSE`, `SimpleX SE`, `SimpleXChat` |
| Configuraciones | Debug, Release; ambas incluyen `Local.xcconfig` opcional (gitignored) |
| Deployment target | iOS 15.0 |
| Swift | 5.0 |
| Versión | `MARKETING_VERSION = 7.0.2`, `CURRENT_PROJECT_VERSION = 351` (upstream) |
| Paquetes SPM | CodeScanner 2.5.0, Yams 5.1.2, LZString, WebRTC (fork simplex-chat), ElegantEmojiPicker, SwiftyGif, Ink 0.6.0 |
| Firma | `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = 5NN7GUYB6T` (equipo upstream de SimpleX), identidad `Apple Development` |

### 3.1. Identidad heredada de upstream (a reemplazar en IT-04)

| Elemento | Valor actual |
|---|---|
| Bundle ID app | `chat.simplex.app` |
| Bundle ID NSE / SE | `chat.simplex.app.SimpleX-NSE`, `chat.simplex.app.SimpleX-SE` |
| Bundle ID framework / tests | `chat.simplex.SimpleXChat`, `chat.simplex.Tests-iOS` |
| App Group (3 targets) | `group.chat.simplex.app` |
| Keychain group (3 targets) | `$(AppIdentifierPrefix)chat.simplex.app` |
| Entitlements de la app | `aps-environment = development`, associated domains `simplex.chat`, `*.simplex.im`, `*.simplexonflux.com`, multicast, user-assigned device name |
| Entitlement NSE | `com.apple.developer.usernotifications.filtering` |
| Nombre visible | «SimpleX» (app), «SimpleX NSE», «SimpleX SE» |
| Cadenas «TrustChat» en `apps/ios` y `src` | Ninguna |

## 4. Core nativo enlazado

| Campo | Valor |
|---|---|
| Paquete Haskell | `simplex-chat` 7.0.0.12 (`simplex-chat.cabal`) |
| `simplexmq` | git `https://github.com/simplex-chat/simplexmq.git` tag `efaad8e73436d60f5052f07dda6b71151ad5039b` (`cabal.project`); hash Nix en `scripts/nix/sha256map.nix` |
| Output Nix | `.#x86_64-darwin-ios:lib:simplex-chat` (flags `swift`, `client_library`, `commoncrypto`) |
| Store path | `/nix/store/azzc2gh7kr6k3mlpi04ayihszp2vszic-simplex-chat-lib-simplex-chat-7.0.0.12` (enlace `result-ios-sim`) |
| Paquete | `pkg-ios-x86_64-swift-json.zip`, sha256 `3a40605c640200aaaf1ce88a358539591eb8feeb9b449f0d28c4d74dbb5212b2` |
| Directorio enlazado por Xcode | `apps/ios/Libraries/sim` (`LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]`); `Libraries/ios` para dispositivo, **inexistente** en este baseline |
| Arquitectura | `x86_64` (non-fat) |
| Plataforma en los objetos | `LC_VERSION_MIN_IPHONEOS 10.12` en todos los `.a` (ver 4.2) |

### 4.1. Bibliotecas en `apps/ios/Libraries/sim`

| Archivo | sha256 |
|---|---|
| `libHSsimplex-chat-7.0.0.12-4ehbYDRAXlKGgyS4p1jhJT.a` | `ba781a266e7dffe80cc5d6e51f223b3ac5b4f39c186867e88a83639ef173d1a3` |
| `libHSsimplex-chat-7.0.0.12-4ehbYDRAXlKGgyS4p1jhJT-ghc9.6.3.a` | `ae3c372429011047f402c92f521d6fd07815df5f285e80f02c58f482c2173f26` |
| `libffi.a` | `42102ec154a45c234ba031ea96b5899a7946fff50180842b1b8ba3821f76b47e` |
| `libgmp.a` | `a41a0bbc4ccb79b9e9d913f5b3a800c205d5b1dbc25d4ec89d30c3c18da07a3a` |
| `libgmpxx.a` | `4e391e142b72269f320134536705a01d0439cbcc189673ec1f011098be219a76` |

Las cinco bibliotecas son **byte a byte idénticas** al contenido de `pkg-ios-x86_64-swift-json.zip` del store de Nix. `project.pbxproj` referencia exactamente estos nombres (grupo `Libraries`, 4 + 4 líneas para las dos variantes de `libHSsimplex-chat`).

### 4.2. Hallazgo: `mac2ios -s` no modifica estas bibliotecas

`flake.nix` (`iosPostInstall`) ya ejecuta `mac2ios` sobre cada `.a` durante el build de Nix, reescribiendo `LC_VERSION_MIN_MACOSX` a `LC_VERSION_MIN_IPHONEOS`. Ejecutar después `mac2ios -s` (paso 6 de `README.trustchat.md`) sobre una copia no cambia el hash ni la plataforma: los objetos quedan marcados como iPhoneOS, no como iPhoneSimulator, y así se enlazan en el build de simulador. Ver sección 5 para el comportamiento del linker. Consecuencia: el paso manual es inocuo pero no hace lo que el README describe; para dispositivo físico las bibliotecas de `Libraries/ios` deberán validarse aparte.

## 5. Compilación baseline

| Campo | Valor |
|---|---|
| Comando | `xcodebuild build -project apps/ios/SimpleX.xcodeproj -scheme "SimpleX (iOS)" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17'` |
| Rama / commit | `mvp0` en `e2e2c7395` (código idéntico a `f15d8bab0`; solo se añadió `CLAUDE.md`) |
| Resultado | `** BUILD SUCCEEDED **`, exit 0 |
| Errores | 0 |
| Warnings del compilador | 0 |
| Warnings del linker por plataforma | Ninguno. `ld` no emitió «building for iOS Simulator, but linking in object file built for iOS» pese a que los objetos de los `.a` llevan `LC_VERSION_MIN_IPHONEOS` (sección 4.2). |
| Targets compilados | `SimpleXChat`, `SimpleX NSE`, `SimpleX SE`, `SimpleX (iOS)` y los siete paquetes SPM |
| Nota | El build phase `Run Script` (`scripts/ios/copy-assets.sh`) corre en cada build y sale de inmediato porque `SIMPLEX_ASSETS` no está definido. |
| Log | Guardado fuera del repositorio; contiene rutas locales de DerivedData, sin datos de usuario. |

### 5.1. Arranque limpio

| Campo | Valor |
|---|---|
| Simulador dedicado | «TrustChat mvp0 A», iPhone 17, iOS 26.3, UDID `5D81D329-2275-4F81-A3A9-F9E90BD9440F`, creado nuevo con `simctl create` (sin datos previos) |
| Instalación | `xcrun simctl install <UDID> …/Debug-iphonesimulator/SimpleX.app` |
| Primer lanzamiento | `xcrun simctl launch <UDID> chat.simplex.app`. A los 10 s la app seguía en «Opening app…» (inicialización del runtime Haskell y creación de la base en el primer arranque, build Debug). Proceso vivo. |
| Segundo lanzamiento | Pantalla de onboarding upstream («Be free in your network», botón «Get started») visible a los 20 s. Proceso vivo a los 20, 40 y 60 s. |
| Estado dejado | No se creó perfil ni conexión. Simulador apagado con `simctl shutdown`; el dispositivo queda disponible para IT-11. |
| Evidencia | Capturas `mvp0-baseline-first-launch.png`, `mvp0-baseline-launch-{20,40,60}s.png` (sin datos de usuario), guardadas fuera del repositorio junto al log. |

## 6. Verificación del binario nativo

El core Haskell se enlaza estáticamente en el framework `SimpleXChat`, no en el ejecutable de la app. La app, la NSE y la SE cargan ese framework.

| Comprobación | Evidencia |
|---|---|
| Único paso de link que usa el core | `Ld …/Debug-iphonesimulator/SimpleXChat.framework/SimpleXChat` con `-L/Users/links/git/trustchat-ios/apps/ios/Libraries/sim -lHSsimplex-chat-7.0.0.12-4ehbYDRAXlKGgyS4p1jhJT -lHSsimplex-chat-7.0.0.12-4ehbYDRAXlKGgyS4p1jhJT-ghc9.6.3` |
| Bibliotecas enlazadas = output de Nix | Hashes de la sección 4.1 idénticos a los del zip del store |
| Símbolos FFI exportados por el framework | `_chat_migrate_init_key`, `_chat_send_cmd_retry`, `_chat_recv_msg_wait`, `_chat_parse_server` presentes (`nm -gU`) |
| Versión del core embebida | La cadena `7.0.0.12` aparece en el binario del framework |
| Plataforma del producto | `LC_BUILD_VERSION platform 7` (iOS Simulator), `minos 15.0`, `x86_64`, tanto en `SimpleXChat` como en `SimpleX.app/SimpleX` |
| sha256 `SimpleXChat.framework/SimpleXChat` (Debug) | `d02b72e4e42d127fd3b8d9797949f52b184a564067998b8dc3ee6b4fbe07e6fa` |
| sha256 `SimpleX.app/SimpleX` (Debug) | `f0dc3a9cc29388831476566aeaf9c7cb18adee2dcd090f3d0c8abbcdb4fe834c` |

Los hashes de los productos Debug cambian con cada compilación (rutas, timestamps); sirven para identificar este build concreto, no para reproducibilidad.

## 7. Limitaciones del baseline

- Solo simulador Intel. No hay bibliotecas `arm64` para iPhoneOS ni build de dispositivo validado.
- Identidad, firma y entitlements son los de upstream; la cuenta Apple Developer de TrustChat no está configurada.
- El core enlazado es upstream sin modificaciones; cualquier cambio en `src/` o `simplexmq` exige rebuild con Nix y repetir las secciones 4 a 6.
- La app conserva servidores preset de SimpleX (`src/Simplex/Chat/Operators/Presets.hs`) y dominios asociados de SimpleX en entitlements.

## 8. Comandos ejecutados

```bash
git status --short --branch && git rev-parse HEAD && git describe --tags
git remote -v && git submodule status --recursive
git diff --stat 683fd6755 f15d8bab0
xcodebuild -version && xcode-select -p && nix --version && sw_vers
xcodebuild -list -project apps/ios/SimpleX.xcodeproj
plutil -lint apps/ios/SimpleX.xcodeproj/project.pbxproj
grep -oE 'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;' apps/ios/SimpleX.xcodeproj/project.pbxproj | sort -u
plutil -p "apps/ios/SimpleX (iOS).entitlements"
readlink result-ios-sim && ls result-ios-sim
shasum -a 256 apps/ios/Libraries/sim/*.a result-ios-sim/pkg-ios-x86_64-swift-json.zip "$HOME/.local/bin/mac2ios"
unzip -oq result-ios-sim/pkg-ios-x86_64-swift-json.zip -d <tmp> && shasum -a 256 <tmp>/*.a
lipo -info apps/ios/Libraries/sim/libHSsimplex-chat-7.0.0.12-4ehbYDRAXlKGgyS4p1jhJT.a
ar x <lib.a> <obj.o> && otool -l <obj.o> | grep -A2 LC_VERSION_MIN
xcodebuild build -project apps/ios/SimpleX.xcodeproj -scheme "SimpleX (iOS)" \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17'
```
