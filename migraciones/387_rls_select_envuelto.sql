-- ============================================================
-- 387 · Rendimiento de las reglas de acceso (RLS): «(select f())»
-- ------------------------------------------------------------
-- En las políticas, una llamada sin argumentos como es_admin(), es_staff(),
-- mi_perfil_id() o auth.uid() se evaluaba UNA VEZ POR FILA (son funciones
-- SECURITY DEFINER / STABLE que Postgres no puede plegar). Envuelta en
-- «(select …)» se calcula una vez por consulta (initPlan) y se reutiliza.
-- Mismo resultado, menos trabajo (recomendación oficial de Supabase).
-- Medido (como una familia, mediana de 7, antes → después):
--   select * from atletas ≈ 340 → 20 ms; select grupo_id from atleta_grupos ≈ 750 → 105 ms.
--
-- Qué se ha tocado (generado con un script a partir de pg_policies DESPUÉS
-- de la 386 y revisado; aquí va el SQL fijo, nada dinámico):
--   · 278 políticas (246 de public + 32 de storage.objects), 481 llamadas.
--   · Funciones: auth.uid(), auth.jwt(), es_admin, es_staff, es_escuela,
--     es_junta, es_tesoreria, es_contabilidad, es_cubo_lista, ve_dinero,
--     puede_girar, mi_perfil_id, cubo_es_gestor, es_responsable_liga,
--     soy_entrenador_de_algun_grupo, soy_gestor_natacion.
--   · NO se tocan: funciones con argumentos (se quedan como están), las que
--     devuelven SETOF (mis_atletas() & cía ya van en «IN (SELECT …)»),
--     escuela_secciones() (IMMUTABLE: ya se pliega sola).
--   · ALTER POLICY solo cambia USING / WITH CHECK: comando, roles y
--     permissive/restrictive de cada política se quedan igual.
--   · Requiere la 386 aplicada antes (no toca las políticas que la 386 borra,
--     y la de cuotas_entreno ya la deja envuelta la 386).
-- ============================================================

begin;

-- El texto de las políticas se sacó con este search_path: así se vuelve a
-- leer igual (nombres de funciones y tablas sin esquema → public).
set local search_path = "$user", public, extensions;

alter policy "admin lee quien ha mirado" on public.altas_datos_vistos
  using ((select es_admin()));

alter policy "escuela lee quien ha mirado" on public.altas_datos_vistos
  using ((select es_escuela()));

alter policy "admin gestiona altas escuela" on public.altas_escuela
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "escuela gestiona las altas" on public.altas_escuela
  using ((select es_escuela()))
  with check ((select es_escuela()));

alter policy "tesoreria gestiona altas escuela" on public.altas_escuela
  using ((select es_tesoreria()))
  with check ((select es_tesoreria()));

alter policy "admin gestiona ninos del alta" on public.altas_escuela_ninos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "escuela gestiona los ninos del alta" on public.altas_escuela_ninos
  using ((select es_escuela()))
  with check ((select es_escuela()));

alter policy "tesoreria gestiona ninos del alta" on public.altas_escuela_ninos
  using ((select es_tesoreria()))
  with check ((select es_tesoreria()));

alter policy "admin gestiona altas socio" on public.altas_socio
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "tesoreria gestiona altas socio" on public.altas_socio
  using ((select es_tesoreria()))
  with check ((select es_tesoreria()));

alter policy "admin gestiona todo" on public.asistencia
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "cubo-lista pasa lista del cubo" on public.asistencia
  using (((select es_cubo_lista()) AND (grupo_id IN ( SELECT grupos.id
   FROM grupos
  WHERE (grupos.seccion = 'cubo'::text)))))
  with check (((select es_cubo_lista()) AND (grupo_id IN ( SELECT grupos.id
   FROM grupos
  WHERE (grupos.seccion = 'cubo'::text)))));

alter policy "escuela pasa lista a sus ninos" on public.asistencia
  using (((select es_escuela()) AND escuela_lleva_atleta(atleta_id)))
  with check (((select es_escuela()) AND escuela_lleva_atleta(atleta_id)));

alter policy "admin gestiona todo" on public.atleta_grupos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "coordinacion ve los de su seccion" on public.atleta_grupos
  using ((EXISTS ( SELECT 1
   FROM (perfiles p
     JOIN grupos g ON ((g.id = atleta_grupos.grupo_id)))
  WHERE ((p.email = ((select auth.jwt()) ->> 'email'::text)) AND (p.rol = 'coordinador'::text) AND (p.seccion IS NOT NULL) AND (g.seccion = p.seccion)))));

alter policy "dinero ve los grupos" on public.atleta_grupos
  using ((select ve_dinero()));

alter policy "entrenador ve a los de sus grupos" on public.atleta_grupos
  using (((grupo_id IN ( SELECT g.id
   FROM grupos g
  WHERE (g.entrenador_id = (select mi_perfil_id())))) OR soy_entrenador_de(atleta_id)));

alter policy "escuela reparte a sus ninos" on public.atleta_grupos
  using (((select es_escuela()) AND (EXISTS ( SELECT 1
   FROM grupos g
  WHERE ((g.id = atleta_grupos.grupo_id) AND (g.seccion = ANY (escuela_secciones())))))))
  with check (((select es_escuela()) AND (EXISTS ( SELECT 1
   FROM grupos g
  WHERE ((g.id = atleta_grupos.grupo_id) AND (g.seccion = ANY (escuela_secciones())))))));

alter policy "medallas ganadas las apunta el equipo" on public.atleta_medallas
  with check ((select es_staff()));

alter policy "medallas ganadas las borra admin" on public.atleta_medallas
  using ((select es_admin()));

alter policy "medallas ganadas lectura" on public.atleta_medallas
  using (((select es_staff()) OR (atleta_id IN ( SELECT mis_atletas() AS mis_atletas))));

alter policy "admin gestiona todo" on public.atletas
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "coordinacion ve atletas de su seccion" on public.atletas
  using ((EXISTS ( SELECT 1
   FROM perfiles p
  WHERE ((p.email = ((select auth.jwt()) ->> 'email'::text)) AND (p.rol = 'coordinador'::text) AND (p.seccion IS NOT NULL) AND (EXISTS ( SELECT 1
           FROM grupos g
          WHERE ((g.seccion = p.seccion) AND (g.id IN ( SELECT grupos_del_atleta(atletas.id) AS grupos_del_atleta)))))))));

alter policy "dinero ve las fichas" on public.atletas
  using ((select ve_dinero()));

alter policy "entrenador gestiona sus atletas" on public.atletas
  using ((entrenador_id = (select mi_perfil_id())))
  with check ((entrenador_id = (select mi_perfil_id())));

alter policy "entrenador ve atletas de sus grupos" on public.atletas
  using ((EXISTS ( SELECT 1
   FROM grupos g
  WHERE ((g.entrenador_id = (select mi_perfil_id())) AND (g.id IN ( SELECT grupos_del_atleta(atletas.id) AS grupos_del_atleta))))));

alter policy "escuela borra a sus ninos" on public.atletas
  using (((select es_escuela()) AND escuela_lleva_atleta(id)));

alter policy "escuela corrige a sus ninos" on public.atletas
  using (((select es_escuela()) AND escuela_lleva_atleta(id)))
  with check (((select es_escuela()) AND escuela_lleva_atleta(id) AND ((grupo_id IS NULL) OR (EXISTS ( SELECT 1
   FROM grupos g
  WHERE ((g.id = atletas.grupo_id) AND (g.seccion = ANY (escuela_secciones()))))))));

alter policy "escuela da de alta a un nino" on public.atletas
  with check (((select es_escuela()) AND (grupo_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM grupos g
  WHERE ((g.id = atletas.grupo_id) AND (g.seccion = ANY (escuela_secciones())))))));

alter policy "escuela ve a sus ninos" on public.atletas
  using (((select es_escuela()) AND escuela_lleva_atleta(id)));

alter policy "ver mis atletas" on public.atletas
  using (((perfil_id = (select mi_perfil_id())) OR (perfil_padre_id = (select mi_perfil_id())) OR (entrenador_id = (select mi_perfil_id()))));

alter policy "escuela ve las faltas de sus ninos" on public.ausencias
  using (((select es_escuela()) AND escuela_lleva_atleta(atleta_id)))
  with check (((select es_escuela()) AND escuela_lleva_atleta(atleta_id)));

alter policy "familia avisa de una falta" on public.ausencias
  with check (((atleta_id IN ( SELECT mis_atletas() AS mis_atletas)) AND (avisado_por = (select mi_perfil_id())) AND (fecha >= CURRENT_DATE)));

alter policy "familia corrige su aviso" on public.ausencias
  using (((atleta_id IN ( SELECT mis_atletas() AS mis_atletas)) AND (avisado_por = (select mi_perfil_id())) AND (fecha >= CURRENT_DATE)))
  with check (((atleta_id IN ( SELECT mis_atletas() AS mis_atletas)) AND (avisado_por = (select mi_perfil_id())) AND (fecha >= CURRENT_DATE)));

alter policy "familia retira su aviso" on public.ausencias
  using (((atleta_id IN ( SELECT mis_atletas() AS mis_atletas)) AND (avisado_por = (select mi_perfil_id())) AND (fecha >= CURRENT_DATE)));

alter policy "ver ausencias de mis atletas" on public.ausencias
  using (((select es_admin()) OR (atleta_id IN ( SELECT mis_atletas() AS mis_atletas))));

alter policy "ajustes gestiona el admin" on public.automatizaciones_ajustes
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "ajustes lee el equipo" on public.automatizaciones_ajustes
  using ((select es_staff()));

alter policy "admin gestiona" on public.avisos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona todo" on public.avisos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "veo mis toques al movil" on public.avisos_cola_movil
  using ((perfil_id = (select mi_perfil_id())));

alter policy "admin cambia avisos_config" on public.avisos_config
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "staff ve los avisos enviados" on public.avisos_enviados
  using ((select es_staff()));

alter policy "el equipo mira cuando se avisó" on public.avisos_novedades
  using ((select es_staff()));

alter policy "veo cuando me avisaron" on public.avisos_novedades_persona
  using ((perfil_id = (select mi_perfil_id())));

alter policy "cambiar mis preferencias de avisos" on public.avisos_preferencias
  using ((perfil_id = (select mi_perfil_id())))
  with check ((perfil_id = (select mi_perfil_id())));

alter policy "crear mis preferencias de avisos" on public.avisos_preferencias
  with check ((perfil_id = (select mi_perfil_id())));

alter policy "ver mis preferencias de avisos" on public.avisos_preferencias
  using ((perfil_id = (select mi_perfil_id())));

alter policy "borrar mis suscripciones de avisos" on public.avisos_suscripciones
  using ((perfil_id = (select mi_perfil_id())));

alter policy "cambiar mis suscripciones de avisos" on public.avisos_suscripciones
  using ((perfil_id = (select mi_perfil_id())))
  with check ((perfil_id = (select mi_perfil_id())));

alter policy "crear mis suscripciones de avisos" on public.avisos_suscripciones
  with check ((perfil_id = (select mi_perfil_id())));

alter policy "ver mis suscripciones de avisos" on public.avisos_suscripciones
  using ((perfil_id = (select mi_perfil_id())));

alter policy "admin gestiona biblioteca_fotos" on public.biblioteca_fotos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona los destinos" on public.buzon_destinos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "equipo lee los destinos" on public.buzon_destinos
  using ((select es_staff()));

alter policy "excepciones gestiona el admin" on public.calendario_excepciones
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "excepciones lee el equipo" on public.calendario_excepciones
  using ((select es_staff()));

alter policy "admin gestiona colaboradores" on public.colaboradores
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona todo" on public.competicion_atleta
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona" on public.competiciones
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona todo" on public.competiciones
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "confirmaciones admin gestiona" on public.confirmaciones
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "confirmaciones respuestas admin gestiona" on public.confirmaciones_respuestas
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona contactos" on public.contactos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "contactos base solo admin" on public.contactos
  using ((select es_admin()));

alter policy "admin gestiona todo" on public.contenido_secciones
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "cubo-lista ve altas del cubo" on public.cubo_altas
  using ((select es_cubo_lista()));

alter policy "cubo_altas_admin_lee" on public.cubo_altas
  using ((select es_admin()));

alter policy "cubo_altas_propia_lee" on public.cubo_altas
  using ((perfil_id = (select mi_perfil_id())));

alter policy "cubo_ausencias_propias" on public.cubo_ausencias
  using (((perfil_id = (select mi_perfil_id())) OR (select es_cubo_lista()) OR (select es_admin())));

alter policy "gestor gestiona bonos del cubo" on public.cubo_bonos
  using ((select cubo_es_gestor()))
  with check ((select cubo_es_gestor()));

alter policy "gestor gestiona clases" on public.cubo_clases
  using ((select cubo_es_gestor()))
  with check ((select cubo_es_gestor()));

alter policy "cubo_cobros_admin" on public.cubo_cobros
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "cubo_cobros_propia_lee" on public.cubo_cobros
  using ((perfil_id = (select mi_perfil_id())));

alter policy "cubo_config_cambia_admin" on public.cubo_config
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "gestor mueve el bono del cubo" on public.cubo_movimientos
  using ((select cubo_es_gestor()))
  with check ((select cubo_es_gestor()));

alter policy "cubo_pausas_lee" on public.cubo_pausas
  using (((perfil_id = (select mi_perfil_id())) OR (select es_admin()) OR (select es_cubo_lista()) OR (select cubo_es_gestor())));

alter policy "cubo_prueba_gestion" on public.cubo_prueba
  using (((select es_admin()) OR (select es_cubo_lista())))
  with check (((select es_admin()) OR (select es_cubo_lista())));

alter policy "cubo_prueba_propia" on public.cubo_prueba
  using ((perfil_id = (select mi_perfil_id())));

alter policy "cubo_prueba_asis_gestion" on public.cubo_prueba_asistencia
  using (((select es_admin()) OR (select es_cubo_lista())))
  with check (((select es_admin()) OR (select es_cubo_lista())));

alter policy "gestor gestiona reservas del cubo" on public.cubo_reservas
  using ((select cubo_es_gestor()))
  with check ((select cubo_es_gestor()));

alter policy "datos_anon_admin_lee" on public.datos_anonimizados
  using ((select es_admin()));

alter policy "dinero lee sus avisos" on public.dinero_avisos
  using (((select es_tesoreria()) OR ((select es_contabilidad()) AND ((para = 'contabilidad'::text) OR (creado_por = (select mi_perfil_id()))))));

alter policy "admin gestiona documentos" on public.documentos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "el grupo lee sus recursos" on public.documentos
  using (((visibilidad = 'grupo'::text) AND activo AND ((grupo_id IN ( SELECT mis_grupos_de_entreno() AS mis_grupos_de_entreno)) OR (grupo_id IN ( SELECT mis_grupos_de_familia() AS mis_grupos_de_familia)) OR (EXISTS ( SELECT 1
   FROM grupos g
  WHERE ((g.id = documentos.grupo_id) AND (g.entrenador_id = (select mi_perfil_id()))))))));

alter policy "admin gestiona todo" on public.ejercicios
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "el equipo tecnico anade ejercicios" on public.ejercicios
  with check ((select es_staff()));

alter policy "entrenador_ficha_admin" on public.entrenador_ficha
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "entrenador_ficha_propia" on public.entrenador_ficha
  using ((perfil_id = (select mi_perfil_id())))
  with check ((perfil_id = (select mi_perfil_id())));

alter policy "Entrenador gestiona entrenamientos" on public.entrenamientos
  using ((entrenador_id = (select auth.uid())));

alter policy "admin gestiona todo" on public.entrenamientos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "borrados gestiona el admin" on public.entrenos_auto_borrados
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "borrados lee el equipo" on public.entrenos_auto_borrados
  using ((select es_staff()));

alter policy "ver entrevista de mis atletas" on public.entrevista_inicial
  using (((select es_admin()) OR (atleta_id IN ( SELECT mis_atletas() AS mis_atletas))));

alter policy "admin gestiona historico" on public.escuela_historico
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "escuela gestiona el historico" on public.escuela_historico
  using ((select es_escuela()))
  with check ((select es_escuela()));

alter policy "Eventos visibles logueados" on public.eventos
  using (((select auth.uid()) IS NOT NULL));

alter policy "admin gestiona todo" on public.eventos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "junta gestiona eventos" on public.eventos
  using ((select es_junta()))
  with check ((select es_junta()));

alter policy "familia_inv admin" on public.familia_invitaciones
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona todo" on public.feedback_entrenamientos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "cada entrenador corrige lo suyo" on public.feedback_entrenamientos
  using ((entrenador_id = (select mi_perfil_id())))
  with check ((entrenador_id = (select mi_perfil_id())));

alter policy "cada entrenador retira lo suyo" on public.feedback_entrenamientos
  using ((entrenador_id = (select mi_perfil_id())));

alter policy "entrenador escribe a su atleta" on public.feedback_entrenamientos
  with check (((entrenador_id = (select mi_perfil_id())) AND (registro_id IN ( SELECT r.id
   FROM registros_sesion r
  WHERE soy_entrenador_de(r.atleta_id)))));

alter policy "escuela gestiona sus horarios" on public.grupo_horarios
  using (((select es_escuela()) AND (EXISTS ( SELECT 1
   FROM grupos g
  WHERE ((g.id = grupo_horarios.grupo_id) AND (g.seccion = ANY (escuela_secciones())))))))
  with check (((select es_escuela()) AND (EXISTS ( SELECT 1
   FROM grupos g
  WHERE ((g.id = grupo_horarios.grupo_id) AND (g.seccion = ANY (escuela_secciones())))))));

alter policy "horarios gestiona el admin" on public.grupo_horarios
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "horarios lee el equipo" on public.grupo_horarios
  using ((select es_staff()));

alter policy "horarios lee su grupo" on public.grupo_horarios
  using ((EXISTS ( SELECT 1
   FROM atletas a
  WHERE ((a.grupo_id = grupo_horarios.grupo_id) AND ((a.perfil_id = (select mi_perfil_id())) OR (a.perfil_padre_id = (select mi_perfil_id())))))));

alter policy "admin gestiona" on public.grupos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona todo" on public.grupos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "escuela gestiona sus grupos" on public.grupos
  using (((select es_escuela()) AND (seccion = ANY (escuela_secciones()))))
  with check (((select es_escuela()) AND (seccion = ANY (escuela_secciones()))));

alter policy "admin gestiona imagenes_web" on public.imagenes_web
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona importaciones" on public.importaciones
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona info_pagos" on public.info_pagos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "lectura info_pagos solo dinero" on public.info_pagos
  using (((select es_admin()) OR (select ve_dinero())));

alter policy "admin gestiona todo" on public.inscripciones_eventos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona invitaciones" on public.invitaciones_equipo
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "ajustes juego los cambia admin" on public.juego_ajustes
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "rangos los cambia el equipo" on public.juego_rangos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona todo" on public.lesiones_atleta
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "lesiones lectura restringida" on public.lesiones_atleta
  using (((select es_admin()) OR (atleta_id IN ( SELECT mis_atletas() AS mis_atletas))));

alter policy "liga ajustes gestiona el equipo" on public.liga_ajustes_puntos
  using ((select es_staff()))
  with check ((select es_staff()));

alter policy "liga baremo gestiona el equipo" on public.liga_baremo
  using ((select es_staff()))
  with check ((select es_staff()));

alter policy "liga categorias gestiona el equipo" on public.liga_categorias
  using ((select es_staff()))
  with check ((select es_staff()));

alter policy "junta gestiona ediciones de liga" on public.liga_ediciones
  using ((select es_junta()))
  with check ((select es_junta()));

alter policy "liga ediciones gestiona admin" on public.liga_ediciones
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "liga participaciones alta del equipo" on public.liga_participaciones
  with check (((select es_staff()) OR (select es_responsable_liga()) OR ((estado = 'pendiente'::text) AND (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE ((atletas.perfil_id = (select mi_perfil_id())) OR (atletas.perfil_padre_id = (select mi_perfil_id()))))))));

alter policy "liga participaciones borra el equipo" on public.liga_participaciones
  using (((select es_staff()) OR (select es_responsable_liga()) OR ((estado = 'pendiente'::text) AND (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE ((atletas.perfil_id = (select mi_perfil_id())) OR (atletas.perfil_padre_id = (select mi_perfil_id()))))))));

alter policy "liga participaciones cambia el equipo" on public.liga_participaciones
  using (((select es_staff()) OR (select es_responsable_liga()) OR ((estado = 'pendiente'::text) AND (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE ((atletas.perfil_id = (select mi_perfil_id())) OR (atletas.perfil_padre_id = (select mi_perfil_id()))))))))
  with check (((select es_staff()) OR (select es_responsable_liga()) OR ((estado = 'pendiente'::text) AND (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE ((atletas.perfil_id = (select mi_perfil_id())) OR (atletas.perfil_padre_id = (select mi_perfil_id()))))))));

alter policy "liga participaciones lectura" on public.liga_participaciones
  using (((select es_staff()) OR (select es_responsable_liga()) OR (atleta_id IN ( SELECT mis_atletas() AS mis_atletas))));

alter policy "liga propuestas alta" on public.liga_propuestas_prueba
  with check (((select es_staff()) OR (propuesta_por IS NULL) OR (propuesta_por = (select mi_perfil_id()))));

alter policy "liga propuestas borra" on public.liga_propuestas_prueba
  using (((select es_staff()) OR ((estado = 'pendiente'::text) AND (propuesta_por = (select mi_perfil_id())))));

alter policy "liga propuestas gestiona el equipo" on public.liga_propuestas_prueba
  using ((select es_staff()))
  with check ((select es_staff()));

alter policy "liga propuestas lectura" on public.liga_propuestas_prueba
  using (((select es_staff()) OR (propuesta_por = (select mi_perfil_id()))));

alter policy "admin gestiona mandatos" on public.mandatos_sepa
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "tesoreria gestiona mandatos" on public.mandatos_sepa
  using ((select es_tesoreria()))
  with check ((select es_tesoreria()));

alter policy "admin gestiona todo" on public.marcas_atleta
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "medallas alta del equipo" on public.medallas
  with check ((select es_staff()));

alter policy "medallas borra el equipo" on public.medallas
  using ((select es_staff()));

alter policy "medallas cambia el equipo" on public.medallas
  using ((select es_staff()))
  with check ((select es_staff()));

alter policy "medallas lectura" on public.medallas
  using ((activa OR (select es_staff())));

alter policy "admin gestiona mensajes" on public.mensajes
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona todo" on public.mensajes
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "buzon atiende quien lo tiene derivado" on public.mensajes
  using (((derivado_a IS NOT NULL) AND (derivado_a = (select mi_perfil_id()))))
  with check (((derivado_a IS NOT NULL) AND (derivado_a = (select mi_perfil_id()))));

alter policy "buzon lee quien lo tiene derivado" on public.mensajes
  using (((derivado_a IS NOT NULL) AND (derivado_a = (select mi_perfil_id()))));

alter policy "escribo yo a quien puedo" on public.mensajes_directos
  with check (((de_perfil = (select mi_perfil_id())) AND puedo_hablar_con(para_perfil)));

alter policy "retiro lo que he escrito" on public.mensajes_directos
  using ((de_perfil = (select mi_perfil_id())));

alter policy "solo los dos que hablan" on public.mensajes_directos
  using (((de_perfil = (select mi_perfil_id())) OR (para_perfil = (select mi_perfil_id()))));

alter policy "admin gestiona todo" on public.microciclos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "abonos los lleva gestor" on public.natacion_abonos
  using ((select soy_gestor_natacion()))
  with check ((select soy_gestor_natacion()));

alter policy "nat accesos escribir gestor" on public.natacion_accesos
  using ((select soy_gestor_natacion()))
  with check ((select soy_gestor_natacion()));

alter policy "nat accesos leer responsable" on public.natacion_accesos
  using (((select es_admin()) OR soy_responsable('natacion'::text) OR soy_responsable('escuela-natacion'::text)));

alter policy "natacion ausencias staff" on public.natacion_ausencias
  using (((select es_admin()) OR soy_responsable('natacion'::text) OR soy_responsable('escuela-natacion'::text)))
  with check (((select es_admin()) OR soy_responsable('natacion'::text) OR soy_responsable('escuela-natacion'::text)));

alter policy "nat franjas escribir gestor" on public.natacion_franjas
  using ((select soy_gestor_natacion()))
  with check ((select soy_gestor_natacion()));

alter policy "nat franjas leer responsable" on public.natacion_franjas
  using (((select es_admin()) OR soy_responsable('natacion'::text) OR soy_responsable('escuela-natacion'::text)));

alter policy "nat inscripciones escribir gestor" on public.natacion_inscripciones
  using ((select soy_gestor_natacion()))
  with check ((select soy_gestor_natacion()));

alter policy "nat inscripciones leer responsable" on public.natacion_inscripciones
  using (((select es_admin()) OR soy_responsable('natacion'::text) OR soy_responsable('escuela-natacion'::text)));

alter policy "natacion_lista lectura" on public.natacion_lista
  using (((select es_admin()) OR soy_responsable('natacion'::text) OR soy_responsable('escuela-natacion'::text)));

alter policy "reservas las lleva gestor" on public.natacion_reservas
  using ((select soy_gestor_natacion()))
  with check ((select soy_gestor_natacion()));

alter policy "staff borra notas privadas" on public.notas_atleta
  using (((select es_admin()) OR (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE (atletas.entrenador_id = (select mi_perfil_id()))))));

alter policy "staff corrige notas privadas" on public.notas_atleta
  using (((select es_admin()) OR (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE (atletas.entrenador_id = (select mi_perfil_id()))))))
  with check (((select es_admin()) OR (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE (atletas.entrenador_id = (select mi_perfil_id()))))));

alter policy "staff escribe notas privadas" on public.notas_atleta
  with check (((select es_admin()) OR (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE (atletas.entrenador_id = (select mi_perfil_id()))))));

alter policy "staff lee notas privadas" on public.notas_atleta
  using (((select es_admin()) OR (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE (atletas.entrenador_id = (select mi_perfil_id()))))));

alter policy "admin gestiona todo" on public.noticias
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "junta gestiona noticias" on public.noticias
  using ((select es_junta()))
  with check ((select es_junta()));

alter policy "admin gestiona todo" on public.pagos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "contabilidad actualiza recibos" on public.pagos
  using ((select puede_girar()))
  with check ((select puede_girar()));

alter policy "contabilidad gira recibos" on public.pagos
  with check ((select puede_girar()));

alter policy "contabilidad ve los recibos" on public.pagos
  using ((select ve_dinero()));

alter policy "admin gestiona catalogo de pagos" on public.pagos_articulos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin cambia pagos_config" on public.pagos_config
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin ve los avisos de stripe" on public.pagos_eventos_stripe
  using ((select es_admin()));

alter policy "ver mis pagos con tarjeta" on public.pagos_online
  using (((perfil_id = (select mi_perfil_id())) OR (atleta_id IN ( SELECT mis_atletas_bolsillo() AS mis_atletas_bolsillo)) OR (select es_admin())));

alter policy "admin gestiona" on public.palmares
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona todo" on public.palmares
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "palmares base solo admin" on public.palmares
  using ((select es_admin()));

alter policy "admin gestiona todo" on public.pedido_items
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "escuela gestiona las lineas del pedido" on public.pedido_items
  using ((select es_escuela()))
  with check ((select es_escuela()));

alter policy "admin gestiona todo" on public.pedidos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "escuela gestiona los pedidos" on public.pedidos
  using ((select es_escuela()))
  with check ((select es_escuela()));

alter policy "socio crea sus pedidos" on public.pedidos
  with check (((perfil_id = (select mi_perfil_id())) AND (estado = 'pendiente'::text) AND ((atleta_id IS NULL) OR (atleta_id IN ( SELECT mis_atletas_bolsillo() AS mis_atletas_bolsillo)))));

alter policy "socio ve sus pedidos" on public.pedidos
  using ((perfil_id = (select mi_perfil_id())));

alter policy "perfil juego alta" on public.perfil_juego
  with check ((soy_staff_de_atleta(atleta_id) OR (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE ((atletas.perfil_id = (select mi_perfil_id())) OR (atletas.perfil_padre_id = (select mi_perfil_id())))))));

alter policy "perfil juego borra el equipo" on public.perfil_juego
  using ((select es_admin()));

alter policy "perfil juego cambia" on public.perfil_juego
  using ((soy_staff_de_atleta(atleta_id) OR (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE ((atletas.perfil_id = (select mi_perfil_id())) OR (atletas.perfil_padre_id = (select mi_perfil_id())))))))
  with check ((soy_staff_de_atleta(atleta_id) OR (atleta_id IN ( SELECT atletas.id
   FROM atletas
  WHERE ((atletas.perfil_id = (select mi_perfil_id())) OR (atletas.perfil_padre_id = (select mi_perfil_id())))))));

alter policy "perfil juego lectura" on public.perfil_juego
  using (((select es_staff()) OR (atleta_id IN ( SELECT mis_atletas() AS mis_atletas))));

alter policy "admin gestiona todo" on public.perfiles
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "dinero lee perfiles" on public.perfiles
  using ((select ve_dinero()));

alter policy "escritura_propia" on public.perfiles
  using (((select auth.uid()) = id));

alter policy "insertar_perfil" on public.perfiles
  with check (((select auth.uid()) = id));

alter policy "lectura_propia" on public.perfiles
  using (((select auth.uid()) = id));

alter policy "leer mi perfil" on public.perfiles
  using ((email = ((select auth.jwt()) ->> 'email'::text)));

alter policy "staff lee al equipo tecnico" on public.perfiles
  using (((select es_staff()) AND (rol = ANY (ARRAY['admin'::text, 'coordinador'::text, 'entrenador'::text]))));

alter policy "el club gestiona las peticiones" on public.peticiones_redes
  using (((select es_admin()) OR (select es_staff())))
  with check (((select es_admin()) OR (select es_staff())));

alter policy "el club ve todas las peticiones" on public.peticiones_redes
  using (((select es_admin()) OR (select es_staff())));

alter policy "propongo una peticion mia" on public.peticiones_redes
  with check ((solicitante_id = (select mi_perfil_id())));

alter policy "veo mis peticiones" on public.peticiones_redes
  using ((solicitante_id = (select mi_perfil_id())));

alter policy "pista_pruebas admin" on public.pista_pruebas
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "pista_pruebas staff" on public.pista_pruebas
  using ((select es_staff()))
  with check ((select es_staff()));

alter policy "admin gestiona todo" on public.plantillas_bloque
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona plantillas email" on public.plantillas_email
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "equipo lee plantillas activas" on public.plantillas_email
  using (((select es_staff()) AND activa));

alter policy "admin gestiona todo" on public.plantillas_microciclo
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona plantillas de semana" on public.plantillas_semana
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "autor gestiona sus plantillas de semana" on public.plantillas_semana
  using ((creado_por = (select mi_perfil_id())))
  with check ((creado_por = (select mi_perfil_id())));

alter policy "equipo tecnico lee plantillas de semana" on public.plantillas_semana
  using ((select es_staff()));

alter policy "Productos visibles logueados" on public.productos
  using ((((select auth.uid()) IS NOT NULL) AND (activo = true)));

alter policy "admin gestiona todo" on public.productos
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "escuela gestiona el catalogo" on public.productos
  using ((select es_escuela()))
  with check ((select es_escuela()));

alter policy "admin gestiona pruebas" on public.pruebas
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona" on public.records_club
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona todo" on public.records_club
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "records base solo admin" on public.records_club
  using ((select es_admin()));

alter policy "admin gestiona todo" on public.registros_sesion
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona renovaciones" on public.renovaciones
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "tesoreria gestiona renovaciones" on public.renovaciones
  using ((select es_tesoreria()))
  with check ((select es_tesoreria()));

alter policy "responsables los lleva el admin" on public.responsable_seccion
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "veo mis responsabilidades" on public.responsable_seccion
  using ((perfil_id = (select mi_perfil_id())));

alter policy "logros lectura" on public.reto_logros
  using (((select es_staff()) OR (atleta_id IN ( SELECT mis_atletas() AS mis_atletas))));

alter policy "logros los apunta el equipo" on public.reto_logros
  with check ((select es_staff()));

alter policy "logros los borra admin" on public.reto_logros
  using ((select es_admin()));

alter policy "logros los cambia el equipo" on public.reto_logros
  using ((select es_staff()))
  with check ((select es_staff()));

alter policy "retos alta del equipo" on public.retos
  with check ((select es_staff()));

alter policy "retos borra el equipo" on public.retos
  using ((select es_staff()));

alter policy "retos cambia el equipo" on public.retos
  using ((select es_staff()))
  with check ((select es_staff()));

alter policy "retos lectura" on public.retos
  using ((activo OR (select es_staff())));

alter policy "admin gestiona todo" on public.rm_atleta
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona el texto del mandato" on public.sepa_mandato_texto
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona apuntados" on public.sesion_inscripciones
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "admin gestiona todo" on public.sesiones
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "el atleta apunta lo suyo" on public.sesiones
  with check (((origen = 'atleta'::text) AND (publicada = true) AND (creado_por = (select mi_perfil_id())) AND (COALESCE(abierta_inscripcion, false) = false) AND (atletas_ids IS NOT NULL) AND (array_length(atletas_ids, 1) = 1) AND (atletas_ids[1] IN ( SELECT mis_atletas_entreno() AS mis_atletas_entreno))));

alter policy "el atleta borra lo suyo" on public.sesiones
  using (((origen = 'atleta'::text) AND (creado_por = (select mi_perfil_id()))));

alter policy "el atleta corrige lo suyo" on public.sesiones
  using (((origen = 'atleta'::text) AND (creado_por = (select mi_perfil_id()))))
  with check (((origen = 'atleta'::text) AND (creado_por = (select mi_perfil_id())) AND (atletas_ids IS NOT NULL) AND (array_length(atletas_ids, 1) = 1) AND (atletas_ids[1] IN ( SELECT mis_atletas_entreno() AS mis_atletas_entreno))));

alter policy "entrenador gestiona sesiones de su grupo" on public.sesiones
  using ((grupo_id IN ( SELECT grupos.id
   FROM grupos
  WHERE (grupos.entrenador_id = (select mi_perfil_id())))))
  with check ((grupo_id IN ( SELECT grupos.id
   FROM grupos
  WHERE (grupos.entrenador_id = (select mi_perfil_id())))));

alter policy "admin gestiona todo" on public.solicitudes_inscripcion
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "escuela atiende solicitudes" on public.solicitudes_inscripcion
  using ((select es_escuela()))
  with check ((select es_escuela()));

alter policy "admin gestiona tarifas" on public.tarifas
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "tesoreria gestiona tarifas" on public.tarifas
  using ((select es_tesoreria()))
  with check ((select es_tesoreria()));

alter policy "tests bateria alta del equipo" on public.test_baterias
  with check ((select es_staff()));

alter policy "tests bateria borra admin" on public.test_baterias
  using ((select es_admin()));

alter policy "tests bateria cambia el equipo" on public.test_baterias
  using ((select es_staff()))
  with check ((select es_staff()));

alter policy "tests resultado alta" on public.test_resultados
  with check ((conf_soy_su_staff(atleta_id) OR (select es_tesoreria()) OR ((atleta_id IN ( SELECT mis_atletas() AS mis_atletas)) AND veo_bateria(bateria_id))));

alter policy "tests resultado borra admin" on public.test_resultados
  using ((select es_admin()));

alter policy "tests resultado cambia" on public.test_resultados
  using ((conf_soy_su_staff(atleta_id) OR (select es_tesoreria()) OR (atleta_id IN ( SELECT mis_atletas() AS mis_atletas))))
  with check ((conf_soy_su_staff(atleta_id) OR (select es_tesoreria()) OR ((atleta_id IN ( SELECT mis_atletas() AS mis_atletas)) AND veo_bateria(bateria_id))));

alter policy "tests resultado lectura" on public.test_resultados
  using ((conf_soy_su_staff(atleta_id) OR (select es_tesoreria()) OR (atleta_id IN ( SELECT mis_atletas() AS mis_atletas))));

alter policy "admin gestiona textos_web" on public.textos_web
  using ((select es_admin()))
  with check ((select es_admin()));

alter policy "Admin gestiona imagenes web" on storage.objects
  using (((bucket_id = ANY (ARRAY['imagenes'::text, 'imagenes-club'::text, 'productos-tienda'::text, 'noticias'::text, 'Imagenes-club'::text, 'Productos-tienda'::text])) AND (select es_admin())))
  with check (((bucket_id = ANY (ARRAY['imagenes'::text, 'imagenes-club'::text, 'productos-tienda'::text, 'noticias'::text, 'Imagenes-club'::text, 'Productos-tienda'::text])) AND (select es_admin())));

alter policy "Documentos de socios: lectura con cuenta" on storage.objects
  using (((bucket_id = 'documentos-socios'::text) AND (EXISTS ( SELECT 1
   FROM documentos d
  WHERE (d.activo AND (d.archivo_url = objects.name) AND ((d.visibilidad = ANY (ARRAY['publico'::text, 'socios'::text])) OR ((d.visibilidad = 'grupo'::text) AND ((d.grupo_id IN ( SELECT mis_grupos_de_entreno() AS mis_grupos_de_entreno)) OR (d.grupo_id IN ( SELECT mis_grupos_de_familia() AS mis_grupos_de_familia)) OR (EXISTS ( SELECT 1
           FROM grupos g
          WHERE ((g.id = d.grupo_id) AND (g.entrenador_id = (select mi_perfil_id())))))))))))));

alter policy "Documentos de socios: los gestiona admin" on storage.objects
  using (((bucket_id = 'documentos-socios'::text) AND (select es_admin())))
  with check (((bucket_id = 'documentos-socios'::text) AND (select es_admin())));

alter policy "Equipo gestiona fotos de atletas" on storage.objects
  using (((bucket_id = ANY (ARRAY['fotos-atletas'::text, 'Fotos-atletas'::text])) AND (select es_staff())))
  with check (((bucket_id = ANY (ARRAY['fotos-atletas'::text, 'Fotos-atletas'::text])) AND (select es_staff())));

alter policy "Fotos de atletas solo equipo" on storage.objects
  using (((bucket_id = ANY (ARRAY['fotos-atletas'::text, 'Fotos-atletas'::text])) AND (select es_staff())));

alter policy "admin sube imagenes" on storage.objects
  using (((bucket_id = 'imagenes'::text) AND (select es_admin())))
  with check (((bucket_id = 'imagenes'::text) AND (select es_admin())));

alter policy "altas-doc: candado borrado" on storage.objects
  using (((bucket_id <> 'altas-documentos'::text) OR (select es_admin())));

alter policy "altas-doc: candado cambio" on storage.objects
  using (((bucket_id <> 'altas-documentos'::text) OR (select es_admin())));

alter policy "altas-doc: candado lectura" on storage.objects
  using (((bucket_id <> 'altas-documentos'::text) OR (select es_admin())));

alter policy "altas-doc: solo admin gestiona" on storage.objects
  using (((bucket_id = 'altas-documentos'::text) AND (select es_admin())))
  with check (((bucket_id = 'altas-documentos'::text) AND (select es_admin())));

alter policy "altas-doc: solo admin lee" on storage.objects
  using (((bucket_id = 'altas-documentos'::text) AND (select es_admin())));

alter policy "entrenador borra sus subidas" on storage.objects
  using (((bucket_id = 'documentos-socios'::text) AND (owner = (select auth.uid())) AND (select soy_entrenador_de_algun_grupo())));

alter policy "entrenador sube recursos de grupo" on storage.objects
  with check (((bucket_id = 'documentos-socios'::text) AND (select soy_entrenador_de_algun_grupo())));

alter policy "foto perfil la borra su dueno" on storage.objects
  using (((bucket_id = 'fotos-perfil'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));

alter policy "foto perfil la cambia su dueno" on storage.objects
  using (((bucket_id = 'fotos-perfil'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)))
  with check (((bucket_id = 'fotos-perfil'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));

alter policy "foto perfil la sube su dueno" on storage.objects
  with check (((bucket_id = 'fotos-perfil'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));

alter policy "foto perfil la ve quien tiene sesion" on storage.objects
  using (((bucket_id = 'fotos-perfil'::text) AND (((storage.foldername(name))[1] = ((select auth.uid()))::text) OR (select es_staff()))));

alter policy "fotos-perfil: sin cuenta no se ve" on storage.objects
  using (((bucket_id <> 'fotos-perfil'::text) OR ((select auth.uid()) IS NOT NULL)));

alter policy "fotos-perfil: solo el dueno borra" on storage.objects
  using (((bucket_id <> 'fotos-perfil'::text) OR ((storage.foldername(name))[1] = ((select auth.uid()))::text)));

alter policy "fotos-perfil: solo el dueno cambia" on storage.objects
  using (((bucket_id <> 'fotos-perfil'::text) OR ((storage.foldername(name))[1] = ((select auth.uid()))::text)))
  with check (((bucket_id <> 'fotos-perfil'::text) OR ((storage.foldername(name))[1] = ((select auth.uid()))::text)));

alter policy "fotos-perfil: solo el dueno sube" on storage.objects
  with check (((bucket_id <> 'fotos-perfil'::text) OR ((storage.foldername(name))[1] = ((select auth.uid()))::text)));

alter policy "liga justificantes borra el autor y el equipo" on storage.objects
  using (((bucket_id = 'liga-justificantes'::text) AND ((select es_staff()) OR ((storage.foldername(name))[1] = ((select auth.uid()))::text))));

alter policy "liga justificantes sube el autor" on storage.objects
  with check (((bucket_id = 'liga-justificantes'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));

alter policy "liga justificantes ve el autor y el equipo" on storage.objects
  using (((bucket_id = 'liga-justificantes'::text) AND ((select es_staff()) OR ((storage.foldername(name))[1] = ((select auth.uid()))::text))));

alter policy "propuesta redes la borran su autor y admin" on storage.objects
  using (((bucket_id = 'propuestas-redes'::text) AND ((select es_admin()) OR ((storage.foldername(name))[1] = ((select auth.uid()))::text))));

alter policy "propuesta redes la cambia su autor" on storage.objects
  using (((bucket_id = 'propuestas-redes'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)))
  with check (((bucket_id = 'propuestas-redes'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));

alter policy "propuesta redes la sube su autor" on storage.objects
  with check (((bucket_id = 'propuestas-redes'::text) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text)));

alter policy "propuesta redes la ven su autor y el club" on storage.objects
  using (((bucket_id = 'propuestas-redes'::text) AND ((select es_staff()) OR ((storage.foldername(name))[1] = ((select auth.uid()))::text))));

alter policy "propuestas-redes: borra el autor o admin" on storage.objects
  using (((bucket_id <> 'propuestas-redes'::text) OR (((select auth.uid()) IS NOT NULL) AND ((select es_admin()) OR ((storage.foldername(name))[1] = ((select auth.uid()))::text)))));

alter policy "propuestas-redes: la ven el autor y el club" on storage.objects
  using (((bucket_id <> 'propuestas-redes'::text) OR (((select auth.uid()) IS NOT NULL) AND ((select es_staff()) OR ((storage.foldername(name))[1] = ((select auth.uid()))::text)))));

alter policy "propuestas-redes: solo el autor cambia" on storage.objects
  using (((bucket_id <> 'propuestas-redes'::text) OR (((select auth.uid()) IS NOT NULL) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text))))
  with check (((bucket_id <> 'propuestas-redes'::text) OR (((select auth.uid()) IS NOT NULL) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text))));

alter policy "propuestas-redes: solo el autor sube" on storage.objects
  with check (((bucket_id <> 'propuestas-redes'::text) OR (((select auth.uid()) IS NOT NULL) AND ((storage.foldername(name))[1] = ((select auth.uid()))::text))));

-- Comprobación: no queda ninguna llamada sin envolver de estas funciones en
-- las políticas de public y storage (si quedara alguna, se para y no se
-- aplica nada).
do $$
declare n int;
begin
  select count(*) into n
    from pg_policies
   where schemaname in ('public', 'storage')
     and regexp_replace(coalesce(qual,'') || ' ' || coalesce(with_check,''),
                        '\( SELECT [a-z_.]+\(\) AS [a-z_]+\)', '', 'g')
         ~ '(^|[^a-z_.])(auth\.uid|auth\.jwt|auth\.email|cubo_es_gestor|es_admin|es_contabilidad|es_cubo_lista|es_escuela|es_junta|es_responsable_liga|es_staff|es_tesoreria|mi_perfil_id|puede_girar|soy_entrenador_de_algun_grupo|soy_gestor_natacion|ve_dinero)\(\)';
  if n > 0 then
    raise exception '387: quedan % políticas con llamadas sin envolver', n;
  end if;
  raise notice '387: todas las llamadas sin argumentos van envueltas en (select …)';
end $$;

commit;
