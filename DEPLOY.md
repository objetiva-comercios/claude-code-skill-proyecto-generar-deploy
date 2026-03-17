# Deploy — generar-deploy

## Instalacion rapida

```bash
curl -sL https://raw.githubusercontent.com/objetiva-comercios/claude-code-skill-proyecto-generar-deploy/main/install.sh | bash
```

## Requisitos

- git
- [Claude Code](https://claude.com/claude-code) instalado (directorio `~/.claude/` debe existir)

## Arquitectura

Este proyecto es una **skill de Claude Code** — un archivo SKILL.md que extiende las capacidades de Claude Code con instrucciones especializadas para generar documentacion de deploy y scripts de instalacion.

```
Repositorio (GitHub)
    └── SKILL.md          # Definicion de la skill (432 lineas)

Se instala en:
    ~/.claude/skills/generar-deploy/
        └── SKILL.md      # Claude Code la detecta automaticamente
```

No hay servicios, contenedores, ni procesos. La skill se carga en memoria cuando Claude Code la necesita.

## Que hace la skill

Cuando se activa en cualquier proyecto, genera dos archivos:

| Archivo | Proposito |
|---------|-----------|
| `install.sh` | Script autonomo ejecutable via `curl \| bash` |
| `DEPLOY.md` | Documentacion completa del deploy del proyecto |

### Tipos de proyecto soportados

| Tipo | Deteccion |
|------|-----------|
| Docker Compose | `docker-compose.yml` presente |
| Docker Compose + monorepo | docker-compose.yml en subdirectorio de monorepo |
| Go + systemd | `go.mod` + archivos `.service` |
| Node.js + systemd | `package.json` + archivos `.service` |
| Node.js + Docker | `package.json` + `Dockerfile` + `docker-compose.yml` |
| Python + Docker | `requirements.txt`/`pyproject.toml` + `docker-compose.yml` |
| Rust + Docker | `Cargo.toml` + `Dockerfile` + `docker-compose.yml` |
| Rust + systemd | `Cargo.toml` + archivos `.service` |
| Estatico + Docker | `nginx.conf` + `Dockerfile` |
| Multi-componente | Multiples subdirectorios con docker-compose |

## Instalacion manual

Si se prefiere no usar el script:

```bash
mkdir -p ~/.claude/skills/generar-deploy
curl -sL https://raw.githubusercontent.com/objetiva-comercios/claude-code-skill-proyecto-generar-deploy/main/SKILL.md \
  -o ~/.claude/skills/generar-deploy/SKILL.md
```

## Comandos utiles

```bash
# Verificar que la skill esta instalada
cat ~/.claude/skills/generar-deploy/SKILL.md | head -12

# Reinstalar (actualizar a ultima version)
curl -sL https://raw.githubusercontent.com/objetiva-comercios/claude-code-skill-proyecto-generar-deploy/main/install.sh | bash

# Desinstalar
rm -rf ~/.claude/skills/generar-deploy/
```

## Actualizacion

Correr el mismo comando de instalacion — el script sobreescribe el SKILL.md con la version mas reciente del repositorio:

```bash
curl -sL https://raw.githubusercontent.com/objetiva-comercios/claude-code-skill-proyecto-generar-deploy/main/install.sh | bash
```

## Troubleshooting

| Problema | Solucion |
|----------|----------|
| La skill no aparece en Claude Code | Verificar que `~/.claude/skills/generar-deploy/SKILL.md` existe. Reiniciar la sesion de Claude Code |
| Error "~/.claude/ no encontrado" | Instalar Claude Code primero desde https://claude.com/claude-code |
| El curl no funciona | Verificar que el repo es publico o usar `git clone` + `bash install.sh` |
| La skill no se activa con mi frase | Probar con `/generar-deploy` directamente o "genera el deploy" |
| Carpeta con nombre incorrecto tras `git clone` directo | El install.sh detecta y elimina `~/.claude/skills/claude-code-skill-proyecto-generar-deploy/` automaticamente, reinstalando en la carpeta correcta `generar-deploy/`. Si hiciste clone manual, correr el install.sh para corregirlo |

## Estructura del proyecto

```
claude-code-skill-proyecto-generar-deploy/
├── SKILL.md       # Especificacion de la skill (se instala en ~/.claude/skills/)
├── install.sh     # Script de instalacion automatica
├── DEPLOY.md      # Este archivo
├── README.md      # Documentacion del proyecto
└── .gitignore     # Exclusiones de git
```
