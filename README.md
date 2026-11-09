# GabriPlay

Web oficial de GabriPlay, publicada con GitHub Pages.

**Web:** https://gabriel10mp.github.io/GabriPlay-Web/  
**YouTube:** https://www.youtube.com/@GabriPlay10

## Secciones

- Inicio, vídeos y contenido de GTA V y Roblox.
- Comunidad con cuentas, perfiles y sugerencias.
- Perfiles públicos con temas, insignias y enlaces.
- Tienda de efectos de nombre y marcos de avatar.
- Paneles privados de administración y creador.

## Desarrollo

El proyecto usa HTML, CSS y JavaScript sin un proceso de compilación. Supabase proporciona autenticación, base de datos y almacenamiento.

- `index.html`: portada y comunidad.
- `perfil.html`: editor de perfil.
- `usuario.html?u=nombre`: perfil público.
- `tienda.html`: tienda de cosméticos.
- `admin.html`: moderación.
- `creador.html`: herramientas del creador.
- `supabase/`: migraciones SQL documentadas.
- `scripts/validate-site.mjs`: comprobaciones de calidad.

## Publicación

Los cambios en `main` se publican mediante GitHub Pages. GitHub Actions actualiza `version.json` para que las páginas abiertas detecten una nueva versión.

## Comprobaciones automáticas

El workflow **GabriPlay site quality** valida:

- Sintaxis de JavaScript incrustado.
- IDs HTML duplicados.
- Referencias locales a archivos inexistentes.
- Metadatos básicos y restos de saltos de línea escapados.

Ejecutar localmente:

```bash
node scripts/validate-site.mjs
```

## Supabase y seguridad

Las claves públicas de Supabase pueden estar en el frontend; nunca se deben añadir contraseñas de base de datos, claves `service_role` ni secretos privados al repositorio.

Las operaciones sensibles de puntos, compras, equipamiento y herramientas de creador se ejecutan mediante funciones SQL con validación en servidor y políticas RLS. Las migraciones existentes están en `supabase/`.
