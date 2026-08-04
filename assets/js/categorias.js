/* ============================================================
   LAS CATEGORÍAS DEL CLUB · UNA SOLA ESCALERA
   ------------------------------------------------------------
   POR QUÉ EXISTE ESTE FICHERO
   Esta cuenta estaba escrita tres veces —en Atletas, en Importar y
   en la pantalla de crear fichas desde un alta— y las tres estaban
   mal del mismo modo. Cuando una cuenta vive en tres sitios, se
   arregla en uno y se queda mal en los otros dos.

   Desde agosto de 2026 vive aquí y en ningún sitio más. La base
   hace esta misma cuenta por su cuenta, en
   `categoria_por_nacimiento` (migración 123), porque el navegador
   no puede ser la única fuente de algo que se guarda; las dos
   tienen que decir SIEMPRE lo mismo, así que si se toca una hay
   que tocar la otra.

   ------------------------------------------------------------
   LA TABLA DE LA FEDERACIÓN · NO BORRAR

   Anexo 2 de la normativa de licencias de la RFEA, temporada 2026:

       MÁSTER    desde el día en que cumple 35 años
       SÉNIOR    nacidos en 2003 o años anteriores
       SUB-23    nacidos en 2004, 2005 y 2006
       SUB-20    nacidos en 2007 y 2008
       SUB-18    nacidos en 2009 y 2010
       SUB-16    nacidos en 2011 y 2012
       SUB-14    nacidos en 2013 y 2014
       SUB-12    nacidos en 2015 y 2016
       SUB-10    nacidos en 2017 y 2018
       SUB-8     nacidos en 2019 o años posteriores

   LO QUE HAY QUE ENTENDER DE ESA TABLA, QUE ES DONDE ESTABA EL FALLO
   Las categorías van por AÑO DE NACIMIENTO, no por años cumplidos, y
   cada una junta DOS años seguidos. Eso quiere decir que dentro de
   una misma categoría conviven dos edades: los Sub-12 de 2026 son
   los que cumplen 10 y los que cumplen 11.

   La cuenta vieja cortaba en el primero de los dos —«Sub-12 hasta
   los 10»—, así que a todos los del año mayor de cada tramo los
   subía de categoría. Un niño de 2015 salía Sub-14 en vez de
   Sub-12; uno de 2011, Sub-18 en vez de Sub-16.

   Si algún día parece que aquí sobra un año, NO SOBRA: vuelve a
   leer la tabla de arriba y cuenta las dos edades de cada tramo.

   ------------------------------------------------------------
   DOS COSAS QUE NO SON UN FALLO Y NO HAY QUE «ARREGLAR»

   1 · «Escuela iniciación» no existe en la federación. Se la
       inventó el club para los más pequeños y corta a los 8 años
       cumplidos. Dónde corta lo decide el club, no esta tabla.

       De ahí sale algo que conviene tener presente: la escalera del
       club no tiene Sub-10 ni Sub-8. Los de 9 y 10 años, que para
       la federación son Sub-10, aquí caen en Sub-12 porque no hay
       otro sitio donde ponerlos. Es así desde siempre; añadir un
       Sub-10 sería una decisión del club.

   2 · Máster se cuenta por años y no por el día del cumpleaños. La
       federación dice «desde el día en que cumple 35»; aquí se pasa
       el 1 de enero del año en que los cumple. Es una aproximación
       sabida, no el fallo de arriba.
   ============================================================ */
(function () {
  'use strict';

  /* Las nueve de la ficha, en orden de pequeño a mayor. Las pantallas
     que pintan un desplegable de categorías tiran de aquí. */
  var LISTA = ['Escuela iniciación', 'Sub-12', 'Sub-14', 'Sub-16',
               'Sub-18', 'Sub-20', 'Sub-23', 'Absoluto', 'Máster'];

  /* Los cortes, en el mismo orden y con la edad que cumple en el año.
     Escrito así, como tabla y no como una escalera de «if», para que
     se pueda leer al lado de la de la federación y compararla de un
     vistazo. `hasta` es la edad MAYOR que entra en ese tramo. */
  var TRAMOS = [
    { hasta:  8, nombre: 'Escuela iniciación' },  /* del club, no de la RFEA */
    { hasta: 11, nombre: 'Sub-12' },              /* cumple 10 u 11          */
    { hasta: 13, nombre: 'Sub-14' },              /* cumple 12 o 13          */
    { hasta: 15, nombre: 'Sub-16' },              /* cumple 14 o 15          */
    { hasta: 17, nombre: 'Sub-18' },              /* cumple 16 o 17          */
    { hasta: 19, nombre: 'Sub-20' },              /* cumple 18 o 19          */
    { hasta: 22, nombre: 'Sub-23' },              /* cumple 20, 21 o 22      */
    { hasta: 34, nombre: 'Absoluto' }             /* la RFEA lo llama sénior */
  ];
  var DE_AHI_EN_ADELANTE = 'Máster';

  /* La categoría de quien nació en esa fecha, hoy.
     Se cuenta con los AÑOS y nada más: cuántos cumple en este año
     natural. Nadie cambia de categoría el día de su cumpleaños, así
     que meter aquí el mes y el día sería meter un fallo. */
  function porNacimiento(fecha) {
    if (!fecha) return '';
    var anio = parseInt(String(fecha).slice(0, 4), 10);
    if (!anio) return '';
    var cumple = new Date().getFullYear() - anio;
    for (var i = 0; i < TRAMOS.length; i++) {
      if (cumple <= TRAMOS[i].hasta) return TRAMOS[i].nombre;
    }
    return DE_AHI_EN_ADELANTE;
  }

  window.APOLANA_CATEGORIAS = {
    LISTA: LISTA,
    TRAMOS: TRAMOS,
    porNacimiento: porNacimiento
  };
})();
