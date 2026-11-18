# INFORMES MAX

Aplicación PWA independiente para registrar informes técnicos de averías. No utiliza la base de datos ni las cuentas de MOVILMAX.

## Funciones incluidas
- Acceso con usuario y contraseña (cuentas independientes).
- Perfiles técnico y supervisor con políticas RLS.
- Registro de ticket, cliente, servicio, fechas, causa, descripción, solución, personal, materiales y observaciones.
- Hasta 8 evidencias fotográficas; cámara del móvil o galería; vista previa en dos columnas.
- Almacenamiento privado de fotografías y enlaces firmados temporales.
- Exportación a PDF mediante impresión del navegador y a Excel.
- Diseño adaptable y PWA instalable.

## Configuración necesaria
1. Crear un proyecto Supabase NUEVO para INFORMES MAX.
2. En SQL Editor ejecutar `supabase/schema.sql`.
3. Copiar `config.example.js` como `config.js` y completar URL y anon key del proyecto.
4. Desplegar la función `admin-create-user`:
   `supabase functions deploy admin-create-user`
5. Configurar secretos de la función con los valores del proyecto:
   `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.
   La service role key se guarda solo como secreto de Supabase; nunca en el frontend ni en GitHub.
6. Crear el primer usuario en Authentication > Users, copiar su UUID y crear su perfil supervisor con el INSERT comentado al final de schema.sql.
7. Publicar el repositorio con GitHub Pages (Settings > Pages > Deploy from branch > main > /(root)).

## Nota sobre la plantilla Excel
La estructura inicial del formulario recoge los campos del informe compartido. La reproducción exacta del diseño visual y de las posiciones de celdas/fotos de la plantilla debe verificarse contra el archivo original antes de darla por finalizada.

## Seguridad
- No subir contraseñas de usuarios ni claves service_role.
- El proyecto Supabase debe ser distinto al de MOVILMAX.
- El bucket de evidencias es privado y las imágenes se muestran mediante signed URLs.
