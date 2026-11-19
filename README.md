# INFORMES MAX
Aplicación PWA para asignación, atención, revisión y cierre de tickets de mantenimiento.

## Flujo operativo
1. El supervisor crea el ticket, registra el inicio, completa los datos iniciales y asigna un técnico.
2. El técnico ve únicamente los tickets que tiene asignados. Los datos originales son de solo lectura.
3. El técnico agrega fotos, descripciones, trabajo realizado, personal, materiales, tiempo efectivo y observaciones. Envía el ticket a revisión.
4. El supervisor revisa y corrige la información, registra la fecha/hora final y cierra el ticket.
5. Al cerrar, la aplicación genera el PDF final y lo guarda de forma privada en Supabase Storage. El PDF queda asociado al ticket para futuras consultas.

## Indicadores
- Total de tickets, asignados/en atención, pendientes de revisión y cerrados.
- Promedio de tiempo transcurrido entre inicio y cierre.
- Promedio del tiempo efectivo declarado por los técnicos.
- Comparación de tiempo transcurrido frente al tiempo declarado.
- Tickets por técnico y filtros por fechas.
- Buscador combinado por ticket, cliente, servicio, técnico, causa y descripción.

## Datos y seguridad
- Proyecto Supabase independiente de MOVILMAX.
- PostgreSQL guarda datos y metadatos; fotografías y PDFs se almacenan en buckets privados.
- RLS limita la lectura de tickets asignados al técnico y de todos los tickets al supervisor.
- El técnico envía sus campos mediante la función SQL `submit_technician_work`; no puede cambiar los datos iniciales ni cerrar tickets.
- Los PDFs finales solo pueden leerse/subirse por supervisores.
- Nunca subir `service_role` ni contraseñas al repositorio.

## Configuración de Supabase
1. Crear un proyecto nuevo para INFORMES MAX en Supabase.
2. En SQL Editor ejecutar el archivo `supabase/schema.sql`. Este script añade las columnas y políticas del nuevo flujo al esquema anterior.
3. Crear el primer usuario en Authentication > Users y registrar su perfil supervisor con el INSERT comentado al final del SQL.
4. Desplegar la función de administración:
   `supabase functions deploy admin-create-user`
5. Configurar los secretos `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` para la Edge Function. La service role key debe permanecer solo en secretos de Supabase.
6. Copiar `config.example.js` como `config.js` y colocar URL y anon key del proyecto.
7. Publicar el repositorio con GitHub Pages (Settings > Pages > Deploy from branch > main > /(root)).

## Importante sobre el despliegue
El código y el esquema SQL se guardan en GitHub. Crear el proyecto real de Supabase, ejecutar el SQL y poner las claves requiere acceso a la cuenta de Supabase del propietario; esos pasos no se pueden completar solo con el repositorio.
