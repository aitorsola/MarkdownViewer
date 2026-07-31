# MarkdownViewer

Visor de Markdown para macOS. Se registra como aplicación para ficheros `.md`/`.markdown`, de modo que se abren con doble click o desde "Abrir con…".

## Características

- Sidebar con el índice de secciones del documento (encabezados); al seleccionar una, el contenido salta a ella.
- Render nativo SwiftUI: encabezados, listas anidadas, citas, bloques de código, reglas horizontales y tablas reales (con alineaciones de columna).
- Código inline coloreado (excepto en títulos).
- Exportación a PDF (⌘E) paginada en A4, con tablas y estilos.
- Solo lectura: sin riesgo de modificar el documento.

## Requisitos

- macOS 14+
- Xcode 16+ y [XcodeGen](https://github.com/yonaskolb/XcodeGen) para generar el proyecto.

## Build

```bash
xcodegen generate
xcodebuild -project MarkdownViewer.xcodeproj -scheme MarkdownViewer -configuration Release build
```

El proyecto Xcode (`MarkdownViewer.xcodeproj`) se genera desde `project.yml` y no se versiona.

## Distribución

La firma usa Developer ID con `--timestamp`, lista para notarizar:

```bash
ditto -c -k --keepParent MarkdownViewer.app MarkdownViewer.zip
xcrun notarytool submit MarkdownViewer.zip --keychain-profile <perfil> --wait
xcrun stapler staple MarkdownViewer.app
```
