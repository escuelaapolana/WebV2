# Panel · atletas, cobros y el patrón para el resto

Maqueta: `Panel Apolana atletas.dc.html` (40a atletas · 40b cobros · 40c el patrón)
Antes: `KIT.md`, `CARACTER-Y-PANEL.md`, `EN-LA-PISTA.md`

Las dos páginas donde el club pasa más horas. De aquí sale el patrón para las
otras 23 del panel.

---

## 1 · Atletas · 40a

420 fichas. **El buscador va primero**, dentro de la banda de filtros y con sitio
para un nombre entero.

### Banda de filtros (crema fuerte, a sangre)
Buscador · chips de filtro aplicado con «×» · «Quitar filtros» · recuento
**«32 de 420»** a la derecha. Nunca «Filtrar · 2»: el recuento dice a la vez
cuánto hay filtrado y cuánto hay en total.

### Tabla
`Atleta · Grupo · Estado · Asistencia · Cuota`

- **Estado = punto de 9 px + palabra.** Nunca solo color
  - Verde `#3F7A4C` → activo (el mismo verde de la pista)
  - Ámbar `#B96F09` → en prueba, lesionado
  - Gris → baja
- Avatar de iniciales a 32 px, y debajo del nombre el año y la categoría
- Asistencia en mono; **en ámbar cuando baja de la mitad**
- **La fila que pide algo va con fondo ámbar** `#FDF3E3` (Lucas, en prueba día 3)
- `Ver 20 más` al final, con el recuento repetido

### Lateral
Resumen con estos filtros (activos, en prueba, lesionados) · el aviso de la prueba
que acaba, con su acción · y la nota de que la ficha se abre encima.

---

## 2 · Cobros · 40b

**El dinero no es una tabla de importes: es qué hay que hacer hoy.**

### Banda navy con el número que manda
`A girar el día 3 · 14.280 €` grande, y al lado los que importan:
recibos (312), **devueltos (7) y sin domiciliar (4) en ámbar**, más el botón
«Ver los 11 pendientes».

### Hay que resolver · antes que todo
Once filas, cada una con **borde de color por motivo** y su acción concreta:

| Motivo | Borde | Acciones |
|---|---|---|
| Devuelto | `#B96F09` | `Escribirle` + `Volver a girar` |
| Devuelto con causa conocida | `#B96F09` | `Pedir IBAN` + `Volver a girar` |
| Alta nueva sin domiciliar | `#6B5B8A` | `Pedir IBAN` |

Cierra con «Y 8 más: 5 devueltos y 3 sin domiciliar».

### Va solo · agrupado y colapsado
Tres líneas con punto verde: entrenamiento de adultos, escuela primer pago,
cuotas de socio. Recuento de recibos e importe. **Solo hay que comprobarlo.**

Nadie entra a cobros a mirar 312 recibos: entra a resolver once.

### Lateral
- **Familia Apolana** — hogares con −10 % y con −15 %, y el descuento total del mes
- **Dos cuentas, dos remesas** — la escuela a su cuenta y en dos pagos; socios y
  adultos a la otra y en uno. Se descargan por separado y el botón lo dice antes
  de girar
- **Agosto, cerrado** — cobrado, devuelto y el porcentaje de devoluciones

---

## 3 · El patrón para las otras 23 · 40c

1. **Cabecera, banda de filtros, contenido en dos columnas.** Migas y título con
   el recuento en mono, **dos acciones máximo**; filtros en crema fuerte a sangre
   con el buscador primero; lista a la izquierda y contexto a la derecha
2. **Lo que pide algo, primero.** Toda página de gestión se parte en «hay que
   resolver» y «va solo». Vale para cobros, pedidos de ropa, buzón, inscripciones
   y validaciones de la Liga
3. **Estado = punto + palabra**, con los mismos tres colores en todo el panel
4. **La banda navy solo si hay un número que manda.** En cobros, el total a girar.
   En atletas no hay banda — **si no existe ese número, no se pone banda para
   rellenar**
5. **La ficha se abre encima**, en ventana sobre la lista. Al cerrarla sigues
   donde estabas y con los filtros puestos
6. **Buscador desde 30 filas, «ver más» desde 20**, y el recuento siempre en
   «N de TOTAL»

---

## Deuda de contraste pendiente

`#B96F09` sobre crema mide **3,74:1** — es el token más flojo del sistema. Donde
se usa como **texto de dato** («4 / 8» de asistencia, «438 €» devuelto) conviene
bajarlo a `#8A5307`, que ya se usa para nombres propios y sí cumple el 4,5:1.

Como **fondo de aviso** (`#FDF3E3` con texto `#6B5227`) no hay problema.

No es urgente, pero es la única deuda de contraste que queda en el sistema.

---

## Pendiente del panel

- Estadísticas — gráficas hechas a mano, funcionan pero son sosas
- Fotos de la web (los 80 huecos) y biblioteca de fotos
- Liga: bandeja de validación con el justificante a la vista
- Retos: crear y ver quién cumple, con permisos de menores
- Informes e historial de un atleta, imprimible con membrete
- Colaboradores, plantillas, tarifas, grupos, usuarios, importar
