-- ============================================================
-- Archivo de Posts: tabla de histórico en Supabase (Postgres)
-- Ejecutar en Supabase > SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS public.posts_archivo (
  id                   bigserial PRIMARY KEY,
  airtable_id          text UNIQUE NOT NULL,
  tema                 text,
  url_sitio            text,
  estado               text,
  fecha_creacion       timestamptz,
  fecha_publicacion    timestamptz,
  fecha_especifica     date,
  template_forzado     text,
  tematica_especifica  text,
  tipo_escritura       text,
  estilo_redaccion     text,
  intencion_articulo   text,
  url_articulo         text,
  idioma               text,
  payload              jsonb,
  fecha_archivado      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_posts_archivo_fecha_pub
  ON public.posts_archivo (fecha_publicacion DESC);

CREATE INDEX IF NOT EXISTS idx_posts_archivo_sitio
  ON public.posts_archivo (url_sitio);

-- RLS activado sin políticas: solo el usuario de n8n (postgres/service_role)
-- y el dashboard pueden leer/escribir. La API anónima queda cerrada.
ALTER TABLE public.posts_archivo ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- Vistas de consulta
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.v_archivo_por_web AS
SELECT
  url_sitio,
  count(*)                        AS total,
  min(fecha_publicacion)          AS primera_publicacion,
  max(fecha_publicacion)          AS ultima_publicacion,
  max(fecha_archivado)            AS ultimo_archivado
FROM public.posts_archivo
GROUP BY url_sitio
ORDER BY total DESC;

CREATE OR REPLACE VIEW public.v_archivo_ultimos_90_dias AS
SELECT *
FROM public.posts_archivo
WHERE fecha_publicacion >= now() - interval '90 days'
ORDER BY fecha_publicacion DESC;

-- ------------------------------------------------------------
-- Consultas de ejemplo
-- ------------------------------------------------------------
-- Últimos 50 artículos archivados:
--   SELECT tema, url_sitio, fecha_publicacion
--   FROM posts_archivo
--   ORDER BY fecha_publicacion DESC NULLS LAST
--   LIMIT 50;
--
-- Buscar por tema:
--   SELECT * FROM posts_archivo
--   WHERE tema ILIKE '%palabra%';
--
-- Archivo de una web concreta:
--   SELECT * FROM posts_archivo
--   WHERE url_sitio = 'https://ejemplo.com'
--   ORDER BY fecha_publicacion DESC;
