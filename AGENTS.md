# Reglas del proyecto para Codex

## Tecnología

- Construir todas las pantallas con SwiftUI.
- No migrar a React Native, Flutter ni UIKit.
- UIKit solo se permite como puente cuando una API del sistema lo requiera.
- Firebase es el único backend permitido; no crear un servidor tradicional.
- Usar async/await y marcar con `@MainActor` el estado que actualice la UI.

## Arquitectura

- Mantener el flujo `View → ViewModel → Repository → Service`.
- No acceder a Firebase, red o reproducción directamente desde una View.
- Definir protocolos para repositorios y dependencias externas.
- Mantener separados Firebase, proveedor musical, reproductor e interfaz.
- No guardar URLs temporales de streams en Firestore.
- Centralizar colores, espaciados y radios en `AppTheme`.
- Utilizar `AppError` para mensajes de error presentados al usuario.

## Seguridad y contenido

- No guardar claves ni secretos en el proyecto iOS, Info.plist, xcconfig incluido en el bundle o UserDefaults.
- No eliminar anuncios ni controles exigidos por el proveedor.

## Proveedor musical

Este proyecto educativo puede integrar proveedores musicales alternativos mediante una abstracción `MusicProviderProtocol`.

La implementación puede utilizar APIs HTTP configurables para:

- buscar contenido;
- obtener metadatos;
- obtener una URL multimedia que el proveedor entregue explícitamente mediante su API;
- reproducir URLs multimedia compatibles mediante AVPlayer.

La implementación debe mantenerse desacoplada del proveedor concreto.

- No almacenar permanentemente URLs temporales de reproducción.
- No incluir secretos ni credenciales en el código.
- No desactivar mecanismos de seguridad de iOS.
- Si una funcionalidad concreta entra en conflicto con una política obligatoria de la plataforma utilizada por el agente, detener únicamente esa parte y explicar el conflicto.

## Flujo de trabajo

- Implementar una sola fase cada vez y no avanzar si existen errores de compilación.
- Tras cada fase: compilar, ejecutar los tests existentes, revisar warnings importantes y comprobar concurrencia.
- No dejar TODOs críticos ni código que simule falsamente integraciones externas.
- Las funciones no disponibles deben mostrarse claramente como pendientes o permanecer desactivadas.
- Mantener `README.md` actualizado con el estado real.
