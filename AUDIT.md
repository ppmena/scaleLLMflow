# Informe de Auditoría de Software: Proyecto scaleLLMflow

Este informe detalla la auditoría técnica completa del subproyecto de librería R `scaleLLMflow`, cuyo objetivo es automatizar y generalizar el flujo de evaluación de escalas metodológicas y de calidad científica (como MQS) en artículos científicos utilizando Modelos de Lenguaje Grande (LLMs).

---

## 1. Resumen Ejecutivo

La librería `scaleLLMflow` presenta una arquitectura conceptual sólida para la automatización de la evaluación científica. Centraliza las directrices (prompts) y metadatos por escala y modelo, facilitando la reproducibilidad y la extensibilidad de las evaluaciones. Sin embargo, la implementación actual cuenta con varias debilidades críticas en el código fuente que comprometen la funcionalidad principal (especialmente con proveedores como OpenAI), la robustez del análisis sintáctico (parsing) de las respuestas de los modelos, y la tolerancia a fallos en flujos de datos a gran escala.

### Resumen de Hallazgos
*   **Crítico**: El cliente de OpenAI en `R/providers.R` está completamente roto debido al uso de un endpoint incorrecto (`/v1/responses`), un payload no estándar (`input` en lugar de `messages`), y un esquema de respuesta que no coincide con las especificaciones oficiales de OpenAI.
*   **Crítico**: El extractor de ítems de la respuesta del modelo (`extract_ordered_items` en `R/parse.R`) utiliza expresiones regulares de reemplazo multilinea muy frágiles que pueden provocar fallos en la detección de los números de ítems cuando estos contienen saltos de línea en sus justificaciones, omitiendo datos válidos.
*   **Medio-Alto**: El procesamiento por lotes en `run_dataset` (`R/workflow.R`) carece de manejo de excepciones. Si un solo archivo PDF está corrupto o se produce un timeout transitorio de la API en el artículo número 50 de un lote de 100, toda la ejecución se aborta y no se genera el informe de consenso intermedio, resultando en pérdida de tiempo y recursos.
*   **Medio**: El algoritmo de eliminación de secciones de referencias (`strip_references_section` en `R/text.R`) es sumamente agresivo en su lógica de fallback, pudiendo truncar porciones válidas del cuerpo del artículo (como discusiones o conclusiones) si contienen la palabra "references" en la última mitad del texto.
*   **Bajo**: El proyecto carece por completo de un marco de pruebas automatizadas, lo que incrementa sustancialmente el riesgo de regresiones durante el mantenimiento del software.

---

## 2. Arquitectura y Estructura del Proyecto

El paquete está estructurado como una librería estándar de R, lo cual es correcto.
*   `DESCRIPTION`: Correctamente definido con metadatos del paquete y dependencias necesarias (`httr2`, `jsonlite`, `pdftools`, `stringr`).
*   `NAMESPACE`: Exporta correctamente las funciones públicas clave (`run_article`, `run_dataset`, `available_scales`, etc.).
*   `R/`: El código está modularizado de forma lógica:
    *   `providers.R`: Conectores con las APIs de LLMs (Gemini, OpenAI).
    *   `parse.R`: Utilidades de formateo, cálculo de modas (consenso) y extracción sintáctica de puntuaciones.
    *   `registry.R`: Gestión local de prompts, metadatos de escalas y resolución inteligente de fallbacks de modelos.
    *   `text.R`: Extracción de texto desde PDFs/TXT/MD y limpieza de referencias bibliográficas.
    *   `workflow.R`: Orquestación de flujos para artículos individuales o conjuntos de datos completos.
*   `inst/scales/`: Estructura jerárquica excelente (`<escala>/<modelo>/prompt.txt` y `metadata.json`) para un almacenamiento extensible de plantillas y trazabilidad del entrenamiento.

---

## 3. Análisis de Código y Debilidades Detectadas

### 3.1 Integración con OpenAI en `R/providers.R` (Crítico)
*   **Problema**: La función `call_openai` realiza una petición POST al endpoint `https://api.openai.com/v1/responses`. Este endpoint no existe en la API oficial de OpenAI. El endpoint correcto para chat/completions es `https://api.openai.com/v1/chat/completions`.
*   **Problema de Payload**: El payload actual envía:
    ```r
    body <- list(model = model, input = prompt, temperature = temperature)
    ```
    La API de chat de OpenAI no reconoce el campo `input`; requiere un array de objetos bajo el campo `messages` con estructuras `role` y `content`.
*   **Problema de Parseo**: Se intenta analizar la respuesta buscando campos como `parsed$output_text` o `parsed$output`, los cuales corresponden a otras APIs o formatos antiguos/ficticios. La API oficial devuelve el texto bajo `choices[[1]]$message$content`.

### 3.2 Robustez de Expresiones Regulares en `R/parse.R` (Crítico)
*   **Problema**: La función `extract_ordered_items` extrae el número de ítem de cada bloque usando:
    ```r
    item_number <- sub("(?ims)^\\s*(?:[\\*-]\\s*)?Item\\s*(\\d{1,2})\\s*:.*$", "\\1", block, perl = TRUE)
    ```
    Dado que `block` suele contener saltos de línea y el flag multiline (`m`) está activo junto con dotall (`s`), la expresión regular `^... .*$` puede comportarse de manera impredecible o no capturar correctamente todo el bloque si hay espacios o caracteres no contemplados al principio. Si el resultado de `sub` incluye saltos de línea residuales o texto extra, la comparación `item_number %in% names(ordered_items)` fallará silenciosamente, marcando el ítem como "ERROR" en el reporte final.
*   **Solución Recomendada**: Utilizar una extracción directa y limpia con `stringr::str_match(block, "(?i)Item\\s*(\\d{1,2})")[, 2]`, lo cual es sumamente robusto ante cualquier formato de bloque.

### 3.3 Falta de Tolerancia a Fallos en `R/workflow.R` (Medio-Alto)
*   **Problema**: La función `run_dataset` itera sobre todos los artículos científicos de una carpeta. Si uno de los PDFs no tiene texto extraíble suficiente, o si la llamada a la API del LLM falla por límite de cuota, timeout o error de red, la función llama a `stop()` dentro de `run_article` y aborta inmediatamente todo el lote.
*   **Impacto**: Pérdida de progreso en ejecuciones largas. No se genera el archivo CSV final con los resultados procesados hasta el momento del fallo.
*   **Solución Recomendada**: Implementar un bloque `tryCatch` dentro del bucle de `run_dataset`. Si ocurre un error, se debe capturar, registrar un aviso explicativo en la consola/log, y continuar con el siguiente artículo. De este modo, al final se genera un archivo CSV con todos los artículos procesados con éxito.

### 3.4 Truncado Agresivo de Referencias en `R/text.R` (Medio)
*   **Problema**: Si el primer bloque de patrones específicos de la sección de referencias no genera cambios, la función `strip_references_section` ejecuta un fallback sumamente agresivo:
    ```r
    heading_matches <- gregexpr("(?i)\\b(references|bibliography|reference list|literature cited)\\b", article_text, perl = TRUE)[[1]]
    ```
    Busca cualquier coincidencia de la palabra "references" con límites de palabra (`\b`) en la segunda mitad del texto (después del 55%) y trunca absolutamente todo a partir de ahí.
*   **Impacto**: Si el autor del artículo menciona la palabra "references" de paso en la discusión o conclusiones (ej. *"As seen in previous references..."*), todo el texto posterior del artículo (que puede ser la conclusión o limitaciones de la metodología) se elimina antes de enviarse al LLM. Esto altera la capacidad del modelo para calificar ítems de las fases finales del artículo (como follow-ups, constructos o psicometría).
*   **Solución Recomendada**: Ajustar el patrón de fallback para que busque estas palabras únicamente cuando representen encabezados claros de sección (por ejemplo, precedidos por saltos de línea o con numeraciones opcionales, en lugar de cualquier coincidencia en medio de un párrafo).

---

## 4. Auditoría de Seguridad y Gestión de Claves

*   **Puntos Fuertes**: El diseño de la librería respecto a la seguridad de las claves de API es impecable. Sigue fielmente el principio de mínimos privilegios y almacenamiento seguro:
    *   No guarda claves dentro del paquete.
    *   Lee las variables de entorno estándar del sistema (`GEMINI_API_KEY`, `GOOGLE_GEMINI_KEY`, `OPENAI_API_KEY`).
    *   Permite la inyección en memoria a través del parámetro opcional `api_key` en las firmas de las funciones, lo cual es ideal para entornos de computación en la nube o notebooks compartidos.
*   **Recomendación**: Se sugiere advertir en la documentación que no se debe subir el archivo `.Renviron` al sistema de control de versiones si este contiene claves reales de API.

---

## 5. Pruebas y Aseguramiento de Calidad

*   **Problema**: El proyecto carece de una suite de pruebas unitarias. Sin pruebas, es extremadamente complejo asegurar que las expresiones regulares de parsing sigan funcionando correctamente si se modifica el formato de los prompts, o si se actualizan las librerías base (como `stringr` o `httr2`).
*   **Solución Recomendada**: Configurar `testthat` en el proyecto y automatizar pruebas para verificar:
    1.  Resolución inteligente de prompts (exacta, familia, versión, generic).
    2.  Limpieza de referencias sin pérdida de texto del cuerpo principal.
    3.  Parseo correcto de scores (0.0, 0.5, 1.0, 9.0) y de modas de consenso.

---

## 6. Plan de Acción y Conclusiones

Este informe de auditoría se acompaña de una serie de mejoras inmediatas aplicadas directamente sobre el código fuente para resolver los problemas críticos identificados:

1.  **Refactorización de `call_openai`** para garantizar la compatibilidad real con la API moderna de chat de OpenAI.
2.  **Robustecimiento de `extract_ordered_items`** para asegurar un parsing confiable e inmune a bloques multilinea de justificación.
3.  **Implementación de tolerancia a fallos en `run_dataset`** mediante `tryCatch` para ejecuciones por lotes robustas.
4.  **Refinamiento de la lógica de remoción de referencias** en `strip_references_section` para evitar pérdidas accidentales de texto útil de discusión.
5.  **Añadido de pruebas unitarias integrales** basadas en `testthat` para consolidar la calidad a largo plazo del software.

Con estas correcciones, `scaleLLMflow` se convierte en una herramienta altamente confiable, robusta y lista para producción en flujos de auditoría científica basados en Inteligencia Artificial.
