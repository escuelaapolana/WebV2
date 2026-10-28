# Ejemplos de cálculo — resultados esperados (para validar antes de programar)

> 28-oct-2026 · Textos reales de la semana 9 de Academia. Reglas en
> [modelo-datos-seguimiento.md](modelo-datos-seguimiento.md).
> Cuando un valor no se puede saber, el resultado esperado es **«pendiente»** o
> **«ausente»**, no un número. Los kg de los ejemplos de RM son ilustrativos.

## A. Arrastre + libre

**A1** · «Bloque 1/3 a 3/3: 20 m trineo + 20 m libre // 90″ dentro y 3′ entre bloques Z»

| Concepto | Previsto |
|---|---|
| Estructura | 3 bloques × secuencia [20 m arrastre → 20 m libre]; 90″ entre componentes, 3′ entre bloques |
| Carrera total / principal | 120 m / 120 m |
| Metros con arrastre (exposición, dentro del total) | 60 m |
| Por contenido | Fuerza horizontal: 60 m · Aceleración: 60 m |
| Carga | trineo, **kg ausente** → pendiente |
| Calzado | Z (zapatillas) |

**A2** · «3x40 arrastre ligero (12kg) // 3′ Z»
- 120 m de carrera, todos con arrastre; Fuerza horizontal 120 m.
- Carga «12 kg»: **duda**, ¿son discos añadidos o la masa total del trineo? Queda
  pendiente hasta que se aclare. No se asume ninguna de las dos.

## B. Flying

**B1** · «2×30 flying (20+30) // 5′ C»

| Concepto | Previsto |
|---|---|
| Carrera total | **100 m** |
| Entrada progresiva | **40 m** (no cuenta como aceleración) |
| Lanzados | **60 m** → contenido según objetivo e intensidad: el texto no los da → **pendiente de revisión** (no se asume velocidad máxima) |
| Metros con clavos (exposición) | **100 m**, dentro de los 100 m, no se suman otra vez |

**B2** · «3x30 flying (30+30) // 6′ C» → total 180 m · entrada progresiva 90 m ·
lanzados 90 m (contenido pendiente) · clavos 180 m.

**B3** · «3×60 (20+60) lanzados en 7,20–7,40″» → **duda**: ¿los 60 m incluyen la
entrada o se suman (80 m por rep.)? **No se calcula** hasta resolverlo. Intensidad:
`tiempo_objetivo` 7,20–7,40″ (del tramo lanzado, a confirmar).

## C. Bloques de series

**C1** · «Bloque 1/2 y 2/2: 250 (34-35″) + 150 (19,5-20,5″) // 4′ y 8′ Z»

| Concepto | Previsto |
|---|---|
| Estructura | 2 bloques × [250 → 150]; 4′ entre componentes, 8′ entre bloques |
| Carrera principal | **800 m** (no 4×200 ni 1×800) |
| Intensidad | `tiempo_objetivo`: 34–35″ en el 250 y 19,5–20,5″ en el 150 |
| Contenido | Si el entrenador titula el bloque «Ritmo 400» → **propuesta**: ritmo específico. Si no, **pendiente** (hace falta la referencia del atleta en 400). |
| Vista detallada | «Ritmo 400 · 2×(250+150) · 34–35″ / 19,5–20,5″ · Z» |

**C2** · «5x1000 en 3:25-3:30 // 2′ trote suave Z» → carrera principal 5.000 m ·
`ritmo` 3:25–3:30/km · recuperación 4×2′ de trote: **8 minutos**, sin metros
(no se inventan) · contenido propuesto: aeróbico/intervalos.

**C3** · «6x150 al 85% // 3′ Z» → 900 m · intensidad `pct_esfuerzo` 85 %
(**no** «85 % de Vmáx», porque no hay referencia).

## D. Gimnasio

**D1** · «Cargada completa 4x3 al 60-65% RM // 2′»
- 4 series × 3 rep. = **12 rep.** · Fuerza (potencia).
- kg previstos: **solo si existe un RM de «cargada completa»** en `rm_atleta`. Ejemplo: RM 80 kg medido el 10-oct → 48–52 kg (fuente `calculo`). Sin ese RM: kg **ausentes**.
- Realizado: kg por serie si se apuntan (fuente `declaracion`, método `no_aplica`).

**D2** · «Media sentadilla + saltos al cajón: 3 bloques de 3 + 2 saltos; sentadilla 75-80% RM // 3′»
- **9 rep. de media sentadilla** (fuerza) + **6 saltos al cajón** (pliometría,
  unidad `saltos`). **No son 15 repeticiones de fuerza.**
- Descanso: 3′ entre bloques; entre componentes **no consta** → pendiente si importa.
- %RM con referencia «media sentadilla». No vale el RM de sentadilla completa.

**D3** · «Búlgaras con salto 3×5/pierna · RIR 3» → 15 rep. **por pierna** (30 en
total, mostrado como 3×5/pierna) · intensidad `rir` 3 · kg sin prescribir.

**D4** · «RDL unilateral con mancuerna 2×5/pierna al 50-60% RM unilateral» →
10 rep. por pierna. Necesita un RM **unilateral** de RDL. **Si solo hay RM
bilateral, kg ausentes** (nunca se traslada). Al apuntar kg: indicar si son por
mancuerna o en total.

## E. Vallas

**E1** · «2x primera valla // 3′ Z» + «2x dos vallas // 4′ Z» + «2x tres vallas // 5′ C»

| Concepto | Previsto |
|---|---|
| Intentos | **6** |
| Vallas franqueadas | 2 + 4 + 6 = **12** |
| Altura y separación | **ausentes** → pendiente (sin ellas no se compara con otras sesiones) |
| Metros | **no se calculan** (separación desconocida) |
| Calzado | Z en los 4 primeros intentos; C en los 2 últimos |

**E2** · «2x3 vallas a 0,84 m · 3 apoyos // 3′» → 2 intentos · 6 vallas · altura
0,84 m · «3 apoyos» = descriptor de ritmo, **no volumen**. Se compara solo con otras
sesiones a 0,84 m y la misma separación.

## F. Ejecución parcial

**F1** · Plan «2×4×120 al 82-87 %» (960 m). El atleta marca «a medias, 60 %», con el
✓ del bloque 1 y no el del bloque 2, y comenta «Paré en la 6.ª por el isquio».
- **% global 60** → se guarda como declaración global. **No** se calcula 0,6 × 960.
- Realizado identificado: bloque 1 = **480 m** (completitud `incompleto` para la
  sesión).
- El comentario sugiere una repetición más del bloque 2 → **propuesta para confirmar**,
  no se cuenta sola.
- Molestia: dato del atleta, con su zona, enlazado al registro.

**F2** · Plan «6x150 al 85 %»; el atleta apunta **un solo tiempo** (21,5″) y nada más.
- Confirma **1 rep. (150 m)**. Las otras 5: **ausentes** (no se dan por hechas).

**F3** · Plan con «6.º opcional si homogéneo + técnica buena + RPE ≤6».
- Previsto: 5 obligatorias + 1 opcional, **separadas**.
- Realizado: la 6.ª solo cuenta si el atleta la confirma.

**F4** · Sin registro del atleta → la sesión queda **«sin datos»**: ni hecha ni no
hecha.

## G. Datos antiguos

**G1** · Registro `historica_sin_garantia` (septiembre): RPE 8, «muy cansado»,
tiempos con clave de bloque `cc`.
- RPE y comentario: **sí se usan** (autor `atleta`, fuente `percepcion`).
- Tiempos: dato **de la sesión**, no de una fila; fuente `declaracion`, método `no_consta`.
- Previsto/realizado: **sin comparación exacta**. El plan guardado se muestra como
  referencia, con su aviso.

**G2** · Registro `sobrescrita` → igual que G1, con el aviso «el plan cambió después
de este registro».

**G3** · Registro `vigente_al_enviar` → comparación **probable**, marcada como tal.
