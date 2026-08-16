# Modelos probados con scaleLLMflow

Estado de referencia: `scaleLLMflow 0.3.7` (2026-08-14).

Este archivo recoge modelos que se han ejecutado o utilizado en los ejemplos de
la librería. La compatibilidad de un modelo puede cambiar en el proveedor; por
eso no equivale a una garantía permanente de disponibilidad.

## Modelos y usos comprobados

| Proveedor | Modelo | Uso comprobado | Observaciones | Predeterminado en 0.3.7 |
|---|---|---|---|---|
| Gemini | `gemini-3.6-flash` | Evaluación de escalas MQS/PEDro y ejemplos generales | Modelo rápido; admite `temperature` y salida estructurada | **Sí, para evaluación general Gemini** |
| Gemini | `gemini-3.5-flash-lite` | Comparación entre modelos | Variante ligera y económica; adecuada para pruebas rápidas | No |
| OpenAI | `gpt-4.1-mini` | Entrenamiento local de prompts MQS y comparación de modelos | Buen equilibrio entre coste y calidad para entrenamiento | No |
| OpenAI | `gpt-5.6-luna` | Conversión PDF → Markdown, incluido un artículo a dos columnas | Mejor reconstrucción observada del orden de lectura; admite `temperature` solo con `reasoning_effort = "none"` | **Sí, para conversión PDF LLM** |
| Claude | `claude-sonnet-4-20250514` | Ejemplo de evaluación libre | Se utiliza mediante la API Messages de Anthropic | No; debe seleccionarse explícitamente |

## Predeterminados por proveedor y contexto

Los valores predeterminados dependen del contexto de uso:

- Gemini: `gemini-3.6-flash` es el modelo predeterminado para evaluación general
  cuando `provider = "gemini"`.
- OpenAI: `gpt-5.6-luna` es el modelo predeterminado para conversión PDF LLM
  (`conversion = "llm"`), porque fue el que mejor resolvió el artículo de dos
  columnas probado.
- Claude: no se fuerza un modelo predeterminado; se recomienda indicar
  explícitamente `claude-sonnet-4-20250514` u otro modelo disponible.

El modelo de conversión es independiente del modelo de evaluación. Por ejemplo:

```r
run_article(
  article_path = "article.pdf",
  provider = "gemini",
  model = "gemini-3.6-flash",
  conversion = "llm",
  conversion_provider = "openai",
  conversion_model = "gpt-5.6-luna"
)
```

## Notas de compatibilidad

En `gpt-5.6-luna`, `temperature` solo es compatible cuando el razonamiento está
desactivado (`reasoning_effort = "none"`). Si se usa un nivel distinto de
`"none"`, scaleLLMflow omite automáticamente `temperature`. Para artículos PDF
complejos, especialmente a dos columnas, la conversión LLM suele dar mejores
resultados que la conversión heurística local, aunque implica coste, latencia y
envío del texto al proveedor seleccionado.

Para configurar explícitamente ambos parámetros:

```r
run_llm(
  prompt = "...",
  provider = "openai",
  model = "gpt-5.6-luna",
  reasoning_effort = "none",
  temperature = 0
)
```
