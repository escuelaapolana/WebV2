# Corrección · quién lleva el dinero

Corrige: `CARACTER-Y-PANEL.md`, `PAGOS`, `PANEL-ATLETAS-Y-COBROS.md`, `DECISIONES-Y-RETOS.md`

**Estaba mal.** Los documentos anteriores decían «todos los pagos a Isabel» y «el
presidente queda fuera del circuito de dinero». No es así.

---

## El reparto real

| Quién | Qué lleva |
|---|---|
| **Isabel Fuentes** · contable | **Socios y adultos.** Gestiona, gira remesas y hace transferencias |
| **Adrián Onandía** · presidente | **Escuela** |
| **Andrés Clavero** · tesorero | **Escuela** |

Adrián y Andrés tienen **acceso a todo**, no solo a escuela. Isabel ejecuta.

---

## Qué cambia en el diseño

### 1 · El contacto depende de la sección, no del tipo de duda
En la zona de pagos del socio, el contacto que se muestra es:

- **Cuota de socio o entrenamiento de adultos** → Isabel
- **Escuela de los niños** → Adrián o Andrés

Ya estaba previsto en el brief original («el responsable de su sección»); lo que
estaba mal era el nombre y el haberlo eliminado después. **Se recupera.**

Es coherente con las dos cuentas bancarias: la escuela tiene cuenta propia y
responsables propios.

### 2 · «Solo lo mío» viene desactivado para tesorería
El filtro de la bandeja de Inicio recuerda la elección por persona:

- **Adrián y Andrés:** desactivado por defecto — ven todo
- **Isabel:** activado por defecto, filtrado a socios y adultos
- **Resto de la junta:** sin acceso a dinero, el bloque no aparece

### 3 · Cambiar una cuota es acción de tesorería
En la ficha del atleta, modificar la cuota o aplicar una excepción **no lo decide
quien gestiona**: lo deciden Adrián o Andrés.

- Para ellos: el campo es editable
- Para Isabel: el campo se muestra pero con un botón **«Pedir cambio a tesorería»**,
  que genera un aviso en la bandeja de los dos

Y al revés: cuando ellos cambian una cuota, **le llega a Isabel como aviso** para
que lo tenga en cuenta en la remesa. No es un permiso, es un flujo de dos pasos.

### 4 · Cobros: quién puede girar
- **Girar la remesa:** Isabel
- **Aprobar una excepción o un cambio de cuota:** Adrián o Andrés
- Las dos cosas se ven en la misma pantalla; lo que cambia es qué botón está activo

En la remesa de escuela, un aviso: «la fija tesorería, la gira Isabel».

---

## Los tres papeles del panel, resumidos

```
Tesorería (Adrián, Andrés)   ve todo · fija cuotas · aprueba excepciones
Contabilidad (Isabel)        socios y adultos · gira remesas · transferencias
Junta                        sin acceso a dinero
Entrenadores                 su grupo · asistencia y notas · nada de dinero
```

**Regla:** quien decide un importe y quien lo ejecuta no son la misma persona, y el
panel tiene que reflejarlo con un aviso entre los dos, no con un permiso que
bloquea.
