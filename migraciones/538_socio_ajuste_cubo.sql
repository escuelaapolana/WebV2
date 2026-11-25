-- 538 · Al hacerse socio, el Cubo se ajusta solo (25-nov-2026)
-- ---------------------------------------------------------------------------
-- Caso Bibiana: estaba en el Cubo a 50 €/mes y se hizo socia. Hubo que darle
-- el papel a mano, marcarla socia en su ficha del Cubo y bajarle la cuota en
-- un botón escondido. Andrés: «hay que hacerlo mucho más fácil».
--
-- Ahora correo-alta-aviso (que corre UNA vez, al firmarse la domiciliación)
-- lo hace solo (_shared/cubo-socio.ts) y deja aquí lo que hizo:
--   { en, rol_anadido, cubo: [{ alta_id, horario, antes, despues, estado, motivo }],
--     alerta_enviada_en }
-- Si luego el banco rechaza o devuelve los 125 €, cubo-webhook lo lee y avisa
-- a Andrés de que esa persona tiene la cuota de socio sin serlo (no la sube sola).
-- Solo la escribe/lee la clave de servicio (las Edge); no hace falta grant.

alter table public.altas_socio add column if not exists cubo_ajuste jsonb;

comment on column public.altas_socio.cubo_ajuste is
  'Lo que hizo el alta en el Cubo al firmarse (papel socio, cuota bajada). Lo usa cubo-webhook para avisar si el banco devuelve el alta. Mig 538.';
