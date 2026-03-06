# generar-deploy

Skill para Claude Code que genera documentacion de deploy (`DEPLOY.md`) y un script de
instalacion automatica (`install.sh`) para cualquier proyecto. Analiza el tipo de proyecto,
lee toda la documentacion disponible (`.planning/`, archivos `.md`, configuraciones) e
identifica los archivos involucrados en la ejecucion (Docker Compose, package.json, go.mod,
systemd, etc.) para producir archivos adaptados y funcionales. El objetivo es que cualquier
proyecto se pueda instalar desde una maquina remota con un solo comando
`curl -sL <url>/install.sh | bash`.

## Tecnologias

| Categoria | Tecnologia |
|-----------|------------|
| Plataforma | Claude Code (skill) |
| Framework de planificacion | Get Shit Done (GSD) |
| Infraestructura soportada | Docker Compose, systemd, Traefik, Tailscale |
| Lenguajes de proyecto soportados | Node.js, Go, Python, Rust, multi-componente |
| Formato de salida | Bash (install.sh), Markdown (DEPLOY.md) |

## Requisitos previos

- [Claude Code](https://claude.com/claude-code) instalado
- La skill debe estar en `~/.claude/skills/generar-deploy/SKILL.md`

## Instalacion

La skill se instala copiando el archivo `SKILL.md` al directorio global de skills:

```bash
mkdir -p ~/.claude/skills/generar-deploy
cp SKILL.md ~/.claude/skills/generar-deploy/SKILL.md
```

Claude Code la detecta automaticamente en la proxima sesion.

## Activacion

La skill se activa con cualquiera de estas frases:

| Trigger | Ejemplo |
|---------|---------|
| Comando directo | `/generar-deploy` |
| Pedir deploy | "genera el deploy", "prepara el deploy" |
| Pedir instalador | "haceme el install.sh", "quiero poder instalar esto con curl" |
| Pedir documentacion de deploy | "genera la doc de deploy", "deploy docs" |
| Preparar produccion | "prepara el proyecto para produccion" |
| Instalacion remota | "como se instala esto", "install script" |

## Uso

Desde la carpeta de cualquier proyecto, ejecutar `/generar-deploy` o pedirlo con lenguaje natural. La skill ejecuta 6 pasos:

### Flujo de trabajo

1. **Recolectar informacion** — Lee `.planning/`, README, CLAUDE.md, docker-compose.yml, package.json, go.mod, .env.example, archivos .service, y cualquier documentacion disponible
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
| Python + Docker | `requirements.txt` + `docker-compose.yml` | clone, network, build, up, healthcheck |
| Estatico + Docker | `nginx.conf` + `Dockerfile` | clone, network, build, up, healthcheck |
| Multi-componente | Multiples subdirectorios con docker-compose | clone, instalar cada componente en orden |

### Regla de Traefik

Todo servicio que exponga una interfaz web se rutea a traves de Traefik como reverse proxy. La skill:

- Extrae los labels de Traefik del docker-compose.yml si existen
- Si faltan labels en un proyecto que expone web, lo marca como error de configuracion y sugiere los labels necesarios
- Si el proyecto solo escucha en localhost (sin interfaz web externa), documenta que no necesita Traefik
- Incluye en el resultado final las instrucciones de DNS (Tailscale, DNS publico, desarrollo local)

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
Arquitectura (diagrama ASCII, componentes)
Variables de entorno (tabla)
Servicios (tabla)
Red y acceso (Traefik, DNS, 3 opciones de acceso)
Comandos utiles
Actualizacion
Troubleshooting
Estructura del proyecto
```

## Arquitectura del proyecto

```
claude-code-skill-proyecto-generar-deploy/
├── README.md                           # Este archivo
└── SKILL.md                            # Especificacion de la skill (se copia a ~/.claude/skills/)
```

La skill instalada vive en:

```
~/.claude/skills/generar-deploy/
└── SKILL.md                            # Skill activa (413 lineas, 6 pasos)
```
