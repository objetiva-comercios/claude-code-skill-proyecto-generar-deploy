# generar-deploy

Skill para Claude Code que genera documentacion de deploy y scripts de instalacion
automatica para cualquier proyecto de software. Analiza el tipo de proyecto leyendo
sus archivos de configuracion (Docker Compose, package.json, go.mod, Cargo.toml,
systemd, etc.), detecta la infraestructura involucrada, y produce dos archivos
adaptados y funcionales: un `DEPLOY.md` con la documentacion completa del despliegue
y un `install.sh` idempotente que permite instalar el proyecto en una maquina remota
con un solo comando `curl | bash`.

## Tecnologias

| Categoria | Tecnologia |
|-----------|------------|
| Plataforma | Claude Code (skill) |
| Infraestructura soportada | Docker Compose, systemd, Traefik, Tailscale |
| Lenguajes de proyecto soportados | Node.js, Go, Python, Rust, estatico, multi-componente |
| Formato de salida | Bash (`install.sh`), Markdown (`DEPLOY.md`) |

## Requisitos previos

- [Claude Code](https://claude.com/claude-code) instalado

## Instalacion

```bash
curl -sL https://raw.githubusercontent.com/objetiva-comercios/claude-code-skill-proyecto-generar-deploy/main/install.sh | bash
```

O manualmente:

```bash
mkdir -p ~/.claude/skills/generar-deploy
curl -sL https://raw.githubusercontent.com/objetiva-comercios/claude-code-skill-proyecto-generar-deploy/main/SKILL.md \
  -o ~/.claude/skills/generar-deploy/SKILL.md
```

Claude Code detecta la skill automaticamente en la proxima sesion.

## Activacion

La skill se activa desde cualquier proyecto con `/generar-deploy` o con lenguaje natural:

| Trigger | Ejemplo |
|---------|---------|
| Comando directo | `/generar-deploy` |
| Pedir deploy | "genera el deploy", "prepara el deploy" |
| Pedir instalador | "haceme el install.sh", "quiero poder instalar esto con curl" |
| Documentacion de deploy | "genera la doc de deploy", "deploy docs" |
| Preparar produccion | "prepara el proyecto para produccion" |
| Instalacion remota | "como se instala esto", "install script" |

## Que hace la skill

Cuando se activa, ejecuta 6 pasos:

1. **Recolectar informacion** — Lee `.planning/`, README, CLAUDE.md, docker-compose.yml, package.json, go.mod, Cargo.toml, .env.example, archivos .service y cualquier documentacion disponible
2. **Clasificar el proyecto** — Determina el tipo de deploy segun los archivos encontrados
3. **Extraer variables** — Obtiene repo URL, red Docker, dominio, puertos, health endpoint, config de Traefik. Pregunta al usuario lo que no puede inferir
4. **Generar install.sh** — Script idempotente, sin interaccion, con colores, health check y resultado informativo
5. **Generar DEPLOY.md** — Documentacion completa con arquitectura, variables, troubleshooting y comandos utiles
6. **Presentar al usuario** — Muestra resumen y el comando curl final

### Tipos de proyecto soportados

| Tipo | Deteccion | Estrategia |
|------|-----------|------------|
| Docker Compose | `docker-compose.yml` presente | clone, network, build, up, healthcheck |
| Docker Compose + monorepo | docker-compose.yml en subdirectorio de monorepo | sparse checkout, network, build, up, healthcheck |
| Go + systemd | `go.mod` + archivos `.service` | clone, go build, copiar binario y .service, systemctl |
| Node.js + systemd | `package.json` + archivos `.service` | clone, npm install, build, copiar .service, systemctl |
| Node.js + Docker | `package.json` + `Dockerfile` + `docker-compose.yml` | clone, network, build, up, healthcheck |
| Python + Docker | `requirements.txt`/`pyproject.toml` + `docker-compose.yml` | clone, network, build, up, healthcheck |
| Rust + Docker | `Cargo.toml` + `Dockerfile` + `docker-compose.yml` | clone, network, build, up, healthcheck |
| Rust + systemd | `Cargo.toml` + archivos `.service` | clone, cargo build --release, copiar binario y .service, systemctl |
| Estatico + Docker | `nginx.conf` + `Dockerfile` | clone, network, build, up, healthcheck |
| Multi-componente | Multiples subdirectorios con docker-compose | clone, instalar cada componente en orden |

### Regla de Traefik

Todo servicio que exponga una interfaz web se rutea a traves de Traefik como reverse proxy. La skill:

- Extrae los labels de Traefik del docker-compose.yml si existen
- Si faltan labels en un proyecto que expone web, lo marca como error de configuracion y sugiere los labels necesarios
- Incluye instrucciones de DNS en el resultado final (Tailscale, DNS publico, desarrollo local)

### Estructura del install.sh generado

```
Header con uso y requisitos
Config (variables editables al inicio)
Colores y funciones de log (info/ok/warn/error)
Banner del proyecto
Verificacion de dependencias
Manejo de instalacion previa (backup .env, docker compose down)
Clone del repositorio (sparse checkout si es monorepo)
Restaurar .env desde backup
Build y deploy segun tipo de proyecto
Health check con reintentos
Resultado final con URLs, DNS y comandos utiles
```

### Estructura del DEPLOY.md generado

```
Instalacion rapida (curl | bash)
Requisitos con versiones
Arquitectura (componentes, conexiones)
Variables de entorno (tabla)
Servicios (tabla)
Red y acceso (Traefik, DNS, 3 opciones de acceso)
Comandos utiles
Actualizacion
Troubleshooting
Estructura del proyecto
```

## Deploy

La skill se instala copiando un unico archivo. Ver [DEPLOY.md](DEPLOY.md) para instrucciones completas, instalacion manual y troubleshooting.

```bash
curl -sL https://raw.githubusercontent.com/objetiva-comercios/claude-code-skill-proyecto-generar-deploy/main/install.sh | bash
```

## Arquitectura del proyecto

```
claude-code-skill-proyecto-generar-deploy/
├── SKILL.md       # Especificacion de la skill (432 lineas, 6 pasos)
├── install.sh     # Script de instalacion automatica
├── DEPLOY.md      # Documentacion de deploy
├── README.md      # Este archivo
└── .gitignore     # Exclusiones de git
```

La skill instalada vive en:

```
~/.claude/skills/generar-deploy/
└── SKILL.md       # Claude Code la detecta automaticamente
```
