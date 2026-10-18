# Guía inicial en español

Construye e instala desde la raíz con `R CMD build .` y `R CMD INSTALL scaleLLMflow_0.4.3.tar.gz`. Configura la credencial del proveedor en `.Renviron` o en el entorno del sistema; no guardes claves en Git.

Carga el paquete, consulta `available_scales()` y ejecuta `run_article()` indicando artículo, escala, proveedor, modelo y tipo de archivo. Para varios artículos usa `run_dataset()` y, si existen puntuaciones revisadas, `validation_mode = "reference"` con `reference_csv`.

La ejecución realiza llamadas reales al proveedor: comprueba antes coste, permisos y condiciones de uso. Consulta [resultados](results.md) y [solución de problemas](troubleshooting.md).
