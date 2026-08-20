# AppDePrueba — plataforma musical social

Aplicación educativa para iPhone construida exclusivamente con SwiftUI. El proyecto seguirá MVVM y separará la interfaz, el dominio, Firebase y el proveedor de contenido.

## Estado actual

Las **Fases 1, 2 y 3**, junto con la primera parte de la Fase 4, están completadas:

- estructura modular del proyecto;
- modelos base de usuario, playlist, miembro, canción y sala futura;
- navegación raíz dependiente de la sesión;
- pestañas Inicio, Buscar y Biblioteca;
- pantallas iniciales de acceso, creación de playlist, perfil y reproductor;
- componentes reutilizables y tema oscuro centralizado;
- estados de error comprensibles para el usuario;
- Firebase Apple SDK mediante Swift Package Manager;
- productos `FirebaseAuth`, `FirebaseFirestore` y `FirebaseFunctions`;
- arranque seguro de Firebase mediante un `UIApplicationDelegate` adaptado a SwiftUI;
- detección de configuración ausente sin cerrar la aplicación;
- registro e inicio de sesión con correo y contraseña;
- recuperación de contraseña por correo;
- cierre y restauración automática de sesión;
- mensajes de error de autenticación adaptados para usuarios;
- creación de playlists propias en Firestore;
- alta atómica del creador como miembro `owner`;
- actualización en tiempo real de las playlists propias en Biblioteca;
- generación local de códigos para playlists colaborativas.
- reglas de Firestore restrictivas para propietarios, miembros y roles;
- listeners de Biblioteca vinculados a la sesión autenticada y retirados al cerrarla.
- detalle navegable de playlist con canciones y miembros en tiempo real;
- invitaciones colaborativas de seis caracteres y unión mediante código;
- índice privado `userPlaylists` para separar playlists propias y colaborativas.
- búsqueda musical real mediante Piped, desacoplada tras `MusicProviderProtocol`;
- resolución local de streams con YouTubeKit 0.4.9 y reproducción global mediante AVPlayer;
- mini-player, reproductor completo, cola y guardado de canciones en playlists.

Firebase está conectado mediante un `GoogleService-Info.plist` local. Authentication y la primera parte de Firestore están implementados. La colaboración completa y la búsqueda musical siguen pendientes.

El Bundle Identifier registrado en Firebase y configurado en Xcode es `com.raulfernandez.AppDePrueb`.

## 1. Abrir el proyecto

1. Clona o descarga el repositorio.
2. Abre `AppDePrueba.xcodeproj` con Xcode.
3. Selecciona el esquema `AppDePrueba`.
4. Elige un simulador de iPhone y pulsa Run.

## 2. Requisitos de Xcode

El proyecto actual fue creado con Xcode 26.6 y tiene iOS 26.5 como versión mínima. Si se decide soportar versiones anteriores, habrá que cambiar el Deployment Target y comprobar la disponibilidad de las APIs empleadas.

## 3. Configurar Firebase (Fase 2)

1. Crea un proyecto en Firebase Console.
2. Añade una aplicación iOS con el mismo Bundle Identifier del target.
3. Añade Firebase mediante Swift Package Manager desde `https://github.com/firebase/firebase-ios-sdk`.
4. Selecciona únicamente `FirebaseAuth`, `FirebaseFirestore` y `FirebaseFunctions` si finalmente se usa una función callable.

## 4. Añadir GoogleService-Info.plist

Descarga `GoogleService-Info.plist` desde Firebase Console y arrástralo al grupo de la aplicación marcando el target `AppDePrueba`. No publiques un archivo de configuración perteneciente a un proyecto real si el repositorio es público.

## 5. Activar Firebase Authentication

En Firebase Console abre Authentication, activa Email/Password y configura los dominios permitidos. La implementación cliente corresponde a la Fase 3.

## 6. Crear Firestore

En Firebase Console crea una base Cloud Firestore. Durante el desarrollo local se recomienda usar Emulator Suite; para entornos remotos deben desplegarse reglas restrictivas antes de guardar datos reales.

## 7. Desplegar Firestore Security Rules

Las reglas restrictivas están en `firestore.rules`. Como el repositorio no identifica un proyecto en `.firebaserc`, selecciona primero el proyecto correcto con Firebase CLI y despliega únicamente las reglas. Nunca se debe mantener Firestore en modo de prueba para producción.

## 8. Activar Cloud Functions

Solo será necesario si se adopta la arquitectura oficial YouTube Data API + callable function. Las funciones y sus secretos no forman parte de la Fase 1.

## 9. Crear el proyecto de Google Cloud

El proyecto normalmente queda vinculado al crear Firebase. Comprueba en Google Cloud Console que facturación, cuotas y APIs pertenecen al entorno correcto.

## 10. Activar YouTube Data API v3

Este paso solo se realizará si se elige el enfoque oficial de YouTube. Activa la API en Google Cloud Console y revisa su cuota y condiciones de servicio.

## 11. Crear la API key de YouTube

Si se adopta ese enfoque, crea una clave restringida exclusivamente para la API necesaria. No debe incluirse en Swift, Info.plist, UserDefaults ni otro recurso del bundle.

## 12. Guardar la clave como secret

La clave se almacenará con Firebase/Google Cloud Secret Manager y se expondrá únicamente a la función autorizada.

## 13. Desplegar `searchYouTube`

La función callable se implementará y desplegará en su fase correspondiente solamente si el proveedor elegido es YouTube Data API. La app recibirá modelos reducidos y nunca el secreto.

## 14. Ejecutar la app

Desde Xcode selecciona un simulador y ejecuta el esquema. Mientras Firebase no esté integrado, utiliza el acceso de maqueta disponible únicamente en Debug.

## 15. Ejecutar tests

El target de tests y sus mocks se añadirá en la fase de pruebas. Una vez creado, podrán ejecutarse con Product > Test en Xcode o mediante `xcodebuild test` con un destino de simulador.

## Arquitectura

El flujo obligatorio será:

```text
View → ViewModel → Repository → Service → fuente externa
```

Las Views no accederán directamente a Firebase ni al proveedor musical. Los repositorios se definirán mediante protocolos para permitir mocks en tests.

## Fuente musical

La búsqueda utiliza el endpoint `/search` de Piped mediante una URL base centralizada. La reproducción no depende de los streams de Piped: YouTubeKit resuelve en el dispositivo una URL temporal a partir de `videoId`, y AVPlayer la reproduce. Las URLs temporales nunca se persisten en Firestore.

## Plan de fases

1. Base SwiftUI, modelos, navegación y tema — completada.
2. Firebase mediante Swift Package Manager — integrada; falta el plist del proyecto.
3. Autenticación — completada.
4. Firestore y playlists — primera parte completada.
5. Colaboración y tiempo real — biblioteca, miembros e invitaciones completados; edición de canciones pendiente del buscador.
6. Proveedor de búsqueda — completado con Piped para búsqueda y YouTubeKit para reproducción.
7. Buscador y debounce — completados; paginación pendiente.
8. Reproductor AVPlayer — completado.
9. Cola global y mini reproductor — completados.
10. Miembros, compartir y permisos.
11. Firestore Security Rules — base de propietarios, miembros y roles completada; ampliar junto con las funciones colaborativas.
12. Tests y pulido.
