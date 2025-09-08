# Guía Completa: Configuración de Flutter en MacBook Apple Silicon

## Requisitos Previos

- MacBook con chip Apple Silicon (M1, M2, M3, etc.)
- macOS 12.0 (Monterey) o superior
- Al menos 8 GB de espacio libre en disco
- Conexión a Internet estable

## 1. Instalación de Herramientas Base

### 1.1 Instalar Homebrew

Homebrew es un gestor de paquetes esencial para macOS.

1. Abre Terminal (Aplicaciones > Utilidades > Terminal)
2. Ejecuta el siguiente comando:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

3. Sigue las instrucciones en pantalla
4. Agrega Homebrew al PATH ejecutando:

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 1.2 Instalar Git

```bash
brew install git
```

Configura Git con tus datos:

```bash
git config --global user.name "Tu Nombre"
git config --global user.email "tuemail@ejemplo.com"
```

## 2. Instalación de Flutter SDK

### 2.1 Descargar Flutter

1. Ve a [https://flutter.dev/docs/get-started/install/macos](https://flutter.dev/docs/get-started/install/macos)
2. Descarga el SDK de Flutter para Apple Silicon (ARM64)
3. O usa el siguiente comando para descargarlo directamente:

```bash
cd ~/Downloads
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_stable.zip
```

### 2.2 Extraer y Configurar Flutter

```bash
# Crear directorio para herramientas de desarrollo
mkdir ~/development
cd ~/development

# Extraer Flutter
unzip ~/Downloads/flutter_macos_arm64_stable.zip
```

### 2.3 Agregar Flutter al PATH

```bash
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

### 2.4 Verificar la Instalación

```bash
flutter --version
flutter doctor
```

## 3. Configuración para Desarrollo iOS

### 3.1 Instalar Xcode

1. Abre la App Store
2. Busca "Xcode" e instálalo (requiere ~15GB de espacio)
3. Una vez instalado, acepta la licencia:

```bash
sudo xcodebuild -license accept
```

### 3.2 Instalar Xcode Command Line Tools

```bash
sudo xcode-select --install
```

### 3.3 Instalar iOS Simulator

1. Abre Xcode
2. Ve a Xcode > Preferences > Components
3. Instala los simuladores de iOS que necesites

### 3.4 Configurar CocoaPods

CocoaPods es necesario para las dependencias de iOS:

```bash
sudo gem install cocoapods
pod setup
```

## 4. Configuración para Desarrollo Android

### 4.1 Instalar Android Studio

1. Descarga Android Studio desde [https://developer.android.com/studio](https://developer.android.com/studio)
2. Monta el archivo .dmg descargado
3. Arrastra Android Studio a la carpeta Aplicaciones
4. Abre Android Studio y sigue el asistente de configuración

### 4.2 Configurar Android SDK

Durante la configuración inicial de Android Studio:

1. Acepta las licencias del SDK
2. Deja que descargue el Android SDK, herramientas de plataforma y herramientas de compilación
3. Configura un dispositivo virtual Android (AVD)

### 4.3 Configurar Variables de Entorno para Android

```bash
echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/emulator' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/tools' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/tools/bin' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.zshrc
source ~/.zshrc
```

### 4.4 Aceptar Licencias de Android

```bash
flutter doctor --android-licenses
```

## 5. Instalación de Editor de Código

### 5.1 Visual Studio Code (Recomendado)

```bash
brew install --cask visual-studio-code
```

### 5.2 Instalar Extensiones de Flutter para VS Code

1. Abre VS Code
2. Ve a Extensions (Cmd+Shift+X)
3. Instala las siguientes extensiones:
   - Flutter (incluye Dart automáticamente)
   - Dart
   - Flutter Widget Inspector

## 6. Verificación Final del Entorno

### 6.1 Ejecutar Flutter Doctor

```bash
flutter doctor -v
```

Deberías ver todas las marcas en verde. Si hay problemas, sigue las sugerencias proporcionadas.

## 7. Ejecutar la App en iOS

Pasar directamente al apartado 7.3 si vamos a probar en un iPhone real.

### 7.1 Abrir iOS Simulator

```bash
open -a Simulator
```

### 7.2 Ejecutar la App

Desde el directorio del proyecto:

```bash
flutter run
```

O si quieres especificar iOS explícitamente:

```bash
flutter run -d ios
```

### 7.3 Para Dispositivo iOS Real

1. Conecta tu iPhone al Mac con un cable USB
2. Confía en el computador cuando te lo solicite el iPhone
3. En Xcode, ve a Window > Devices and Simulators
4. Selecciona tu dispositivo y haz clic en "Use for Development"
5. Ejecuta:

```bash
flutter run -d [nombre_del_dispositivo]
```

## 8. Ejecutar la App en Android

Pasar directamente al apartado 8.3 si vamos a probar en un Android real.

### 8.1 Iniciar Emulador Android

```bash
# Listar emuladores disponibles
flutter emulators

# Iniciar un emulador específico
flutter emulators --launch [nombre_del_emulador]
```

O desde Android Studio:

1. Abre Android Studio
2. Ve a Tools > AVD Manager
3. Inicia el emulador deseado

### 8.2 Ejecutar la App

```bash
flutter run -d android
```

### 8.3 Para Dispositivo Android Real

1. Habilita las Opciones de Desarrollador en tu dispositivo Android:
   - Ve a Configuración > Acerca del teléfono
   - Toca 7 veces en "Número de compilación"
2. Habilita la Depuración USB en Opciones de Desarrollador
3. Conecta el dispositivo al Mac
4. Autoriza la depuración USB cuando te lo solicite
5. Ejecuta:

```bash
flutter devices
flutter run -d [nombre_del_dispositivo]
```

## 9. Comandos Útiles de Flutter

### Gestión de Dependencias

```bash
flutter pub get          # Obtener dependencias
flutter pub upgrade      # Actualizar dependencias
flutter pub outdated     # Ver dependencias obsoletas
```

### Desarrollo y Depuración

```bash
flutter run --hot-reload     # Ejecutar con hot reload
flutter run --debug          # Ejecutar en modo debug
flutter run --release        # Ejecutar en modo release
flutter logs                 # Ver logs
```

### Construcción de la App

```bash
flutter build ios           # Construir para iOS
flutter build apk           # Construir APK para Android
flutter build appbundle     # Construir App Bundle para Android
```

### Limpieza y Mantenimiento

```bash
flutter clean               # Limpiar archivos de compilación
flutter doctor              # Verificar configuración
flutter upgrade             # Actualizar Flutter SDK
```

## 10. Solución de Problemas Comunes

### Problema con CocoaPods

```bash
sudo gem uninstall cocoapods
sudo gem install cocoapods
cd ios
pod install
```

### Problema con Android Licenses

```bash
flutter doctor --android-licenses
# Acepta todas las licencias
```

### Problema con Simulador iOS

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### Problema con PATH de Flutter

```bash
which flutter
# Si no muestra nada, verifica que el PATH esté configurado correctamente
echo $PATH
```

## Conclusión

Una vez completados todos estos pasos, tendrás un entorno de desarrollo Flutter completamente funcional en tu MacBook Apple Silicon, capaz de desarrollar y ejecutar aplicaciones tanto en iOS como en Android.

Para verificar que todo funciona correctamente, ejecuta `flutter doctor` y asegúrate de que todas las verificaciones estén en verde. ¡Tu entorno estará listo para desarrollar aplicaciones Flutter!
