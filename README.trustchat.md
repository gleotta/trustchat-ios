# TrustChat iOS

Cliente iOS privado de TrustChat, basado en el código de
[`simplex-chat/simplex-chat`](https://github.com/simplex-chat/simplex-chat).
La interfaz está desarrollada en Swift/SwiftUI y utiliza el core de SimpleX
compilado desde Haskell como bibliotecas estáticas para iOS.

Repositorio:
[`gleotta/trustchat-ios`](https://github.com/gleotta/trustchat-ios)

> **Estado actual:** el proyecto está compilado y probado en un Mac Intel con
> el simulador iOS. El build para iPhone físico, la firma definitiva y la
> distribución mediante Apple todavía deben validarse con una cuenta activa
> de Apple Developer.

## Alcance

Este repositorio contiene el cliente iOS. No contiene ni despliega:

- el servidor SMP de TrustChat;
- el servidor XFTP para transferencia de archivos;
- un backend de invitaciones o activación;
- infraestructura de notificaciones push;
- servicios de llamadas.

Cada componente tiene un ciclo de configuración, seguridad y despliegue
independiente.

## Arquitectura

```mermaid
flowchart LR
    UI["Swift / SwiftUI"] --> B["Bridge SimpleXChat"]
    B --> H["Core Haskell estático"]
    H -->|"SMP/TLS"| S["TrustChat SMP"]
    H -->|"Archivos"| X["Servidor XFTP"]
```

Las bibliotecas Haskell no se compilan dentro de Xcode. Primero se generan con
Nix, se preparan para la arquitectura de Apple correspondiente y se copian a
`apps/ios/Libraries/`. Xcode luego enlaza esos archivos `.a` con la aplicación
y sus extensiones.

## Baseline validado

| Componente | Estado probado |
|---|---|
| Repositorio | `https://github.com/gleotta/trustchat-ios` |
| Rama | `main` |
| Commit de referencia | `683fd675550c9a29b2b8c94c475c81007ac06a2b` |
| Equipo | MacBook Pro Intel, `x86_64` |
| macOS | `15.7.9` |
| Xcode | `26.3` |
| Nix | `2.35.2` |
| GHC utilizado por el core | `9.6.3` |
| Destino validado | iPhone Simulator sobre Mac Intel |
| Proyecto Xcode | `apps/ios/SimpleX.xcodeproj` |
| Scheme | `SimpleX (iOS)` |
| Resultado | La app abrió y pudo conectarse |

Los nombres de algunas bibliotecas del baseline contienen la versión
`simplex-chat-7.0.0.12`. Al actualizar el core, esos nombres pueden cambiar y
debe volver a ejecutarse `scripts/ios/update-pbxproj.sh`.

## Estructura relevante

```text
trustchat-ios/
├── apps/ios/
│   ├── SimpleX.xcodeproj/       Proyecto Xcode
│   ├── Shared/                  Código compartido de la aplicación
│   ├── SimpleX NSE/             Notification Service Extension
│   ├── SimpleX SE/              Share Extension
│   ├── Libraries/
│   │   ├── sim/                 Bibliotecas para iOS Simulator
│   │   └── ios/                 Bibliotecas para iPhone/iPad físico
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   └── *.entitlements
├── scripts/ios/
│   ├── prepare.sh
│   ├── prepare-x86_64.sh
│   ├── download-libs.sh
│   ├── copy-assets.sh
│   └── update-pbxproj.sh
├── cabal.project
└── flake.nix
```

Targets principales encontrados en el proyecto:

| Target/scheme | Función |
|---|---|
| `SimpleX (iOS)` | Aplicación iOS principal |
| `SimpleXChat` | Integración entre Swift y el core de SimpleX |
| `SimpleX NSE` | Procesamiento de notificaciones antes de mostrarlas |
| `SimpleX SE` | Compartir contenido hacia TrustChat desde otras apps |
| `Tests iOS` | Pruebas del cliente iOS |

La base actual usa iOS 15 o posterior y Swift 5. Antes de modificar esos
valores, verificar todos los targets y extensiones.

## Requisitos

- Mac con una versión compatible de macOS.
- Xcode `26.3` para reproducir exactamente el baseline probado.
- Xcode Command Line Tools.
- Git.
- Nix con soporte para `nix-command` y flakes.
- `mac2ios` disponible en `$HOME/.local/bin/mac2ios` para el procedimiento
  probado en simulador Intel.
- Espacio libre suficiente para el Nix store, dependencias Haskell, DerivedData
  y simuladores.
- Acceso al repositorio privado.

Para ejecutar solamente en simulador no hace falta una membresía paga de Apple
Developer. Para instalar correctamente en dispositivos de terceros, usar
TestFlight o publicar una versión Unlisted sí se necesita la membresía.

## Inicio rápido: simulador Intel

Este es el procedimiento que ya funcionó en el entorno de referencia.

Este bloque es específico para un Mac Intel. En Apple Silicon, el simulador
también utiliza `arm64` y requiere otro paquete/preparación; ese camino debe
validarse antes de incorporarlo como procedimiento oficial.

### 1. Clonar el repositorio

```bash
git clone https://github.com/gleotta/trustchat-ios.git
cd trustchat-ios
git checkout main
git submodule update --init --recursive
```

Comprobar el commit:

```bash
git rev-parse HEAD
```

Para reproducir exactamente el baseline, la salida debe ser:

```text
683fd675550c9a29b2b8c94c475c81007ac06a2b
```

Si se trabaja sobre un commit posterior, registrar explícitamente qué cambió y
volver a ejecutar la validación completa.

### 2. Verificar Xcode

```bash
xcodebuild -version
xcode-select -p
```

Si hay varias versiones de Xcode instaladas, seleccionar la correspondiente:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Abrir Xcode al menos una vez para completar la instalación de componentes y
aceptar la licencia.

### 3. Instalar o verificar Nix

La instalación multi-user recomendada por Nix para macOS se realiza con:

```bash
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh
```

Después de instalar, abrir una terminal nueva y verificar:

```bash
nix --version
```

El baseline probado utilizó:

```text
nix (Nix) 2.35.2
```

### 4. Verificar `mac2ios`

```bash
test -x "$HOME/.local/bin/mac2ios"
"$HOME/.local/bin/mac2ios" --help
```

Si ya se obtuvo el binario pero todavía no está instalado:

```bash
mkdir -p "$HOME/.local/bin"
install -m 755 /ruta/al/binario/mac2ios "$HOME/.local/bin/mac2ios"
export PATH="$HOME/.local/bin:$PATH"
```

`mac2ios` proviene del proyecto
[`zw3rk/mobile-core-tools`](https://github.com/zw3rk/mobile-core-tools), que
también está referenciado como input en `flake.nix`. No usar un binario de una
fuente no verificada.

### 5. Compilar el core Haskell para simulador `x86_64`

Desde la raíz del repositorio:

```bash
nix --extra-experimental-features "nix-command flakes" \
  build '.#x86_64-darwin-ios:lib:simplex-chat' \
  --no-update-lock-file \
  --out-link result-ios-sim \
  -L
```

Verificar el resultado:

```bash
test -f result-ios-sim/pkg-ios-x86_64-swift-json.zip
```

El primer build puede ser muy largo. Nix descargará o compilará el toolchain y
las dependencias necesarias; los siguientes builds pueden reutilizar el Nix
store.

El enlace `result-ios-sim` es un artefacto local. Para ignorarlo sin modificar
el `.gitignore` compartido:

```bash
grep -qxF '/result-ios-sim' .git/info/exclude 2>/dev/null \
  || printf '\n/result-ios-sim\n' >> .git/info/exclude
```

### 6. Preparar las bibliotecas para Xcode

```bash
mkdir -p apps/ios/Libraries/sim

unzip -o \
  result-ios-sim/pkg-ios-x86_64-swift-json.zip \
  -d apps/ios/Libraries/sim

chmod u+w apps/ios/Libraries/sim/*.a

for lib in apps/ios/Libraries/sim/*.a; do
  "$HOME/.local/bin/mac2ios" -s "$lib" > /dev/null
done
```

El parámetro `-s` prepara los archivos para el simulador Intel. No utilizarlo
para las bibliotecas de dispositivo físico.

Verificar que existan archivos estáticos:

```bash
find apps/ios/Libraries/sim -maxdepth 1 -type f -name '*.a' -print
```

### 7. Actualizar las referencias del proyecto Xcode

El siguiente comando ejecuta el script del repositorio utilizando el directorio
del simulador sin editar permanentemente la variable `LIB_DIR` del script:

```bash
sed 's|^LIB_DIR=.*|LIB_DIR=./apps/ios/Libraries/sim|' \
  scripts/ios/update-pbxproj.sh | sh
```

Validar que el archivo del proyecto siga siendo correcto:

```bash
plutil -lint apps/ios/SimpleX.xcodeproj/project.pbxproj
```

Resultado esperado:

```text
apps/ios/SimpleX.xcodeproj/project.pbxproj: OK
```

Revisar los cambios antes de continuar:

```bash
git diff -- apps/ios/SimpleX.xcodeproj/project.pbxproj
```

### 8. Abrir y ejecutar la aplicación

```bash
open apps/ios/SimpleX.xcodeproj
```

En Xcode:

1. Seleccionar el scheme **SimpleX (iOS)**.
2. Seleccionar un **iPhone Simulator** disponible.
3. Ejecutar con `⌘R`.
4. Confirmar que la app abre y permite crear o cargar un perfil.
5. Configurar el servidor SMP y ejecutar **Test server**.

No seleccionar **My Mac** ni un iPhone físico cuando solo están preparadas las
bibliotecas de `Libraries/sim`.

## Flujo cotidiano de desarrollo

### Cambios únicamente en Swift/SwiftUI

No es necesario recompilar Haskell para cada cambio Swift:

1. Abrir `apps/ios/SimpleX.xcodeproj`.
2. Modificar el código.
3. Compilar y ejecutar desde Xcode.

Xcode reutiliza DerivedData y las bibliotecas estáticas existentes.

### Cambios en Haskell o en dependencias del core

Repetir:

1. `nix build` para la arquitectura necesaria.
2. Extracción del ZIP.
3. Preparación con `mac2ios`.
4. `update-pbxproj.sh` si cambió algún nombre de biblioteca.
5. **Product → Clean Build Folder** en Xcode si quedaron referencias anteriores.
6. Build y pruebas completas.

Los archivos nuevos sin seguimiento pueden no formar parte de la fuente que
Nix utiliza para una flake. Revisar siempre:

```bash
git status --short
```

## Servidores prefijados de TrustChat (rama `mvp0`)

Desde IT-06 la app trae los servidores TrustChat en un archivo de configuración y
no depende de la carga manual descrita en la sección siguiente.

| Archivo | Contenido | En git |
|---|---|---|
| `apps/ios/Shared/TrustChat/TrustChatConfig.plist` | Host, puerto y fingerprint del SMP y del XFTP; flag `pushNotifications` | Sí |
| `apps/ios/Local.xcconfig` | `TRUSTCHAT_SMP_PASSWORD = <PASS>`; Xcode lo inyecta en `Info.plist` como `TrustChatSMPPassword` | **No** (gitignored; plantilla en `Local.xcconfig.example`) |

En cada arranque, antes de la primera conexión, `applyTrustChatServerPolicy()`
(`apps/ios/Shared/TrustChat/TrustChatConfig.swift`) deshabilita los operadores
SimpleX y Flux, deja habilitados solo el SMP y el XFTP de TrustChat, elimina
cualquier otro servidor agregado a mano y fija la red sin SOCKS, sin onion y sin
conexión directa a relays ajenos. El onboarding salta la elección de operadores
y no se registra el token APNs. Si falta `TrustChatConfig.plist`, la app se
comporta como SimpleX upstream.

Para cambiar de servidor: editar el plist (y `Local.xcconfig` si cambia el PASS)
y recompilar. No hace falta recompilar el core Haskell.

## Configurar el servidor SMP

La app puede conectarse al SMP local o al desplegado en Railway.

### Servidor local desde el simulador

Si el servidor Docker se publica en la Mac como `127.0.0.1:5223`, usar la
dirección generada por el servidor con este final:

```text
smp://<FINGERPRINT>:<PASS>@127.0.0.1:5223
```

El iOS Simulator sobre la misma Mac puede utilizar ese loopback. Un iPhone
físico no puede hacerlo.

### Servidor Railway

El deployment actualmente probado utiliza como ejemplo:

```text
iriguchi.proxy.rlwy.net:19616
```

La dirección del cliente debe tener este formato:

```text
smp://<FINGERPRINT>:<PASS>@iriguchi.proxy.rlwy.net:19616
```

No debe contener `https://`, una barra al final ni el puerto interno `5223`.

### Agregarlo en la aplicación

1. Abrir **Settings**.
2. Entrar en **Network & servers**.
3. Abrir **Your servers**.
4. Elegir **Add server → Enter server manually**.
5. Pegar la dirección SMP completa.
6. Ejecutar **Test server**.
7. Activar **Use for new connections**.
8. Guardar la configuración.

La dirección completa incluye `PASS`: no publicarla en issues, capturas,
documentación pública ni commits.

### Servidores públicos y privacidad

Agregar el SMP de TrustChat no desactiva automáticamente los servidores
predeterminados ni cambia conexiones anteriores.

Para validar que una conexión nueva utiliza solamente la infraestructura
prevista:

1. Configurar los servidores antes de crear la conexión.
2. Deshabilitar los SMP públicos para nuevas conexiones, si ése es el requisito
   del entorno.
3. Crear un contacto nuevo entre dos clientes.
4. Verificar tráfico y logs del SMP privado.

El servidor actual es únicamente SMP. Los adjuntos pueden seguir utilizando
servidores XFTP externos y las notificaciones push requieren su propia
infraestructura. No afirmar que todo el tráfico está bajo control de TrustChat
hasta haber desplegado y verificado esos componentes.

## Pruebas

### Compilación

- La configuración Debug compila sin errores.
- `plutil -lint` valida `project.pbxproj`.
- No aparecen errores de arquitectura ni símbolos Haskell indefinidos.
- Los targets de extensiones continúan compilando.

### Pruebas desde Xcode

Usar **Product → Test** (`⌘U`) con el scheme correspondiente y revisar el
resultado completo, no solamente la compilación del target principal.

### Prueba funcional mínima

1. Abrir la app sin crash.
2. Crear dos perfiles de prueba en instalaciones independientes.
3. Configurar el SMP privado en ambos clientes.
4. Ejecutar **Test server**.
5. Crear una conexión nueva.
6. Enviar y recibir mensajes en ambas direcciones.
7. Desconectar un receptor, enviar un mensaje y comprobar la entrega posterior.
8. Reiniciar el SMP y repetir el intercambio.
9. Confirmar qué servidor utiliza la transferencia de archivos.

### Pruebas exclusivas de dispositivo físico

No se pueden validar completamente en simulador:

- APNs y comportamiento real de notificaciones en background;
- Notification Service Extension;
- Share Extension con otras aplicaciones reales;
- cámara, micrófono y permisos del dispositivo;
- llamadas y audio en segundo plano;
- protección de datos cuando el dispositivo está bloqueado;
- instalación, actualización y restauración mediante TestFlight/App Store.

## Build para iPhone físico (`arm64`)

> **Pendiente de validación:** los siguientes pasos representan el camino
> definido por el `flake.nix` de SimpleX, pero todavía no forman parte del
> baseline comprobado de TrustChat. El output está expuesto para un host
> `aarch64-darwin`; no debe asumirse que puede construirse directamente en el
> Mac Intel utilizado para el baseline.

En un Mac Apple Silicon, compilar la biblioteca para iOS físico:

```bash
nix --extra-experimental-features "nix-command flakes" \
  build '.#aarch64-darwin-ios:lib:simplex-chat' \
  --no-update-lock-file \
  --out-link result-ios-device \
  -L
```

Resultado esperado:

```text
result-ios-device/pkg-ios-aarch64-swift-json.zip
```

Para trabajar desde un Mac Intel, obtener ese ZIP mediante una de estas vías:

- un build de CI fijado al mismo commit;
- un Mac Apple Silicon controlado por el equipo;
- `scripts/ios/download-libs.sh`, únicamente después de confirmar que descarga
  la versión y el hash esperados.

No mezclar una biblioteca `arm64` de otro commit o versión del core. Registrar
el commit de origen y verificar el checksum del artefacto antes de utilizarlo.

Preparar el directorio:

```bash
mkdir -p apps/ios/Libraries/ios
unzip -o \
  result-ios-device/pkg-ios-aarch64-swift-json.zip \
  -d apps/ios/Libraries/ios
```

Verificar las arquitecturas antes de abrir Xcode:

```bash
find apps/ios/Libraries/ios -maxdepth 1 -type f -name '*.a' \
  -exec lipo -info {} \;
```

Los archivos deben ser compatibles con `arm64` para iPhoneOS. No copiar las
bibliotecas de `sim/` a `ios/`: aunque ambas puedan contener `arm64` en un Mac
Apple Silicon, pertenecen a plataformas distintas.

Actualizar el proyecto con el script del repositorio y validar el resultado:

```bash
sed 's|^LIB_DIR=.*|LIB_DIR=./apps/ios/Libraries/ios|' \
  scripts/ios/update-pbxproj.sh | sh
plutil -lint apps/ios/SimpleX.xcodeproj/project.pbxproj
```

Antes de considerar este procedimiento estable, debe completarse el checklist
de dispositivo y distribución incluido al final del documento.

## Firma, Bundle IDs y capabilities

El baseline proviene de SimpleX y conserva configuraciones upstream que no
deben utilizarse como identidad definitiva de TrustChat. Antes de instalar en
un dispositivo o subir a App Store Connect:

1. Obtener una cuenta Apple Developer para la organización responsable.
2. Definir un Bundle ID definitivo para la app.
3. Definir identificadores propios para NSE y SE.
4. Definir un App Group propio compartido por la app y sus extensiones.
5. Revisar Keychain Access Groups, Push Notifications y Background Modes.
6. Aplicar el mismo Team a todos los targets.
7. Confirmar que ningún entitlement siga apuntando a `chat.simplex.app` o
   `group.chat.simplex.app`, salvo que exista una decisión explícita y válida.

Ejemplo conceptual —no registrar literalmente sin acordar el dominio—:

```text
App:       com.organizacion.trustchat
NSE:       com.organizacion.trustchat.NSE
SE:        com.organizacion.trustchat.SE
App Group: group.com.organizacion.trustchat
```

En Xcode, revisar **Signing & Capabilities** target por target. La opción
**Automatically manage signing** es adecuada para comenzar, siempre que cada
target tenga el identificador correcto y el mismo Team.

No guardar certificados `.p12`, claves APNs, perfiles privados ni contraseñas
en el repositorio.

## Configuración local y assets

La base admite un `Local.xcconfig` local/gitignored para overrides como los
assets personalizados. Mantener allí sólo configuración no secreta o rutas
locales.

Los secretos de producción no deben incorporarse a:

- `Debug.xcconfig`;
- `Release.xcconfig`;
- `Info.plist`;
- código Swift/Haskell;
- assets del bundle;
- argumentos persistidos en schemes compartidos.

Cualquier secreto incluido en el binario de iOS puede ser extraído. Una
invitación o credencial SMP de producción debe entregarse mediante un flujo de
activación controlado, con tokens de corta duración y validación en backend.

## Distribución

### Decisión para TrustChat

| Etapa | Modalidad | Uso |
|---|---|---|
| Desarrollo local | Xcode + Simulator/dispositivo registrado | Trabajo diario del equipo |
| MVP y pruebas externas | TestFlight | Validación antes de producción; cada build expira a los 90 días |
| Producción | App Store **Unlisted** | Instalación mediante enlace directo, sin aparecer en búsquedas públicas |

La protección de acceso no debe depender solamente del enlace Unlisted: el
enlace puede reenviarse. TrustChat debe exigir su propia invitación o
activación, idealmente de un solo uso y con expiración.

Una web privada no puede instalar libremente un IPA en cualquier iPhone. Ad
Hoc exige registrar previamente cada UDID y tiene límites de dispositivos;
Apple Enterprise/MDM está reservado a escenarios organizacionales específicos
y no corresponde a clientes externos arbitrarios.

### TestFlight

Flujo resumido:

1. Crear el registro de la app en App Store Connect.
2. Preparar las bibliotecas `arm64` y la firma de todos los targets.
3. Incrementar `Marketing Version` y `Current Project Version`.
4. Seleccionar **Any iOS Device (arm64)** o un destino genérico iOS.
5. Ejecutar **Product → Archive**.
6. En Organizer, validar el archive.
7. Elegir **Distribute App → App Store Connect → Upload**.
8. Completar la información de TestFlight.
9. Enviar el primer build externo a Beta App Review.
10. Invitar testers mediante email o enlace controlado.

TestFlight es un canal de pruebas, no la distribución permanente del producto.

### Producción Unlisted

1. Completar la ficha de App Store Connect.
2. Subir y seleccionar el build de producción.
3. Declarar privacidad y tratamiento de datos con precisión.
4. Resolver export compliance por el uso de criptografía.
5. Proporcionar a App Review una invitación/cuenta funcional y pasos claros.
6. Incluir eliminación de cuenta dentro de la app si existe creación de cuenta.
7. Enviar la versión a App Review.
8. Solicitar a Apple la distribución **Unlisted**.
9. Integrar el enlace aprobado con el sistema privado de invitaciones.

Unlisted oculta la app de búsquedas, rankings y navegación normal del App
Store, pero no evita App Review ni sustituye los controles de autenticación.

## Privacidad y seguridad

- No registrar contenidos de mensajes, claves, direcciones SMP completas,
  tokens de invitación ni datos sensibles en logs.
- No subir bases de datos de usuarios, exports de chat o capturas reales al
  repositorio.
- Guardar credenciales locales mediante Keychain y aplicar protección de datos
  adecuada a los archivos.
- Mantener el fingerprint SMP para detectar cambios de identidad del servidor.
- Tratar la cadena `smp://...:PASS@...` como una credencial.
- Evitar servidores públicos en conexiones nuevas cuando la política exija
  infraestructura exclusiva de TrustChat.
- Auditar por separado SMP, XFTP, push y llamadas: controlar SMP no significa
  controlar automáticamente los demás flujos.
- Revisar dependencias y cambios upstream antes de cada actualización.
- No desactivar App Transport Security ni validaciones TLS para resolver un
  problema de desarrollo.
- Probar que una invitación no pueda reutilizarse y que su revocación funcione.

Como la app incorpora criptografía, App Store Connect exige realizar la
evaluación de export compliance. No asumir una exención sin responder el
cuestionario según los algoritmos y bibliotecas realmente incluidos.

## Caché y tiempos de compilación

| Cambio | Qué se recompila |
|---|---|
| Sólo Swift/SwiftUI | Xcode; reutiliza las bibliotecas Haskell |
| Haskell o `cabal.project` | Nix reconstruye las derivaciones afectadas |
| `flake.nix` o `flake.lock` | Puede cambiar el toolchain y gran parte de la caché |
| Cambio de arquitectura | Requiere otro paquete (`sim` o `ios`) |
| Clean Build Folder | Limpia productos de Xcode, no el Nix store |
| Borrar el Nix store | Fuerza descargas/builds costosos; no usar como solución habitual |

El primer build Haskell puede tardar mucho. No cancelarlo sólo porque durante
varios minutos no aparezcan nuevas líneas; revisar uso de CPU, disco y la
salida `-L` antes de concluir que está bloqueado.

## Solución de problemas

### `nix: command not found`

Abrir una terminal nueva después de instalar Nix y comprobar:

```bash
nix --version
```

Si continúa faltando, revisar la instalación oficial y el daemon de Nix antes
de modificar manualmente rutas del sistema.

### Las flakes no están habilitadas

Usar el comando documentado con:

```text
--extra-experimental-features "nix-command flakes"
```

No es necesario cambiar una configuración global para ejecutar este build.

### No existe `pkg-ios-x86_64-swift-json.zip`

Verificar que se utilizó el output correcto:

```bash
readlink result-ios-sim
find -L result-ios-sim -maxdepth 1 -type f -print
```

Revisar el final del log de Nix; un symlink `result-ios-sim` existente no
garantiza que el build nuevo haya terminado correctamente.

### `mac2ios` no existe o no es ejecutable

```bash
ls -l "$HOME/.local/bin/mac2ios"
chmod 755 "$HOME/.local/bin/mac2ios"
```

Verificar el origen del binario antes de ejecutarlo.

### `Undefined symbols for architecture x86_64`

Normalmente indica bibliotecas ausentes, incorrectas o no preparadas:

1. Confirmar que se construyó el output `x86_64-darwin-ios`.
2. Confirmar que el ZIP se extrajo en `apps/ios/Libraries/sim`.
3. Ejecutar `mac2ios -s` sobre todos los `.a`.
4. Ejecutar `update-pbxproj.sh` con `LIB_DIR` de simulador.
5. Validar `project.pbxproj` y limpiar el build de Xcode.

### `building for iOS Simulator, but linking in object file built for iOS`

Se mezclaron plataformas. Utilizar:

```text
apps/ios/Libraries/sim  -> simulador
apps/ios/Libraries/ios  -> dispositivo físico
```

La arquitectura `arm64` por sí sola no alcanza para decidir: iPhoneOS y
iPhoneSimulator son plataformas binarias diferentes.

### Xcode no encuentra una biblioteca `libHS...`

Los nombres cambiaron después de recompilar el core. Volver a ejecutar:

```bash
sed 's|^LIB_DIR=.*|LIB_DIR=./apps/ios/Libraries/sim|' \
  scripts/ios/update-pbxproj.sh | sh
plutil -lint apps/ios/SimpleX.xcodeproj/project.pbxproj
```

Luego revisar el diff del proyecto antes de commitearlo.

### `project.pbxproj` quedó inválido

No abrir ni guardar el proyecto repetidamente. Conservar el archivo defectuoso
para analizar el problema y restaurar únicamente ese cambio desde Git si no
contiene trabajo válido. La comprobación obligatoria es:

```bash
plutil -lint apps/ios/SimpleX.xcodeproj/project.pbxproj
```

### Error de firma o provisioning

Revisar en todos los targets:

- Team;
- Bundle Identifier;
- App Group;
- capabilities;
- perfiles de la app y extensiones;
- dispositivo registrado para builds de desarrollo.

Un target principal correctamente firmado no compensa una NSE o SE con un
perfil incompatible.

### El simulador conecta localmente, pero el iPhone no

`127.0.0.1` en el iPhone representa el propio teléfono, no la Mac. Utilizar la
IP LAN de la Mac con el puerto publicado y el firewall configurado, o el SMP
público de Railway.

### TCP/TLS funcionan, pero **Test server** falla

Revisar:

- formato exacto `smp://`;
- fingerprint;
- `PASS`;
- puerto público de Railway;
- proxy SOCKS configurado en la app;
- versión de protocolo compatible entre cliente y servidor.

### Xcode conserva errores después de corregir las bibliotecas

Usar **Product → Clean Build Folder**, cerrar Xcode, volver a abrir el proyecto
y compilar nuevamente. No borrar indiscriminadamente todo `~/Library` ni el
Nix store.

## Política de Git

Antes de comenzar una modificación:

```bash
git status --short --branch
git rev-parse HEAD
```

Antes de commitear:

```bash
git diff --check
git status --short
```

No subir:

- `result-ios-sim` o `result-ios-device`;
- DerivedData;
- archives `.xcarchive`;
- `.ipa`;
- certificados y perfiles privados;
- claves APNs;
- archivos locales con credenciales;
- direcciones SMP completas;
- bases o exports de chats.

Las bibliotecas generadas deben seguir la política definida en
`apps/ios/.gitignore`; no forzarlas al repositorio sin una decisión explícita.

## Checklist: nuevo desarrollador

- [ ] Repositorio clonado y commit registrado.
- [ ] Xcode y Command Line Tools verificados.
- [ ] Nix funcionando.
- [ ] `mac2ios` verificado.
- [ ] Core Haskell compilado para la arquitectura correcta.
- [ ] ZIP extraído en `Libraries/sim` o `Libraries/ios`.
- [ ] Archivos `.a` preparados para su plataforma.
- [ ] `update-pbxproj.sh` ejecutado.
- [ ] `plutil -lint` devuelve `OK`.
- [ ] Scheme `SimpleX (iOS)` seleccionado.
- [ ] App ejecutada sin crash.
- [ ] Servidor SMP probado desde la app.
- [ ] `git status` revisado antes de comenzar cambios.

## Checklist: release

- [ ] Build `arm64` para dispositivo validado.
- [ ] App y extensiones usan Team y Bundle IDs definitivos.
- [ ] App Group y Keychain Groups propios y consistentes.
- [ ] APNs y Background Modes validados en dispositivo real.
- [ ] Version y build number incrementados.
- [ ] Tests automáticos y funcionales aprobados.
- [ ] SMP privado probado con conexiones nuevas.
- [ ] Uso real de XFTP y push identificado y aprobado.
- [ ] No hay secretos ni información sensible en logs o bundle.
- [ ] Archive validado y subido a App Store Connect.
- [ ] Export compliance completado.
- [ ] Privacy Policy y App Privacy actualizadas.
- [ ] Cuenta/invitación de App Review preparada.
- [ ] Eliminación de cuenta disponible si corresponde.
- [ ] Build de TestFlight probado antes de producción.
- [ ] Solicitud Unlisted completada para la versión productiva.

## Referencias

- [Repositorio upstream de SimpleX Chat](https://github.com/simplex-chat/simplex-chat)
- [Nix — instalación oficial](https://nixos.org/download/)
- [Apple — ejecutar en simulador o dispositivo](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device)
- [Apple — preparar una app para distribución](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution/)
- [Apple — distribuir builds y releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Apple — TestFlight](https://developer.apple.com/testflight/)
- [Apple — Unlisted App Distribution](https://developer.apple.com/support/unlisted-app-distribution/)
- [Apple — App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [Apple — App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Apple — export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)
- [Apple — App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
