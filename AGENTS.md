# AGENTS.md — Guía para agentes y mantenimiento del proyecto

Este documento es la referencia operativa para cualquier persona o agente que modifique los workflows, los scripts o la documentación de **N8N Blog**. Está pensado para que un cambio futuro no rompa el archivado, el dedup ni la publicación.

> **Alcance:** workflows de n8n exportados a JSON, scripts de apoyo en Python/Node, SQL de Supabase y documentación. No es una aplicación web ni un backend tradicional.
>
> **Relación con otras guías:** `.github/copilot-instructions.md` contiene reglas generales para Copilot. Este archivo contiene las reglas específicas del proyecto y **prevalece** cuando hay conflicto sobre cómo tocar workflows, datos o credenciales.

---

## 1. Principios no negociables

Estas reglas protegen datos de producción. No las cambies sin autorización explícita y sin actualizar la documentación.

1. **Los pendientes nunca se archivan ni se borran.** Un post con `Estado = No creado`, `Estado` vacío o sin `Temas` no entra en ningún lote de archivado.
2. **No se borra nada de Airtable sin verificarlo antes en Supabase.** El orden es obligatorio: insertar → verificar → borrar. Si la verificación falla, no se borra.
3. **El único `DELETE` permitido es el del nodo `Borrar en Airtable`** del workflow de mantenimiento, en lotes de 10 y solo con ids verificados.
4. **No se usa el nodo Airtable con operación `delete`.** El borrado va por HTTP REST para controlar el lote y la verificación.
5. **No se ejecuta SQL destructivo en Supabase** (`DELETE`, `TRUNCATE`, `DROP`, `UPDATE`) desde n8n. El mantenimiento solo hace `INSERT ... ON CONFLICT DO NOTHING` y `SELECT`.
6. **No se actualizan Posts desde n8n** salvo el `DELETE` verificado del mantenimiento. El resto de escrituras son altas de temas y cambios de `Estado`/`WP Post ID` desde el flujo editorial.
7. **No se hardcodean secretos nuevos.** Si un nodo necesita una API key, se crea una credencial de n8n. Las claves existentes de Pexels y Tavily son deuda técnica a migrar.
8. **No se renombran nodos sin actualizar todas las expresiones.** n8n referencia nodos por nombre (`$('Nombre del nodo')`).
9. **Los JSON se guardan en UTF-8 sin BOM.** Un guardado en ANSI/Windows-1252 produce mojibake y puede romper nombres de nodos y expresiones.
10. **La fuente de verdad en ejecución es n8n, no el repo.** El repo debe reflejar lo que está desplegado, no al revés.

---

## 2. Fuente de verdad y ciclo de cambio

```text
n8n (ejecución)
   │ exportar
   ▼
JSON raíz (fuente local versionada)
   │ copiar sin id + active=false
   ▼
import/ (copia para importar en otro entorno)
```

### Regla de oro

Antes de modificar un workflow:

1. Exporta el workflow actual desde n8n.
2. Reemplaza el JSON de la raíz.
3. Ejecuta los tests y la validación.
4. Si el cambio es desplegable, actualiza también la copia de `import/` (sin `id`, con `active: false`).
5. Documenta el cambio en el README o en el plan correspondiente.
6. Commitea **antes** de importar en n8n.

### Qué va en cada archivo

| Archivo | Contenido | Se puede importar |
|---|---|---|
| `<Workflow>.json` (raíz) | Workflow completo; puede incluir `id` y `active`. Los generados por `build_workflows.py` no tienen `id`. | Sí, pero sobrescribe si el `id` coincide. |
| `import/<Workflow>.json` | Misma lógica, sin `id` y con `active: false`. | Sí, como workflow nuevo. |
| `backups/Backup_DD_MM_AA/` | Snapshot histórico. | Solo para restaurar. |

---

## 3. Mapa del repositorio

| Ruta | Qué contiene | Se toca |
|---|---|---|
| `Blogs Analista.json` | Análisis de webs, generación de temas y dedup. | Con cuidado: usa Supabase y Airtable en lectura. |
| `Blogs Principal.json` | Redacción, imágenes, taxonomías y publicación. | Con cuidado: es el flujo más largo. |
| `Mantenimiento Posts.json` | Archivado mensual y borrado verificado. | **Máxima precaución.** |
| `Supabase Keepalive.json` | `SELECT 1` semanal. | Poco probable. |
| `Publicar Programados.json` | Publicación de borradores programados. | Revisar solapamiento con Principal. |
| `Subflow_*.json` | Redactor, Editor, Imágenes, Taxonomías. | Contratos de entrada/salida estables. |
| `import/` | Copias para importar. | Mantener sincronizadas con la raíz. |
| `sql/posts_archivo.sql` | DDL, índices, RLS y vistas. | Solo cambios aditivos. |
| `scripts/` | Generadores, diagnóstico y tests. | Sí, con tests. |
| `docs/` | Planes y guías. | Sí, al cambiar comportamiento. |
| `datos/` | CSV de muestra y esquema. | No commitear datos de producción actualizados. |
| `backups/` | Snapshots. | No editar; solo agregar. |
| `Fragmentos de código php.../` | Snippets de Yoast para REST. | Solo si cambia la integración con WordPress. |

---

## 4. Convenciones técnicas

### JSON de n8n

- **Codificación:** UTF-8 sin BOM.
- **Indentación:** 2 espacios (la que exporta n8n).
- **Orden:** no reordenar nodos ni conexiones si no es necesario; genera diffs enormes.
- **Nombres de nodos:** estables, en español, sin duplicados. Se usan en expresiones.
- **`executionOrder`:** `v1`.
- **Zona horaria:** `America/Caracas` en los workflows que la declaran (mantenimiento y keepalive).
- **IDs de nodo:** no reutilizar ids entre nodos.
- **Posiciones:** no hace falta mantenerlas perfectas, pero evita solapamientos si vas a revisar el flujo en la UI.

### Expresiones y Code nodes

- No cambies el nombre de un nodo sin buscar todas las referencias:

```bash
# Buscar referencias por nombre de nodo
grep -R "\$('Nombre del nodo')" --include="*.json" .
```

- Si cambias la salida de un Code node, revisa todos los nodos aguas abajo y los tests.
- Los Code nodes deben seguir siendo **deterministas** y no hacer llamadas de red.
- No agregues `console.log` permanente en producción; usa el nodo de diagnóstico o un `NoOp` temporal.
- Evita `any`/`unknown` sin narrowing en el código TypeScript de las skills; en los Code nodes de n8n (JavaScript) aplica el mismo criterio de claridad.

### Fechas y zonas

- Las fechas de negocio se comparan en `America/Caracas`.
- `$now.setZone('America/Caracas').toFormat('yyyy-MM-dd')` es el patrón usado.
- No uses `new Date()` sin zona en lógica de elegibilidad.

### Umbrales

Los umbrales del mantenimiento están centralizados en el nodo `Configuración`:

| Parámetro | Valor actual |
|---|---:|
| `umbral` | 900 |
| `objetivo` | 750 |
| `diasError` | 90 |
| `avisoPorEncimaDe` | 950 |

Si cambias uno, actualiza:
- `docs/PLAN_ARCHIVADO_POSTS.md`
- `README.md` (secciones 5.1 y 8)
- `scripts/test_mantenimiento.js` si el test asume el valor.

---

## 5. Cómo cambiar un workflow (procedimiento)

1. **Lee el contexto.** Abre el workflow y el plan correspondiente. No asumas la intención.
2. **Crea una rama o copia de trabajo.** Si no hay Git, duplica el JSON a `backups/` antes de tocarlo.
3. **Edita el JSON** (o usa los scripts generadores, con las precauciones de la sección 7).
4. **Valida la estructura:**

```bash
python scripts/validate_workflows.py
```

5. **Ejecuta los tests de lógica:**

```bash
node scripts/test_mantenimiento.js
node scripts/test_auto_delete.js
node scripts/test_dedup.js
```

6. **Revisa el diff completo.** Busca:
   - nodos eliminados por accidente,
   - conexiones huérfanas,
   - expresiones que apunten a nombres viejos,
   - credenciales con id placeholder,
   - claves hardcodeadas.
7. **Actualiza `import/`** si el cambio debe poder importarse en un entorno limpio.
8. **Actualiza la documentación.** Como mínimo, `README.md` si cambia comportamiento, credenciales, umbrales o triggers.
9. **Commit con convención** (sección 9).
10. **Importa en n8n y prueba en un entorno controlado.** No actives a ciegas.
11. **Etiqueta el release** si es un hito estable.

### Si el cambio es en el mantenimiento

Además de lo anterior:

- No toques el orden `Insertar → Verificar → Preparar → Borrar`.
- No elimines `Verificar en Supabase`.
- No cambies `records[]` por un `DELETE` masivo.
- No incluyas estados pendientes en `archivable`.
- Prueba con un umbral bajo en un entorno de prueba y datos ficticios.
- Verifica que `skipped` se reporte y que el mensaje de Telegram sea correcto.

### Si el cambio es en el Analista

- Mantén la lectura de títulos vivos **y** archivados.
- Si agregas una fuente de títulos, normaliza la URL igual (`trim`, sin `/` final, minúsculas).
- No metas la lista de títulos en el prompt sin límite: puede explotar el contexto. Si crece, resume o filtra por últimos N.
- Recuerda que el Analista corre cada 3 días y crea hasta 8 temas por web; un error de filtro llena Airtable rápido.

### Si el cambio es en el Redactor/Editor

- Mantén el contrato de salida: `title`, `content`, `slug`, `excerpt`, `focusKeyphrase`, `categoryNames`, `tags`, `seoMetaTitle`, `seoMetaDescription`.
- No rompas el parser tolerante a JSON malformado.
- Prueba con una plantilla forzada y con `Auto`.
- Revisa que `Temática específica` e `Intención del artículo` sigan teniendo precedencia.

---

## 6. Contratos de los subflows

No cambies estos campos sin actualizar `Blogs Principal` y el README.

### Redactor

**Entrada:** `topic`, `briefing`, `brandContext`, `categoriesInput`, `language`, `siteUrl`, `postsIndex`, `sourcesIndex`, `templateForzado`, `modoCustom`, `tematicaEspecifica`, `tipoEscritura`, `estiloRedaccion`, `intencionArticulo`.

**Salida:** `title`, `content`, `slug`, `excerpt`, `focusKeyphrase`, `categoryNames`, `tags`, `targetLanguage`, `languageValid`, `languageSource`, `seoMetaTitle`, `seoMetaDescription`.

### Editor

**Entrada:** el JSON/texto del artículo.

**Salida:** mismo contrato que el Redactor.

### Imágenes

**Entrada:** `siteUrl`, `wpUser`, `wpPassword`, `topic`, `title`, `content`.

**Salida:** `content` (con figura inline), `featuredMediaId`, `headerAuthRaw`, `excerpt`.

### Taxonomías

**Entrada:** `siteUrl`, `wpUser`, `wpPassword`, `categoryNames`, `tags`.

**Salida:** `final_ids`, `final_tag_ids`, `headerAuthRaw`.

---

## 7. Scripts generadores: precauciones

Estos scripts **modifican** los JSON de la raíz. No son seguros de ejecutar a ciegas:

| Script | Efecto | Precaución |
|---|---|---|
| `scripts/build_workflows.py` | **Sobrescribe** `Mantenimiento Posts.json` y `Supabase Keepalive.json`. | Ejecutar solo si quieres regenerarlos desde cero. Perderás cambios manuales. |
| `scripts/auto_delete_posts.py` | Añade la rama de borrado al mantenimiento. | Puede duplicar nodos si se ejecuta dos veces. Revisar diff. |
| `scripts/add_dedup_analista.py` | Inserta nodos de dedup en el Analista. | Idempotencia no garantizada. Revisar diff. |
| `scripts/add_archived_dedup.py` | Añade la consulta a Supabase. | Idem. |
| `scripts/analizar_posts.py` | Solo lectura del CSV. | Seguro. |
| `scripts/validate_workflows.py` | Solo lectura/validación. | Seguro. |
| `scripts/inspect_workflow.py` | Solo lectura. | Seguro. |

**Antes de ejecutar un generador:**

```bash
git status            # debe estar limpio
cp "Mantenimiento Posts.json" "backups/tmp_mantenimiento.json"
python scripts/build_workflows.py
git diff --stat
```

Si no hay Git, haz una copia manual con fecha.

---

## 8. Tests y validación

### Comandos obligatorios antes de cerrar un cambio

```bash
node scripts/test_mantenimiento.js
node scripts/test_auto_delete.js
node scripts/test_dedup.js
python scripts/validate_workflows.py
```

### Qué valida cada uno

- `test_mantenimiento.js`: umbral, objetivo, errores antiguos, pendientes intactos, orden por antigüedad.
- `test_auto_delete.js`: lotes de 10, solo ids verificados, `skipped`, conteo.
- `test_dedup.js`: normalización y unión de títulos vivos/archivados.
- `validate_workflows.py`: JSON válido, conexiones existentes, `DELETE` solo en el nodo permitido, sin SQL destructivo, verificación en Supabase.

### Si agregas un test

- Usa Node.js sin dependencias externas (los tests actuales solo usan `fs` y `path`).
- Lee el JSON real del repo; no dupliques la lógica en el test.
- Cubre el caso feliz y al menos un caso de borde (vacío, sin fecha, estado pendiente).
- Documenta el comando en el README.

---

## 9. Git y commits

### Formato

Convención del proyecto (ver `.github/skills/shared/SKILL.md`):

```text
<type>(<scope>): <short description>
```

- `type`: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `style`, `perf`, `ci`.
- `scope`: módulo o workflow afectado (`analista`, `principal`, `mantenimiento`, `supabase`, `docs`).
- Descripción en inglés, imperativa, minúscula, sin punto final.

Ejemplos:

```text
feat(mantenimiento): verify ids in supabase before delete
fix(analista): include archived titles in dedup prompt
docs(readme): document api keys and rotation
test(mantenimiento): cover error older than 90 days
```

### Reglas

- Un commit por cambio lógico. No mezcles workflows y documentación no relacionada.
- No commitees secretos, CSV de producción ni `.env`.
- No commitees `__pycache__/` ni `*.pyc`.
- Si el cambio se despliega en n8n, el commit debe existir **antes** del despliegue.
- Usa tags para releases estables: `v2026.10.30-archivado`.

### Si aún no hay repositorio

1. `git init`
2. Crear `.gitignore` (ver README, sección 14).
3. Primer commit con el estado actual.
4. Tag del estado desplegado.
5. Remoto privado (cuenta del cliente/organización, no personal).

---

## 10. Credenciales y secretos

### Reglas

- **Nunca** agregues una API key en un `jsCode`, `jsonBody`, header o URL.
- Usa credenciales de n8n (Header Auth, Query Auth, OAuth2, Postgres, etc.).
- No imprimas credenciales completas en logs, issues, capturas ni documentación.
- No commitees `.env` ni exports que contengan tokens.
- Si encuentras un secreto hardcodeado, no lo repitas en el PR: repórtalo y rótalo.

### Inventario actual

| Servicio | Dónde vive | Acción pendiente |
|---|---|---|
| Airtable | Credencial `Airtable Synergiart` | Ninguna. |
| OpenAI | Credencial `OpenAI Synergiart` | Ninguna. |
| Pinecone | Credencial `Pinecone Synergiart` | Sin uso: RAG retirado de `Blogs Principal`; solo si se reactiva. |
| Telegram | Credenciales `Telegram Benjamin` / `Telegram Eduardo` | Mover `chatId` a variable si cambia el equipo. |
| Supabase | Credencial `Supabase Archive` | Ninguna. |
| WordPress | Campos `Usuario WP` / `WP password` en Airtable | Rotar Application Passwords periódicamente. |
| Tavily | **Hardcodeada** en `Blogs Principal.json` | Mover a credencial y rotar. |
| Pexels | **Hardcodeada** en `Subflow_imagenes_blog.json` | Mover a credencial y rotar. |

### Al importar

Revisa la checklist de [README, sección 6.3](./README.md#63-checklist-al-importar). El placeholder `REEMPLAZAR_POR_ID` aparece en los JSON exportados (raíz e `import/`) y es intencional: obliga a reseleccionar la credencial.

---

## 11. Documentación obligatoria

| Si cambias… | Actualiza… |
|---|---|
| Umbrales, lotes, política de borrado | `README.md` (sección 5), `docs/PLAN_ARCHIVADO_POSTS.md`, tests. |
| Triggers o frecuencias | `README.md` (secciones 3 y 8). |
| Credenciales o API keys | `README.md` (sección 6), este archivo (sección 10). |
| Campos de Airtable | `README.md` (sección 4.1), `docs/GUIA_CAMPOS_EDITORIALES.md` si es editorial. |
| Contratos de subflows | `README.md` (sección 3.6) y este archivo (sección 6). |
| Scripts | `README.md` (sección 10). |
| Tests | `README.md` (sección 11). |
| Estructura de carpetas | `README.md` (sección 12). |

La documentación debe explicar **qué hace**, **por qué** y **qué revisar si falla**. No basta con "se cambió el nodo X".

---

## 12. Checklist de revisión antes de terminar

- [ ] El JSON es válido y está en UTF-8.
- [ ] No hay nodos huérfanos ni conexiones rotas.
- [ ] No se renombró ningún nodo sin actualizar expresiones.
- [ ] No se agregaron secretos hardcodeados.
- [ ] Los pendientes siguen excluidos del archivado.
- [ ] El orden `insertar → verificar → borrar` se mantiene.
- [ ] `validate_workflows.py` pasa.
- [ ] Los tres tests de Node pasan.
- [ ] `import/` está sincronizado si corresponde.
- [ ] El README/plan está actualizado.
- [ ] El diff no incluye datos de producción ni `__pycache__`.
- [ ] El commit sigue la convención.

---

## 13. Trampas conocidas

| Trampa | Qué pasa | Cómo evitarla |
|---|---|---|
| Guardar JSON desde PowerShell sin UTF-8 | Mojibake en nombres y expresiones. | Usar `Get-Content -Encoding UTF8` / `Set-Content -Encoding UTF8` o Node/Python con UTF-8. |
| Confiar en `active` del export | El workflow real puede estar en otro estado. | Verificar en n8n. |
| Renombrar `Search records` o `Preparar borrado` | Las expresiones `$('...')` dejan de resolver. | Buscar referencias y actualizar todo. |
| Ejecutar `build_workflows.py` sobre un workflow editado a mano | Se pierden cambios. | Copia de seguridad y diff. |
| Subir el umbral para "probar" | Se archiva antes de tiempo y se borra producción. | Usar entorno de prueba y umbral bajo con datos ficticios. |
| Insertar títulos archivados sin normalizar URL | El dedup no encuentra coincidencias. | Usar la misma normalización del nodo `Adjuntar títulos`. |
| `Buscar títulos existentes` depende de `$json.URL` | Su input real es la salida de `Títulos archivados`; el filtro puede quedar vacío y traer todos los Posts (más coste, mismo resultado). | Revisar la expresión o reordenar `Webs a procesar → Buscar títulos existentes → Títulos archivados → Adjuntar títulos`. |
| Cambiar el `chatId` de Telegram | Los avisos van a otra persona o fallan. | Revisar los dos `chatId` de los nodos de Telegram (Benjamín y Eduardo). |
| Poner `Ignore SSL Issues` en otras credenciales | Riesgo de seguridad. | Solo en `Supabase Archive` por la cadena del pooler. |
| Conectar a Supabase con `db.<ref>.supabase.co` en Free | `ENETUNREACH` sobre IPv6: la conexión directa es IPv6-only y el contenedor no tiene ruta. | Usar **Session pooler** (`...pooler.supabase.com:5432`, usuario `postgres.<ref>`). Si persiste, `NODE_OPTIONS=--dns-result-order=ipv4first`. |
| `self-signed certificate in certificate chain` con Supabase | El pooler usa una cadena que n8n no confía; `SSL = Require` con `Ignore SSL Issues` apagado. | Activar **Ignore SSL Issues (Insecure)** y guardar. Para verificación estricta, montar el CA de Supabase y usar `NODE_EXTRA_CA_CERTS` + `Verify-Full`. |
| Cambiar o perder `N8N_ENCRYPTION_KEY` | n8n no puede descifrar las credenciales guardadas. | Volver a introducir cada credencial y guardar la clave en el gestor de secretos. No hay recuperación posible sin la clave original. |
| Duplicar el mantenimiento | Dos jobs borran a la vez. | Un solo workflow activo; revisar la lista de workflows. |
| Ejecutar el mantenimiento dos veces el mismo mes | El segundo no encuentra candidatos; no borra de más. | Es idempotente por diseño, pero revisa el aviso. |

---

## 14. Comportamiento esperado del agente

- **Idioma:** responder en castellano.
- **Tono:** profesional, claro y directo.
- **Iniciativa:** no asumir requisitos ambiguos; preguntar antes de cambiar la política de borrado, los umbrales o las credenciales.
- **Alcance:** no refactorizar de más. Cambios pequeños, revisables y con tests.
- **Transparencia:** si algo no se puede verificar (por ejemplo, el trigger real en n8n o la fórmula de `Próxima fecha`), decirlo y no inventarlo.
- **Seguridad:** nunca reproducir claves completas; usar `[REDACTED]` o prefijos.
- **Documentación:** cada cambio de comportamiento deja rastro en README/plan.
- **Terminado:** un cambio no está terminado hasta que pasan los tests y la documentación está actualizada.

---

## 15. Enlaces rápidos

- [README del proyecto](./README.md)
- [Plan de archivado](./docs/PLAN_ARCHIVADO_POSTS.md)
- [Plan editorial](./docs/PLAN.md)
- [Guía de campos editoriales](./docs/GUIA_CAMPOS_EDITORIALES.md)
- [DDL de Supabase](./sql/posts_archivo.sql)
- [Workflow de mantenimiento](./Mantenimiento%20Posts.json)
- [Workflow del Analista](./Blogs%20Analista.json)
- [Workflow Principal](./Blogs%20Principal.json)
- [Tests](./scripts)
