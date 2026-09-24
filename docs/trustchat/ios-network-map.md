# TrustChat iOS — Mapa de rutas de red (IT-02)

**Código:** TRUSTCHAT-IOS-NETWORK-MAP  
**Versión:** 1.0  
**Fecha:** 25 de septiembre de 2026  
**Tarea:** IT-02 de `TRUSTCHAT-IOS-TASKS.md` v1.0 (Spec v1.2, Arquitectura v1.0)  
**Rama / commit analizado:** `mvp0` en `ff531115d` (código idéntico al baseline `f15d8bab0`)  
**Alcance:** todo camino por el que la app iOS, sus extensiones o el core Haskell enlazado obtienen un destino de red o abren una conexión. Las rutas y líneas citadas fueron leídas en este commit. Donde el camino entra en `simplexmq` (dependencia git, no incluida en el repo) se nombra el símbolo importado y se marca como **pendiente de verificar en simplexmq**.

> **Regla de lectura:** «Política MVP» es lo que exige la especificación para la demo; «Estado» es lo que hace el código hoy. Ninguna fila implica que algo esté implementado.

## 1. Hallazgos principales

1. **Swift no elige servidores.** Los servidores SMP/XFTP/NTF y los operadores vienen del core (`src/Simplex/Chat.hs` `defaultChatConfig`, `src/Simplex/Chat/Operators/Presets.hs`). Swift solo envía la configuración de transporte (`/_network`) y luego arranca el chat (`/_start`).
2. **El chat arranca antes de que el usuario elija operadores.** En el onboarding, `createProfile` llama a `apiCreateActiveUser` y `startChat(onboarding: true)` y recién después muestra el paso 3 de operadores (`apps/ios/Shared/Views/Onboarding/CreateProfile.swift:365-384`). El primer usuario recibe los presets del core (`Commands.hs` `chooseServers`, línea 429 en adelante).
3. **Lista vacía = presets aleatorios.** `useServerCfgs` (`src/Simplex/Chat/Library/Internal.hs:162-169`) devuelve servidores preset aleatorios de SimpleX cuando la lista de servidores habilitados queda vacía. Deshabilitar todos los operadores desde la UI no deja al agente sin servidores: le deja servidores de `simplex.im`.
4. **No se puede dejar XFTP sin servidores por API.** `validateUserServers` (`src/Simplex/Chat/Operators.hs:536-560`) rechaza con `USENoServers` cualquier configuración sin al menos un servidor XFTP habilitado y exige roles de almacenamiento y proxy. Quitar XFTP del todo requiere cambio en el core.
5. **Los servidores NTF están fijos en código** (`src/Simplex/Chat/Library/Commands.hs:147-152`, `ntf3`/`ntf4.simplex.im`) y no existe comando para cambiarlos. La app registra el token APNs en cada arranque si existe (`SimpleXAPI.swift:2275-2277`) y pide el registro APNs incondicionalmente al lanzar (`AppDelegate.swift:18`).
6. **Los presets se vuelven a fusionar en cada arranque** (`Chat.hs:285-307` `agentServers` → `updatedUserServers`, `Operators.hs:411-447`). Se conservan los flags `enabled` guardados, se re-añaden los presets nuevos y se descartan servidores custom cuyo host coincida con un preset.
7. **Ningún enlace entrante se valida contra el servidor autorizado.** `connectPlan` (`Commands.hs:4306-4488`) resuelve short links y nombres contra el servidor que nombra el enlace (`getShortLinkConnReq`, `resolveSimplexName`) salvo con `PRMNever`. Las invitaciones de grupo recibidas por protocolo (`Subscriber.hs`) se unen a colas en servidores elegidos por el par.
8. **Destinos fuera del core:** vistas previas de enlaces con `LPMetadataProvider` (HTTP directo desde el dispositivo), STUN/TURN de `simplex.im` con credenciales embebidas para llamadas, descubrimiento multicast de escritorio remoto al abrir la vista, y decenas de enlaces a `simplex.chat`/GitHub abiertos en el navegador del sistema.
9. **No hay `URLSession`, `URLRequest`, `NWConnection` ni `SFSafariViewController`** en el código iOS. No hay excepciones ATS. El único `WKWebView` carga HTML local (condiciones de uso).

## 2. Cadena de arranque y primera conexión

Camino normal (usuario existente):

| Paso | Capa | Función (archivo:línea) | Efecto de red |
|---|---|---|---|
| 1 | UI | `SimpleXApp.onAppear` → `initChatAndMigrate` (`apps/ios/Shared/SimpleXApp.swift:53-64`, `Shared/Model/SuspendChat.swift:118-139`) | Ninguno |
| 2 | Wrapper | `initializeChat` (`Shared/Model/SimpleXAPI.swift:2188-2230`): `chatMigrateInit`, `restartMonitor`, `apiSetAppFilePaths`, `getServerOperatorsSync`; importa `AppSettings` si hubo importación de archivo | Ninguno |
| 3 | FFI → core | `chat_migrate_init_key` (`SimpleXChat/API.swift:24-55`) → `chatMigrateInitKey` (`src/Simplex/Chat/Mobile.hs:307-318`) → `newChatController` (`src/Simplex/Chat.hs:152-171`) | `agentServers` carga presets + DB y llama a `getSMPAgentClient` (simplexmq). Crea el agente; **pendiente de verificar en simplexmq** si abre sockets aquí |
| 4 | Wrapper | `startChat` (`SimpleXAPI.swift:2259-2293`): `setNetworkConfig(getNetCfg())` → `apiGetNtfToken` → **`apiStartChat()`** → `registerToken` si hay token APNs → `ChatReceiver.start` | `/_network`, luego `/_start main=on snd_files=on`: suscripción a colas SMP existentes; registro en NTF si hay token |
| 5 | Core | `APISetNetworkConfig` → agente `setNetworkConfig` (`Commands.hs:1844`); `StartChat` → agente | Sockets TLS hacia los SMP de las colas y hacia NTF (simplexmq) |

Variantes que también arrancan el core y conectan sin pasar por ajustes:

| Variante | Función | Nota |
|---|---|---|
| Onboarding, primer perfil | `CreateFirstProfile.createProfile` (`Onboarding/CreateProfile.swift:365-384`) → `apiCreateActiveUser` → `startChat(onboarding: true)` | Antes del paso «elegir operadores». `CreateActiveUser.chooseServers` (`Commands.hs:429-457`) asigna los presets al primer usuario |
| Base de datos | `DatabaseView.startChat` (`Views/Database/DatabaseView.swift:428-462`) | Llama `apiStartChat()` directo, sin `setNetworkConfig` cuando la DB no cambió |
| Background refresh | `BGManager.receiveMessages` (`Shared/Model/BGManager.swift:112-149`) | `initializeChat(start: true)` + `activateChat` |
| Llamada entrante (PushKit) | `CallController` (`Views/Call/CallController.swift:242-256`) | `initializeChat(start: true)` + `startChatForCall` |
| Autenticación local / autodestrucción | `LocalAuthView` (`Views/LocalAuth/LocalAuthView.swift:33, 85-96`) | `initializeChat(start: true)` |
| NSE | `NotificationService.doStartChat` (`SimpleX NSE/NotificationService.swift:861-905`) | `chatMigrateInit(backgroundMode: true)`, `setNetworkConfig`, `/_start main=off`, luego `apiGetConnNtfMessages` contra SMP. Nota: `updateNetCfg` (`:1057-1068`) envía el valor viejo antes de asignar el nuevo |
| SE | `ShareModel.initChat` (`SimpleX SE/ShareModel.swift:174-196`) | **`apiStartChat()` antes de `apiSetNetworkConfig`** (línea 189 vs 192) |
| Migración | `startChatWithTemporaryDatabase` (`SimpleXAPI.swift:2295-2302`) | Controlador separado, `/_network` + `/_start` |

## 3. Tabla de fuentes de destino

Columnas: fuente de destino · función (archivo:línea) · capa que lo consume · política MVP (Spec v1.2 / IT-xx) · prueba · estado actual.

### 3.1. Servidores por defecto del core

| Fuente | Función | Capa | Política MVP | Prueba | Estado |
|---|---|---|---|---|---|
| Presets SMP SimpleX (11 habilitados `smp8…smp19.simplex.im`, 3 deshabilitados `smp4/5/6`, `smp7` en `allPresetServers`) | `Operators/Presets.hs:51-91`; `Chat.hs:83-107` (`useSMP = 4`) | Core → agente (`InitialAgentServers`) | Un único SMP TrustChat por IP/puerto/fingerprint; ningún preset (IT-06, D-02/D-05) | TC-01, TC-12 | Sin control |
| Presets SMP Flux (6, `smp1…6.simplexonflux.com`, rol proxy) | `Presets.hs:100-116`; `Chat.hs:96-103` (`useSMP = 3`) | Core → agente | Eliminar (IT-06) | TC-12, TC-13 | Sin control |
| Presets XFTP SimpleX (`defaultXFTPServers`, simplexmq) y Flux (6) | `Chat.hs:44, 90`; `Presets.hs:118-128` | Core → agente | XFTP fuera de alcance; deshabilitar por código (IT-12). Requiere core: `validateUserServers` exige ≥1 XFTP y `useServerCfgs` rellena con presets | TC-11, TC-12 | Sin control |
| Servidores NTF (`ntf3`, `ntf4.simplex.im`) | `Library/Commands.hs:147-152`; `Chat.hs:105` | Core → agente (`registerNtfToken`) | Sin push; no registrar token y quitar preset (IT-12) | TC-11, TC-12 | Sin control; sin comando runtime |
| Chat relays preset (`smp4/5/6.simplex.im/r#…`, `useChatRelays = 2`) | `Presets.hs:93-98`; `Chat.hs:91-92` | Core → agente al unirse a canales | Canales fuera de alcance; lista vacía (IT-12) | TC-11 | Sin control |
| Fallback a presets aleatorios con lista vacía | `Library/Internal.hs:162-169` `useServerCfgs`; `Chat.hs:282-284` `randomServerCfgs` | Core → agente | Eliminar el fallback o fallar cerrado (IT-06, ADR-05) | TC-01, TC-13 | Activo |
| Dominios preset para short links y puerto web 443 | `Chat.hs:111-112` (`shortLinkPresetServers`, `presetDomains`) | Core → agente | Sin dominios SimpleX (IT-06) | TC-07 | Sin control; uso interno **pendiente de verificar en simplexmq** |
| Operadores preset y condiciones (auto-aceptación tras plazo) | `Presets.hs:18-44`; `Store/Profiles.hs:787-844` `getUpdateServerOperators` | Core (DB) → UI | Sin operadores públicos; sin condiciones de terceros (IT-05/06) | TC-11 | Activo |
| Config de red por defecto del core | `Controller.hs:1255-1267` `defaultSimpleNetCfg` (`hostMode = HMOnionViaSocks`, sin SOCKS); `netCfg = defaultNetworkConfig` (simplexmq) | Core → agente | Fijar: sin SOCKS, sin onion, sin proxy privado (IT-06/12) | TC-13 | Valores de simplexmq **pendientes de verificar** |

### 3.2. Configuración en tiempo de ejecución (Swift → core)

| Fuente | Función | Capa | Política MVP | Prueba | Estado |
|---|---|---|---|---|---|
| Config de transporte desde App Group | `SimpleXChat/AppGroup.swift:360-407` `getNetCfg()` (defaults `:69-111`: onion `.no`, sesión `.session`, proxy SMP `.unknown`, fallback `.allowProtected`, puerto web `.preset`) | Wrapper → `/_network` (`SimpleXAPI.swift:885-889`) → `APISetNetworkConfig` (`Commands.hs:1844`) | Valores fijados en código: sin SOCKS, `hostMode` público, proxy SMP «nunca», sin fallback; no editable (IT-06/12). Constructores en simplexmq | TC-13 | Editable por UI |
| Ajustes avanzados de red | `Views/UserSettings/NetworkAndServers/AdvancedNetworkSettings.swift:27-343` (`saveNetCfg` → `setNetworkConfig` + `setNetCfg`) | UI → wrapper | Ocultar y deshabilitar (IT-05) | TC-11 | Activo |
| Lista de servidores por usuario | `SimpleXAPI.swift:803-825` `getUserServers`/`setUserServers`/`validateServers` → `APISetUserServers` (`Commands.hs:1748-1762`) → agente `setProtocolServers` | UI `NetworkAndServers.swift:33-180, 474-504` | Única fuente inmutable; sin alta, edición ni importación por el usuario (IT-06) | TC-06 | Activo |
| Operadores habilitados | `setServerOperators` (`SimpleXAPI.swift:782-801`) → `APISetServerOperators` (`Commands.hs:1715-1735`) | UI `OperatorView.swift:312-335`; onboarding `ChooseServerOperators.swift:148-182` | Ninguno habilitado; UI eliminada (IT-05) | TC-11 | Activo |
| Alta manual / QR de servidor / chat relay | `NewServerView.swift:118-160`, `ScanProtocolServer.swift:14-46`, `ChatRelayView.swift:53-80` | UI | Deshabilitar (IT-06) | TC-06 | Activo |
| Prueba de servidor arbitrario | `testProtoServer` (`SimpleXAPI.swift:761-771`) → `APITestProtoServer` → agente `testProtocolServer`; `testChatRelay` → `joinConnection` | UI `ProtocolServerView.swift:214-232`, `ProtocolServersView.swift:355-446` | Solo contra el SMP TrustChat, o eliminado (IT-06) | TC-06 | Conecta a cualquier servidor |
| Reconexión manual | `reconnectAllServers`/`reconnectServer` (`SimpleXAPI.swift:891-904`); pull-to-refresh `ChatListView.swift:244-255` | UI → agente | Sin cambio; solo reintenta el mismo destino (IT-06.6) | TC-10 | Activo |
| Monitor de red | `Shared/Model/NetworkObserver.swift:20-72` (`NWPathMonitor` → `apiSetNetworkInfo`) | Model → core | Sin cambio; no abre destinos | TC-14 | Activo |

### 3.3. Destinos que entran por usuario, enlaces o pares

| Fuente | Función | Capa | Política MVP | Prueba | Estado |
|---|---|---|---|---|---|
| Universal links y esquema `simplex:` | `SimpleXApp.swift:45-52` `.onOpenURL`; `ContentView.swift:307-313` `onContinueUserActivity`; `SimpleX--iOS--Info.plist:33-45`; entitlements `applinks:simplex.chat`, `*.simplex.im`, `*.simplexonflux.com` | UI → `connectViaUrl` (`ContentView.swift:449-482`) | Quitar dominios SimpleX; esquema propio; validador antes de red (IT-04/07) | TC-07 | Sin validación de host |
| Plan de conexión (QR, pegado, búsqueda, enlaces en mensajes) | `NewChatView.swift:1307-1655` `planAndConnect` → `apiConnectPlan` (`SimpleXAPI.swift:1035-1048`) → `connectPlan` (`Commands.hs:4306-4488`): `getShortLinkConnReq` (`Internal.hs:1568-1577`), `resolveSimplexName` | UI → core → agente (`getConnShortLink`, `joinConnection`) | Validador central que acepte solo la identidad del SMP TrustChat **antes** de resolver o abrir socket; rechazar short links y nombres (IT-07) | TC-07 | Resuelve contra el servidor del enlace salvo `PRMNever` |
| Pegado en búsqueda de la lista de chats | `ChatListView.swift:709-760` (`connect` inmediato al pegar un enlace) | UI | Mismo validador (IT-07) | TC-07 | Conecta sin confirmación |
| Pegado y escáner en «Nuevo chat» | `NewChatView.swift:646-702, 736-816` | UI | Mismo validador (IT-07) | TC-07 | Sin validación |
| Enlaces SimpleX dentro de mensajes | `Chat/ChatItem/MsgContentView.swift:195-225` → `appOpenUrl` / `planAndConnect` | UI | Mismo validador (IT-07) | TC-07 | Sin validación |
| Conexión con contacto ya preparado / por dirección | `apiConnectPreparedContact`, `apiConnectContactViaAddress` (`SimpleXAPI.swift:1197-1249`) → `Commands.hs:2199-2243, 2379-2392` | UI → core | Mismo validador (IT-07) | TC-07 | Sin validación |
| Invitaciones y reenvíos de grupo recibidos por protocolo | `Library/Subscriber.hs:2644-2667` (`processGroupInvitation`), `:3254-3288` (`xGrpMemFwd`), `:3779-3856` (`xGrpDirectInv`), `:804-809` (`XGrpRelayAcpt`) → `joinAgentConnectionAsync` (`Internal.hs:2867-2872`) | Core → agente | Grupos fuera de alcance; no unirse a colas en servidores ajenos (IT-07/12) | TC-07, TC-11 | Se une a servidores elegidos por el par |
| Dirección propia en servidor explícito | `APICreateMyAddress userId server_` (`Commands.hs:2402-2422`) | Core | Solo SMP TrustChat (IT-06) | TC-01 | Acepta cualquier servidor |
| Contactos con colas en servidores ajenos (DB previa) | `apiContactInfo` → `ConnectionStats.rcvQueuesInfo/sndQueuesInfo` (`ChatInfoView.swift:40-51, 262-263`); `apiSwitchContact` (`SimpleXAPI.swift:950`) | UI → core | Detener y marcar «requiere migración»; no borrar (IT-07.5) | TC-07 | Reconecta a los servidores guardados |
| Importar archivo de chat | `DatabaseView.importArchive` (`Views/Database/DatabaseView.swift:488-527`) + `shouldImportAppSettingsDefault` → `AppSettings.importIntoApp` (`Views/UserSettings/AppSettings.swift:14-70`, escribe `setNetCfg`) | UI → wrapper | Deshabilitar en MVP, o reimponer política tras importar (IT-07.5) | TC-07 | Restaura config de red del archivo |
| Migración entre dispositivos | `Views/Migration/MigrateFromDevice.swift:515-569` (sube a XFTP), `MigrateToDevice.swift:471-536` (descarga por enlace `https://simplex.chat/file`) | UI → core XFTP | Deshabilitar (IT-12) | TC-11 | Activo |
| Contacto preset «SimpleX Chat team» y enlaces de equipo/crowdfunding/directorio | `Internal.hs:3225-3248` `adminContactReq` (`smp6.simplex.im`), `Commands.hs:442-444` `createPresetContactCards`; `SettingsView.swift:14` `simplexTeamURL`, `WhatsNewView.swift:832`, `Localizable.strings` (bot de directorio en `smp4.simplex.im`) | Core (DB) y UI → `appOpenUrl` | Eliminar (IT-05) | TC-11 | Activo |
| Nombres SimpleX (`@nombre`, dominios) | `resolveSimplexName` en `connectPlan` (`Commands.hs:4333`), `apiSetUserDomain`/`apiVerifyContactDomain` (`SimpleXAPI.swift:1382-1405`) | UI → core → agente | Fuera de alcance; deshabilitar (IT-12) | TC-11 | Activo |

### 3.4. Servicios fuera del alcance del MVP que abren conexiones

| Fuente | Función | Capa | Política MVP | Prueba | Estado |
|---|---|---|---|---|---|
| Registro APNs y token NTF | `AppDelegate.swift:18` `registerForRemoteNotifications` (incondicional); `SimpleXAPI.swift:675-759` `apiRegisterToken`/`registerToken`; `startChat:2275-2277`; onboarding `YourNetwork.swift:144-190` | App → core → agente `registerNtfToken` (NTF `simplex.im`) | Sin push: no pedir APNs ni registrar token; sin `aps-environment` (IT-12, D-09) | TC-11, TC-12 | Activo |
| NSE | `SimpleX NSE/NotificationService.swift:300-340, 403-487, 861-905` | Extensión → core → SMP | Sin push ⇒ NSE sin función; decidir si se compila (IT-04.5) | TC-11 | Compila y arranca el core |
| SE | `SimpleX SE/ShareModel.swift:174-196, 468` (arranca core; vista previa de enlaces) | Extensión → core | Decidir si se compila (IT-04.5); sin previews | TC-11 | Compila y arranca el core |
| XFTP envío/recepción | `SimpleXAPI.swift:1553-1721` (`receiveFile` con `approved_relays = userApproved || !privacyAskToApproveRelays`, auto-recepción `:2538`); core `Internal.hs:753-794` `receiveViaCompleteFD` (servidores desconocidos requieren aprobación salvo `ipAddressProtected`), `:826-830` `receiveViaURI` siempre aprobado; `Commands.hs:257-261` `startXFTP` | UI → core → agente `xftpSendFile`/`xftpReceiveFile` | Deshabilitar envío, recepción y workers por código (IT-12) | TC-11, TC-12 | Activo; auto-recepción de imágenes |
| Vistas previas de enlaces | `SimpleXChat/ImageUtils.swift:436-470` `getLinkPreview` (`LPMetadataProvider`, HTTP directo); `ComposeView.swift:1866-1962`; `AppGroup.swift` `privacyLinkPreviews = true` por defecto; SE `ShareModel.swift:468` | UI (dispositivo, no core) | Deshabilitar por código y por defecto (IT-12.5) | TC-11, TC-12 | Activo por defecto |
| Llamadas WebRTC | `Views/Call/WebRTCClient.swift:86-90` `defaultIceServers` (`stuns:stun.simplex.im:443`, `turns:turn.simplex.im:443` con usuario y credencial embebidos); `WebRTC.swift:449-507`; señalización por SMP `SimpleXAPI.swift:1822-1868`; `CallController` PushKit | UI | Deshabilitar llamadas, CallKit y PushKit; quitar ICE (IT-12) | TC-11 | Activo |
| Escritorio remoto | `Views/RemoteAccess/ConnectDesktopView.swift:87-103` (`findKnownDesktop` multicast al abrir la vista); `SimpleXAPI.swift:1723-1763`; `Remote.hs:142-151, 400-471` (`rcConnectHost`, `rcDiscoverCtrl`) | UI → core → simplexmq | Deshabilitar; quitar entitlement multicast (IT-12) | TC-11 | Activo |
| Canales y relays | `ChatRelayView.swift`, `Commands.hs:1656-1695` `APITestChatRelay`, `:2244-2336` `connectToRelay` | UI → core | Fuera de alcance (IT-12) | TC-11 | Activo |
| Enlaces externos abiertos en navegador | `Views/Helpers/ShareSheet.swift:94-125` `openExternalLink` (confirmación, `UIApplication.shared.open`); `WhatsNewView.swift` (23 posts de blog), `SettingsView.swift:447-462`, `HowItWorks.swift:31`, `OperatorView.swift:398-611` (GitHub PRIVACY.md), `ProtocolServersView.swift:13`, `RTCServers.swift:11`, `NameBadge.swift:156`, `UserAddressView.swift:880, 919`, `VersionView.swift:23`, `GroupChatInfoView.swift:345-351` | UI → navegador del sistema | Eliminar enlaces a SimpleX/GitHub; ninguna apertura externa sin especificación (IT-05/12.5) | TC-11 | Activo |
| Condiciones de uso en `WKWebView` | `NetworkAndServers/ConditionsWebView.swift:13-80` (`loadHTMLString`, sin red) | UI | Eliminar con los operadores (IT-05) | TC-11 | HTML local |
| Reseña en App Store | `SettingsView.swift:458` `SKStoreReviewController` | SO | Fuera de control de TrustChat; documentar (IT-12 nota) | TC-12 | Activo |

## 4. Defaults de la app frente a defaults del core

| Ámbito | Valor | Dónde |
|---|---|---|
| Servidores y operadores | Presets SimpleX + Flux; se fusionan en cada arranque | Core: `Chat.hs:83-112`, `Operators.hs:397-447` |
| Config de red inicial del core | `defaultSimpleNetCfg` (`HMOnionViaSocks`, sin SOCKS) sobre `defaultNetworkConfig` de simplexmq | Core: `Controller.hs:1255-1267`, `Chat.hs:262`, `Commands.hs:366-372` |
| Config de red que realmente aplica la app | `getNetCfg()` desde App Group: onion `.no`, sesión `.session`, proxy `.unknown`, fallback `.allowProtected`, puerto web `.preset` | App: `AppGroup.swift:69-111, 360-407` |
| Defaults del struct `NetCfg` (no usados al arrancar) | sesión `.user`, proxy `.always` | App: `SimpleXChat/APITypes.swift:260-280` |
| `AppSettings` exportables/importables | `networkConfig`, `networkProxy`, `privacyLinkPreviews = true`, `webrtcICEServers = []`, `connectRemoteViaMulticast = true` | Core: `AppSettings.hs:77-113`; App: `AppSettings.swift:14-108` |
| ICE servers | Vacío en `AppSettings`; si vacío, `defaultIceServers` de `simplex.im` | App: `WebRTCClient.swift:93-94` |

## 5. Conexiones existentes frente a conexiones nuevas

- Los flags `enabled` de servidores y operadores solo afectan a **conexiones nuevas** (`Operators.hs:258-267`, `:312-321`). Las colas ya creadas conservan su servidor; `ConnectionStats` lo muestra por contacto (`ChatInfoView.swift:262-263`).
- Cambiar el servidor de una conexión existente requiere `apiSwitchContact` / `apiSwitchGroupMember` (`SimpleXAPI.swift:950`), que negocia con el par.
- Al restaurar una DB de otra instalación, el core reconecta a los servidores de las colas guardadas en el primer `/_start`, antes de cualquier ajuste. La política IT-07.5 debe aplicarse antes de ese arranque.

## 6. Puntos de enforcement por capa

| Capa | Qué se puede imponer ahí | Qué no |
|---|---|---|
| Swift (sin rebuild del core) | Orden de arranque: `setServerOperators`/`setUserServers` antes de `apiStartChat` en `startChat`, `createProfile`, `DatabaseView.startChat`, NSE y SE. No registrar APNs. Validador de enlaces antes de `planAndConnect`/`connectViaUrl`. Ocultar y bloquear UI de servidores, operadores, archivos, grupos, llamadas, escritorio remoto, previews, enlaces externos. Entitlements y esquemas | Quitar presets XFTP/NTF ni el fallback aleatorio; impedir que `connectPlan` resuelva contra un servidor ajeno si el validador se salta; controlar `joinConnection` de invitaciones recibidas por protocolo |
| Core `simplex-chat` (rebuild con Nix) | Reemplazar `Presets.hs`/`defaultChatConfig` por el único SMP TrustChat; eliminar `_defaultNtfServers`, chat relays, `presetDomains`; eliminar el fallback de `useServerCfgs`; relajar o cambiar `validateUserServers` para XFTP; validar host en `connectPlan` y en `Subscriber.hs`; eliminar `adminContactReq` | Handshake de transporte, selección de servidor para colas nuevas, resolución de short links, proxy privado |
| `simplexmq` (fork + rebuild) | Gate de autenticación de aplicación en el transporte (IT-10); valores de `defaultNetworkConfig`; restricción de host en `joinConnection`/`getConnShortLink`/`resolveSimplexName`; workers XFTP/NTF | — |

## 7. Pendiente de verificar en simplexmq

Sin el código fuente de `simplexmq` (tag `efaad8e7…`, `cabal.project:23-24`) no se puede afirmar:

1. Valores de `defaultNetworkConfig` (`smpProxyMode`, `smpProxyFallback`, `hostMode`, timeouts) y el constructor exacto que desactiva el proxy privado («never»).
2. Lista `defaultXFTPServers` de SimpleX (`Simplex.FileTransfer.Client.Presets`).
3. Si `getSMPAgentClient` o `xftpStartWorkers` abren sockets sin colas ni archivos pendientes.
4. Cómo el agente usa `presetDomains`, `presetServers`, `ServerCfg.enabled` y `roles` para elegir servidor de cola nueva y proxy.
5. Si `getConnShortLink`/`restoreShortLink` contactan por SMP o HTTPS, y si comprueban el host.
6. Si `joinConnection`/`prepareConnectionToJoin` restringen o enrutan por proxy hacia servidores nombrados en enlaces entrantes.
7. A qué se conecta `resolveSimplexName`.
8. Direcciones, grupo multicast y puertos de `rcConnectHost`/`rcDiscoverCtrl`.
9. Punto exacto del handshake SMP donde insertar la autenticación de aplicación (IT-03/IT-10).

## 8. Método

- Commit analizado: `ff531115d` (`mvp0`). Exploración con tres barridos (Swift, core Haskell, inventario de literales) y verificación manual de cada afirmación de las secciones 1, 2 y 3.1 leyendo los rangos citados.
- Sin cambios en el código. Sin ejecución de red.
- Inventario completo de literales (SMP/XFTP/NTF con hosts `.onion`, URLs de ayuda, ICE, entitlements) disponible en el mismo barrido; este documento lista solo los que tienen efecto operativo.
