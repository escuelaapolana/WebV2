#!/usr/bin/env python3
"""
Crea cuentas de acceso al portal en bloque, a partir de un CSV.

SE EJECUTA EN TU ORDENADOR, no en la web. Necesita la clave SECRETA de Supabase,
que se lee de un archivo local y NUNCA sale de tu equipo ni aparece en la web.

--------------------------------------------------------------------
PREPARACIÓN (una sola vez)
--------------------------------------------------------------------
1) Consigue la clave secreta:
   Supabase → Project Settings → API Keys → "service_role" (secret) → copiar.

2) Guárdala en tu ordenador (NO la pegues en ningún chat):
   printf '%s' 'PEGA_AQUI_LA_CLAVE' > ".secrets/service_key"

3) Prepara el CSV con las personas (separador ; y una columna de correo):
   nombre;apellidos;email
   Lucía;Bernabéu;lucia@ejemplo.com

--------------------------------------------------------------------
USO
--------------------------------------------------------------------
   python3 herramientas/crear-cuentas.py personas.csv                # prueba, no crea nada
   python3 herramientas/crear-cuentas.py personas.csv --crear        # crea las cuentas

Al terminar deja "cuentas-creadas.csv" con la contraseña temporal de cada uno,
para que se la repartas (por los grupos de WhatsApp, en mano...). Cada persona
debería cambiarla al entrar por primera vez.
"""

import csv, json, os, secrets, string, sys, time, urllib.request, urllib.error

URL = "https://icaxokjsvhlreuwpyxeb.supabase.co"
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLAVE = os.path.join(RAIZ, ".secrets", "service_key")


def clave_secreta():
    if not os.path.exists(CLAVE):
        sys.exit(f"No encuentro la clave en {CLAVE}\nLee las instrucciones de arriba (paso 2).")
    k = open(CLAVE, encoding="utf8").read().strip()
    if len(k) < 40:
        sys.exit("La clave parece incompleta. Vuelve a copiarla entera.")
    return k


def contrasena_temporal(n=10):
    """Legible: sin caracteres que se confundan (l, 1, O, 0)."""
    letras = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789"
    return "".join(secrets.choice(letras) for _ in range(n))


def crear_cuenta(email, password, key, nombre=""):
    datos = json.dumps({
        "email": email,
        "password": password,
        "email_confirm": True,           # sin correo de confirmación
        "user_metadata": {"nombre": nombre},
    }).encode()
    req = urllib.request.Request(
        f"{URL}/auth/v1/admin/users", data=datos, method="POST",
        headers={"apikey": key, "Authorization": f"Bearer {key}",
                 "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return True, json.load(r).get("id", "")
    except urllib.error.HTTPError as e:
        cuerpo = e.read().decode("utf8", "ignore")
        if "already" in cuerpo.lower() or e.code == 422:
            return False, "ya tenía cuenta"
        return False, f"error {e.code}: {cuerpo[:120]}"
    except Exception as e:
        return False, str(e)[:120]


def main():
    if len(sys.argv) < 2:
        sys.exit("Uso: python3 herramientas/crear-cuentas.py personas.csv [--crear]")
    fichero, de_verdad = sys.argv[1], "--crear" in sys.argv

    with open(fichero, encoding="utf-8-sig") as f:
        muestra = f.read(2048); f.seek(0)
        sep = ";" if muestra.count(";") >= muestra.count(",") else ","
        filas = list(csv.DictReader(f, delimiter=sep))

    if not filas:
        sys.exit("El CSV está vacío.")

    col = next((c for c in filas[0] if c and "mail" in c.lower()), None)
    if not col:
        sys.exit(f"No encuentro una columna de correo. Columnas: {list(filas[0])}")

    personas, vistos = [], set()
    for fila in filas:
        email = (fila.get(col) or "").strip().lower()
        if not email or "@" not in email or email in vistos:
            continue
        vistos.add(email)
        nombre = " ".join(str(fila.get(c) or "").strip()
                          for c in fila if c and c.lower() in ("nombre", "apellidos")).strip()
        personas.append((email, nombre))

    print(f"\n{len(personas)} correos válidos en «{fichero}» (columna «{col}»)")

    if not de_verdad:
        for e, n in personas[:10]:
            print(f"   · {e}  {n}")
        if len(personas) > 10:
            print(f"   … y {len(personas)-10} más")
        print("\nEsto ha sido una PRUEBA: no se ha creado nada.")
        print("Para crearlas de verdad, repite el comando añadiendo  --crear\n")
        return

    key = clave_secreta()
    print("Creando cuentas…\n")
    hechas, fallos = [], []
    for i, (email, nombre) in enumerate(personas, 1):
        pwd = contrasena_temporal()
        ok, info = crear_cuenta(email, pwd, key, nombre)
        if ok:
            hechas.append({"email": email, "nombre": nombre, "contrasena_temporal": pwd})
            print(f"  [{i}/{len(personas)}] ✓ {email}")
        else:
            fallos.append({"email": email, "motivo": info})
            print(f"  [{i}/{len(personas)}] ✗ {email} — {info}")
        time.sleep(0.15)   # sin prisa, para no saturar

    if hechas:
        salida = os.path.join(os.path.dirname(os.path.abspath(fichero)), "cuentas-creadas.csv")
        with open(salida, "w", encoding="utf-8-sig", newline="") as f:
            w = csv.DictWriter(f, fieldnames=["email", "nombre", "contrasena_temporal"], delimiter=";")
            w.writeheader(); w.writerows(hechas)
        print(f"\n✓ {len(hechas)} cuentas creadas → {salida}")
        print("  Reparte esas contraseñas y que cada uno la cambie al entrar.")
        print("  ⚠️  Ese archivo lleva contraseñas: guárdalo bien y bórralo cuando acabes.")
    if fallos:
        print(f"\n✗ {len(fallos)} sin crear:")
        for f_ in fallos[:15]:
            print(f"   · {f_['email']} — {f_['motivo']}")
    print()


if __name__ == "__main__":
    main()
