/* ============================================================
   CONEXIÓN A SUPABASE · base de datos del club
   ------------------------------------------------------------
   La clave "publishable" es PÚBLICA por diseño: va en el navegador
   y no es secreta. La seguridad de verdad la dan las reglas RLS
   configuradas en Supabase (qué puede leer/escribir cada quién).
   Requiere que la librería supabase-js se haya cargado antes.
   ============================================================ */
(function () {
  var URL = "https://icaxokjsvhlreuwpyxeb.supabase.co";
  var KEY = "sb_publishable_ABwJ5L9azzN30mqKg6igxA_zq6pB3MH";

  if (!window.supabase || !window.supabase.createClient) {
    console.warn("[Apolana] supabase-js no está cargado; la web usará los datos de ejemplo.");
    return;
  }
  window.APOLANA_DB = window.supabase.createClient(URL, KEY);

  /* Ayudante: últimas noticias publicadas (o null si algo falla). */
  window.APOLANA_DB.noticias = async function (limite) {
    try {
      var q = window.APOLANA_DB
        .from("noticias")
        .select("titulo, excerpt, categoria, foto_portada, fecha_publicacion, slug:id")
        .eq("publicada", true)
        .order("fecha_publicacion", { ascending: false });
      if (limite) q = q.limit(limite);
      var res = await q;
      if (res.error) { console.warn("[Apolana] noticias:", res.error.message); return null; }
      return res.data;
    } catch (e) {
      console.warn("[Apolana] noticias (excepción):", e);
      return null;
    }
  };
})();
