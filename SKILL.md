---
name: generar-deploy
description: >
  Genera documentacion de deploy (DEPLOY.md) y un script de instalacion (install.sh)
  completo y funcional para cualquier proyecto. Usar esta skill siempre que el usuario
  pida generar deploy, crear install.sh, documentar el despliegue, preparar el proyecto
  para produccion, o cualquier variante como "genera el deploy", "haceme el instalador",
  "quiero poder instalar esto con curl", "prepara el deploy", "genera la doc de deploy",
  "install script", "como se instala esto", "deploy docs". Tambien activar cuando el
  usuario diga "/generar-deploy". Incluso si el usuario no dice explicitamente "deploy"
  pero quiere que su proyecto sea instalable desde una maquina remota, esta skill aplica.
---

# Generar Deploy

Genera dos archivos para cualquier proyecto:
- **DEPLOY.md** — Documentacion completa de deploy
- **install.sh** — Script de instalacion ejecutable via `curl | bash`

## Filosofia

El install.sh debe ser **autonomo**: una persona en una maquina remota debe poder correr
un solo comando curl y tener el proyecto funcionando. El DEPLOY.md complementa explicando
el contexto, la arquitectura y los procedimientos manuales.

---

## Paso 1: Recolectar informacion del proyecto

Antes de generar nada, hay que entender el proyecto a fondo. Leer en este orden de prioridad:

### 1.1 Documentacion existente
- `.planning/` (framework GSD — contiene PROJECT.md, roadmap, requirements, etc.)
- `README.md`, `DEPLOY.md` existente, `INSTALL.md`, `CLAUDE.md`
- Archivos `PRD-*.md` o cualquier `.md` en la raiz

### 1.2 Archivos de configuracion del proyecto
- `docker-compose.yml` / `docker-compose.*.yml` — servicios, redes, volumenes
- `Dockerfile` / `*.Dockerfile` — como se construye la imagen
- `package.json` / `pnpm-workspace.yaml` / `turbo.json` — Node.js/monorepo
- `go.mod` — Go
- `requirements.txt` / `pyproject.toml` / `setup.py` — Python
- `Makefile` — targets de build
- `*.service` / archivos en `systemd/` — servicios systemd
- `.env.example` / `.env.template` — variables de entorno necesarias
- `nginx.conf`, `Caddyfile` — configuracion de web server

### 1.3 Infraestructura y red
- Labels de Traefik en docker-compose.yml (dominios, entrypoints)
- Puertos expuestos
- Redes Docker externas
- Dependencias de otros servicios (base de datos, reverse proxy, etc.)

### 1.4 Estructura del repositorio
- Si es monorepo: identificar que subdirectorios se necesitan (para sparse checkout)
- Si tiene subdirectorios con sus propios docker-compose.yml
- Si es un repo simple o tiene multiples componentes

---

## Paso 2: Clasificar el tipo de proyecto

Basandose en lo recolectado, determinar el tipo de deploy:

| Tipo | Señales | Estrategia de install.sh |
|------|---------|--------------------------|
| **Docker Compose** | `docker-compose.yml` presente | clone → network → build → up → healthcheck |
| **Docker Compose + monorepo** | docker-compose.yml + es subdirectorio de un monorepo | clone sparse → network → build → up → healthcheck |
| **Go binary + systemd** | `go.mod` + archivos `.service` o directorio `systemd/` | clone → go build → copiar .service → systemctl enable+start |
| **Node.js + systemd** | `package.json` + archivos `.service` o directorio `systemd/` | clone → npm install → build → copiar .service → systemctl enable+start |
| **Node.js + Docker** | `package.json` + `Dockerfile` + `docker-compose.yml` | clone → network → build → up → healthcheck |
| **Python + Docker** | `requirements.txt`/`pyproject.toml` + `docker-compose.yml` | clone → network → build → up → healthcheck |
| **Estatico + Docker** | `nginx.conf` + `Dockerfile` + contenido estatico | clone → network → build → up → healthcheck |
| **Rust + Docker** | `Cargo.toml` + `Dockerfile` + `docker-compose.yml` | clone → network → build → up → healthcheck |
| **Rust + systemd** | `Cargo.toml` + archivos `.service` o directorio `systemd/` | clone → cargo build --release → copiar binario y .service → systemctl enable+start |
| **Multi-componente** | Multiples subdirectorios con sus propios docker-compose | clone → instalar cada componente en orden |

Si el tipo no es claro, preguntar al usuario antes de generar. Si el proyecto no encaja
en ninguna categoria pero tiene un Dockerfile, tratarlo como Docker Compose generico.
Si no tiene Docker ni systemd, sugerir al usuario que agregue uno de los dos y explicar las opciones.

---

## Paso 3: Determinar variables del proyecto

Extraer o preguntar al usuario estos datos esenciales:

| Variable | De donde extraerla | Preguntar si no se encuentra |
|----------|-------------------|------------------------------|
| `REPO_URL` | Remote de git (`git remote get-url origin`) | Si |
| `PROJECT_NAME` | Nombre del directorio o package.json name | No (inferir) |
| `INSTALL_DIR` | Convención: `/opt` (servidor de produccion, nunca `$HOME`) | Confirmar |
| `DOCKER_NETWORK` | docker-compose.yml networks (buscar external: true) | Si usa Docker |
| `CONTAINER_NAME` | docker-compose.yml container_name | Si usa Docker |
| `DOMAIN` | Labels de Traefik en docker-compose.yml (`traefik.http.routers.*.rule=Host(...)`) o preguntar | Si (si expone web) |
| `TRAEFIK_ROUTER` | Nombre del router Traefik (tipicamente el nombre del servicio) | Inferir del docker-compose.yml |
| `TRAEFIK_ENTRYPOINT` | Entrypoint de Traefik (`web` para HTTP, `websecure` para HTTPS) | Inferir o preguntar |
| `TRAEFIK_SERVICE_PORT` | Puerto interno del contenedor que Traefik debe rutear | Inferir del docker-compose.yml o codigo |
| `HEALTH_ENDPOINT` | Buscar /health, /api/health, /status en el codigo | Inferir o preguntar |
| `HEALTH_PORT` | docker-compose.yml ports o codigo del server | Inferir |
| `SERVICE_NAME` | Nombre del archivo .service | Si usa systemd |
| `SPARSE_DIRS` | Solo para monorepos: que directorios necesita | Si es monorepo |

### 3.1 Regla de Traefik (obligatoria si expone interfaz web)

Todo servicio que exponga una interfaz web al exterior debe rutearse a traves de **Traefik** como
reverse proxy. El proyecto accede via un subdominio, nunca por IP:puerto directo.

**Detectar la configuracion de Traefik:**
1. Buscar labels de Traefik en `docker-compose.yml`
2. Si ya tiene labels, extraer dominio, entrypoint y puerto
3. Si NO tiene labels, preguntar al usuario el subdominio deseado y agregarlo

**Variables de Traefik a resolver:**
- `DOMAIN`: el subdominio completo (ej: `mi-app.midominio.com.ar`)
- `TRAEFIK_ROUTER`: nombre unico del router (ej: `mi-app`)
- `TRAEFIK_ENTRYPOINT`: tipicamente `web` (HTTP) — se usa HTTP porque el trafico viaja
  cifrado por el tunel Tailscale. Si hay HTTPS directo, usar `websecure`
- `TRAEFIK_SERVICE_PORT`: puerto interno del contenedor (ej: `3000`, `3335`, `80`)

**Labels minimos en docker-compose.yml:**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.{TRAEFIK_ROUTER}.rule=Host(`{DOMAIN}`)"
  - "traefik.http.routers.{TRAEFIK_ROUTER}.entrypoints={TRAEFIK_ENTRYPOINT}"
  - "traefik.http.services.{TRAEFIK_ROUTER}.loadbalancer.server.port={TRAEFIK_SERVICE_PORT}"
```

**Importante:** cuando Traefik rutea, el contenedor NO debe exponer puertos directamente (`ports:`).
El trafico llega via la red Docker interna. Solo descomentar `ports:` para desarrollo local sin Traefik.

---

## Paso 4: Generar install.sh

El script debe seguir esta estructura. Adaptar segun el tipo de proyecto detectado.

### Estructura base del install.sh

```bash
#!/bin/bash
# =============================================================================
# {PROJECT_NAME} — Instalador automatico
# =============================================================================
# Uso:
#   curl -sL {RAW_GITHUB_URL}/install.sh | bash
#
# O desde el VPS:
#   bash {LOCAL_PATH}/install.sh
#
# Que hace:
#   {descripcion de pasos en formato lista}
#
# Requisitos:
#   {lista de requisitos}
# =============================================================================

set -euo pipefail
```

### Secciones obligatorias (en este orden)

#### 4.1 Config
Variables al inicio del script, faciles de editar:
```bash
# -- Config ------------------------------------------------------------------
INSTALL_DIR="/opt"
REPO_DIR="${INSTALL_DIR}/{repo-name}"
REPO_URL="https://github.com/{org}/{repo}.git"
# ... mas variables segun el tipo
```

**IMPORTANTE:** El `INSTALL_DIR` debe apuntar siempre a un directorio de produccion (tipicamente `/opt`).
**NUNCA** usar `$HOME/proyectos` ni ninguna ruta dentro del home del usuario, porque puede coincidir
con la carpeta donde se desarrollo el proyecto y pisarla. Si el usuario sugiere una ruta en `$HOME`,
advertir que puede sobreescribir su copia de desarrollo y recomendar `/opt` en su lugar.

#### 4.2 Colores y funciones de log
```bash
# -- Colores -----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
```

#### 4.3 Banner
```bash
echo ""
echo "=========================================="
echo "  {PROJECT_NAME} — Instalador"
echo "=========================================="
echo ""
```

#### 4.4 Verificar dependencias
Verificar solo lo que el proyecto necesita:
- **Siempre**: `git`
- **Docker Compose**: `docker`, `docker compose` (v2)
- **Go**: `go` (con version minima si go.mod la especifica)
- **Node.js**: `node`, `npm` o `pnpm` (segun package manager del proyecto)
- **Python**: `python3`, `pip`
- **systemd**: `systemctl`

#### 4.5 Proteccion contra sobreescritura de repo de desarrollo
Antes de cualquier operacion, verificar que no estamos pisando el repo de desarrollo:
```bash
# Proteccion: no sobreescribir repo de desarrollo
if [ -d "$REPO_DIR/.git" ]; then
  EXISTING_REMOTE=$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || echo "")
  DIRTY_FILES=$(git -C "$REPO_DIR" status --porcelain 2>/dev/null | wc -l)
  if [ "$DIRTY_FILES" -gt 0 ]; then
    error "$REPO_DIR tiene cambios sin commitear — parece ser un repo de desarrollo. Abortando para no pisarlo."
  fi
fi
```

#### 4.6 Manejar instalacion previa
Si el directorio ya existe (y paso la proteccion anterior):
- Bajar servicios (docker compose down / systemctl stop)
- Hacer backup de `.env` si existe
- Eliminar directorio
- Restaurar `.env` despues del clone

#### 4.7 Clonar repositorio
- Repo simple: `git clone`
- Monorepo con sparse checkout:
```bash
git clone --filter=blob:none --sparse "$REPO_URL"
cd "$REPO_DIR"
git sparse-checkout set dir1/ dir2/
```

#### 4.8 Restaurar .env
Si se hizo backup, restaurarlo despues del clone.

#### 4.9 Segun tipo de proyecto

**Para Docker Compose:**
```bash
# Crear red Docker si no existe
# Verificar que docker-compose.yml tiene labels de Traefik (si expone web)
# docker compose build (--no-cache si es reinstalacion)
# docker compose up -d
```

**Traefik (obligatorio si expone interfaz web):**
El install.sh no modifica la config de Traefik (ya viene en el docker-compose.yml del repo),
pero el resultado final debe informar al usuario:
- El subdominio configurado y como apuntar el DNS/hosts
- Detectar la IP de Tailscale: `tailscale ip -4 2>/dev/null || echo "<IP-TAILSCALE>"`
- Mostrar la linea que debe agregar en `/etc/hosts` o configurar en DNS:
  ```
  {TAILSCALE_IP}    {DOMAIN}
  ```
- Si el proyecto NO tiene labels de Traefik en docker-compose.yml pero expone una interfaz
  web, esto es un **error de configuracion**. Avisar al usuario que debe agregar los labels
  o descomentar los ports para desarrollo local.

**Para Go + systemd:**
```bash
# go build -o {binary} {main_path}
# sudo cp {binary} /usr/local/bin/
# sudo cp {service_file} /etc/systemd/system/
# sudo systemctl daemon-reload
# sudo systemctl enable --now {service}
```

**Para Node.js + systemd:**
```bash
# npm install (o pnpm install)
# npm run build (si hay build script)
# sudo cp {service_file} /etc/systemd/system/
# sudo systemctl daemon-reload
# sudo systemctl enable --now {service}
```

**Para Rust + systemd:**
```bash
# cargo build --release
# sudo cp target/release/{binary} /usr/local/bin/
# sudo cp {service_file} /etc/systemd/system/
# sudo systemctl daemon-reload
# sudo systemctl enable --now {service}
```

#### 4.10 Health check
Esperar que el servicio arranque y verificar:
```bash
RETRIES=0
MAX_RETRIES=15
while [ $RETRIES -lt $MAX_RETRIES ]; do
  # Para Docker: docker inspect --format='{{.State.Health.Status}}' $CONTAINER_NAME
  # Para systemd: systemctl is-active --quiet $SERVICE_NAME
  # Para endpoint HTTP: curl -sf http://localhost:$HEALTH_PORT$HEALTH_ENDPOINT
  # Elegir el metodo que corresponda al tipo de proyecto
  RETRIES=$((RETRIES + 1))
  sleep 2
done
# Si falla el health check, mostrar logs para diagnostico:
# Docker: docker compose logs --tail 30
# systemd: journalctl -u $SERVICE_NAME --no-pager -n 30
```

#### 4.11 Resultado final
Mostrar resumen con:
- Estado del servicio
- URL de acceso (si tiene dominio)
- Comando para ver logs
- Proximos pasos si necesita configuracion (.env, wizard, etc.)

### Reglas del install.sh

- **Idempotente**: correrlo dos veces no debe romper nada
- **Backup de .env**: siempre preservar configuracion del usuario
- **Sin interaccion**: no pedir input (debe funcionar con `curl | bash`)
- **Fail-fast**: usar `set -euo pipefail`
- **Colores**: siempre con las funciones info/ok/warn/error
- **Logs en caso de fallo**: mostrar logs del servicio si el health check falla

---

## Paso 5: Generar DEPLOY.md

El DEPLOY.md debe contener toda la informacion necesaria para que alguien entienda
como funciona el deploy sin leer el codigo fuente.

### Estructura del DEPLOY.md

```markdown
# Deploy — {PROJECT_NAME}

## Instalacion rapida

\`\`\`bash
curl -sL {RAW_GITHUB_URL}/install.sh | bash
\`\`\`

## Requisitos

- {lista de requisitos con versiones}

## Arquitectura

{descripcion de componentes, como se conectan entre si}
{si usa Docker: servicios, redes, volumenes}
{si usa systemd: que servicios crea}

## Variables de entorno

| Variable | Descripcion | Ejemplo | Requerida |
|----------|-------------|---------|-----------|
| ... | ... | ... | Si/No |

{Extraer de .env.example o del codigo}

## Servicios

{Tabla o lista de servicios que levanta el proyecto}

| Servicio | Puerto | Descripcion |
|----------|--------|-------------|
| ... | ... | ... |

## Red y acceso

- Red Docker: `{network_name}`
- Dominio: `{domain}` (via Traefik)
- Router Traefik: `{traefik_router}`
- Entrypoint: `{traefik_entrypoint}`
- Puerto interno: `{traefik_service_port}`

### Configurar acceso DNS

**Opcion A: Tailscale (recomendado)**
Agregar en el archivo hosts de tu maquina:
\`\`\`
{TAILSCALE_IP}    {domain}
\`\`\`
Para obtener la IP Tailscale del VPS: `tailscale ip -4`

**Opcion B: DNS publico**
Crear registro A: `{subdominio}` → IP publica del VPS

**Opcion C: Desarrollo local sin Traefik**
Descomentar `ports:` en docker-compose.yml y acceder a `http://localhost:{port}`

## Comandos utiles

\`\`\`bash
# Ver logs
{comando para ver logs}

# Reiniciar
{comando para reiniciar}

# Detener
{comando para detener}

# Estado
{comando para ver estado}
\`\`\`

## Actualizacion

{Pasos para actualizar a una nueva version}

## Troubleshooting

{Problemas comunes y soluciones, basados en la documentacion existente}

## Estructura del proyecto

{Arbol simplificado de archivos relevantes al deploy}
```

### Reglas del DEPLOY.md

- Escribir en **español** (consistente con el estilo del usuario)
- Incluir el comando curl de instalacion al principio (es lo primero que alguien busca)
- Las variables de entorno se extraen de `.env.example` — si no existe, buscar en el codigo
- La seccion de troubleshooting se construye desde la documentacion existente y problemas comunes del stack
- No inventar informacion: si algo no se puede determinar, marcarlo con `{COMPLETAR}`

---

## Paso 6: Presentar al usuario

Despues de generar ambos archivos:

1. Mostrar un resumen de lo que se genero
2. Mostrar el comando curl completo que funcionara desde una maquina remota
3. Recordar que el install.sh necesita estar pusheado a GitHub para que el curl funcione
4. Si hay datos que no se pudieron determinar (marcados con `{COMPLETAR}`), listarlos para que el usuario los complete

---

## Notas importantes

- Si el proyecto ya tiene un install.sh o DEPLOY.md, leerlos primero y usarlos como base. Preguntar al usuario si quiere reemplazarlos o mejorarlos.
- El health check del install.sh debe adaptarse a lo que el proyecto realmente expone. No asumir que tiene `/health` — buscar en el codigo la ruta real.
- Para monorepos, el install.sh solo debe clonar los directorios necesarios para el componente que se esta deployando, no el monorepo completo.
- Los archivos `.env` nunca deben estar en el repositorio. El install.sh debe manejar su ausencia con gracia (mostrar instrucciones de configuracion si no existe `.env`).
