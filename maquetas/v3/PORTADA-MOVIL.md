# Portada en móvil · el hero no es el de escritorio

Maqueta: `Portada movil Apolana.dc.html` (42a diagnóstico · 42b la solución)
Corrige: `PORTADA.md`

El hero de escritorio se aplicó tal cual en móvil. En 402 px no funciona.

---

## Qué está pasando

1. **El velo diagonal no vale.** En escritorio va oscuro a la izquierda y limpio a
   la derecha, porque el texto ocupa media pantalla. En móvil el texto ocupa el
   ancho entero, así que la parte clara del velo cae justo debajo del texto y el
   atleta se cruza con las palabras.
2. **El hero lleva seis cosas de más.** Titular, frase, dos botones, tres números,
   el aviso de El Cubo y un segundo botón: casi **1.200 px** de alto. Hay que
   hacer tres barridos para llegar a «Hoy en el club».
3. **El informativo se ha colado dentro.** «En agosto El Cubo abre por las
   mañanas» en gris claro sobre la pista azul: no se lee. En escritorio iba en la
   línea de los números porque allí sobraba sitio.

---

## Las tres reglas del hero en móvil

### 1 · Velo vertical, no diagonal
De abajo arriba: casi opaco en el tercio inferior, casi limpio arriba. El texto se
apoya en el borde inferior y la foto se ve entera en la parte alta.

```css
background: linear-gradient(to top,
  rgba(20,28,36,0.93) 0%,
  rgba(20,28,36,0.86) 38%,
  rgba(20,28,36,0.42) 68%,
  rgba(20,28,36,0.15) 100%);
```

⚠️ **El recorte de la foto en móvil tiene que dejar el tercio inferior sin nada
importante.** No es la misma versión de la foto que en escritorio: hace falta un
recorte vertical propio.

### 2 · Cuatro elementos y ni uno más
- Antetítulo a 14 px
- **Titular a 40 px** (no 62), interlineado 0.96, dos líneas
- Una frase corta
- **Un botón** azul a ancho completo, 52 px, y el secundario como texto debajo

Los dos botones en fila no caben: se parten y quedan de 150 px cada uno.

**Alto total del hero: 430 px.**

### 3 · Lo demás baja, y cada cosa a su banda
| Elemento | Dónde va en móvil |
|---|---|
| «Hoy en el club» | Banda **navy** justo debajo del hero. Es lo segundo que hay que ver |
| Los tres números | Banda **crema fuerte** `#F1EADC`, una sola línea, cifra + rótulo al lado |
| Aviso de El Cubo | **Tarjeta ámbar dentro del contenido.** Es un aviso, no parte del hero |

### Y la frase se acorta
«Atletismo, running, triatlón, natación y montaña.» y punto. El «de los 3 años a
la alta competición» se cae: en escritorio son dos líneas, en móvil son cuatro y
empujan el botón fuera de pantalla.

---

## Cabecera en móvil
Escudo a 28 px + «Apolana» + `Acceso` + botón de menú de 40 px. El «Alicante ·
1988» del logotipo se cae, y WhatsApp pasa al menú (ya estaba así en
`REDISENO-WEB.md`).

---

## La regla general que sale de aquí

**Ninguna banda a sangre se traduce sola de escritorio a móvil.** Cuando una
banda de escritorio lleva más de tres elementos en fila, en móvil hay que decidir
qué se queda dentro y qué baja a su propia banda. Aplica a:

- El hero de portada (aquí)
- La banda de datos duros de una página de grupo (días · hora · sitio · cuota ·
  botón → en móvil, dos filas de dos + botón a ancho completo)
- La banda navy de cobros en el panel (cuatro cifras → dos y dos)
- La cabecera de horarios (título + dos cifras + botón de suscripción)

Con las tres reglas puestas, el titular, el botón y el arranque de «Hoy en el
club» entran en la primera pantalla de un iPhone — que es el equivalente móvil de
la regla de los 640 px de escritorio.
