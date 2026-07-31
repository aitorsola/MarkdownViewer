# MarkdownViewer

Un visor **nativo** de Markdown para macOS, con *sidebar de secciones*, exportación a PDF y modo edición. Escrito en SwiftUI, sin dependencias.

## Características

- Doble click en cualquier fichero `.md` y se abre al instante
- Índice lateral generado a partir de los encabezados
- Código inline con `resaltado de color`
- Exportación a PDF con ⌘E

## Comandos rápidos

| Atajo | Acción | Modo |
|-------|--------|:----:|
| `⌘E` | Exportar a PDF | ambos |
| `⇧⌘E` | Activar edición | visor |
| `⌘S` | Guardar cambios | editor |

## Ejemplo de código

```swift
let saludo = "Hola, mundo"
print(saludo)
```

> La sencillez es la máxima sofisticación.

---

### Y mucho más

1. Listas ordenadas
2. Con **formato** inline
3. Y [enlaces](https://github.com/aitorsola/MarkdownViewer)
