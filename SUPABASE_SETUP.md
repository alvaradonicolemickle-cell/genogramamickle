# Configurar archivos compartidos

Las fotos y documentos se publican para lectura pública. Solo la cuenta administradora indicada en las políticas puede cargar, reemplazar o eliminar archivos. No subas documentos que no deban ser visibles para cualquier visitante.

1. Crea un proyecto en Supabase.
2. Abre `supabase-setup.sql`, reemplaza cada `OWNER_EMAIL_HERE` por el correo exacto de la cuenta administradora y ejecuta el script en el SQL Editor de Supabase.
3. En Authentication, crea el usuario administrador con ese correo y una contraseña. Desactiva el registro público de usuarios.
4. En Project Settings > API, copia el Project URL y la clave pública `anon`/publishable en `supabase-config.js`, en `url` y `anonKey`.
5. Publica juntos `index.html`, `Tritopani.otf` y `supabase-config.js`. El navegador debe tener acceso a Internet para cargar el cliente de Supabase.
6. Vuelve a ejecutar el `supabase-setup.sql` actualizado en el SQL Editor de Supabase para habilitar el registro de actividad. El script puede ejecutarse más de una vez.
7. Busca una persona, abre su ficha e inicia sesión en «Administrar archivos». Luego usa «Cambiar foto» o «Agregar documentos». En una página de familia, usa «Administrar foto familiar» para iniciar sesión y cargar su retrato.

La clave `anon`/publishable está diseñada para usarse en el navegador; las políticas SQL restringen las escrituras al correo administrador. Nunca pongas la clave `service_role` en `supabase-config.js` ni en el HTML.

Las fotos y documentos publicados son visibles para todos. Cada archivo admite hasta 10 MB. Los archivos guardados previamente solo en IndexedDB de este dispositivo no se migran automáticamente: cuando Supabase esté configurado, vuelve a cargarlos desde la ficha para compartirlos.

La sección «Actividad reciente» registra automáticamente las cargas y eliminaciones de fotos/documentos. También detecta altas, cambios y eliminaciones de personas, además de cambios en los vínculos, cuando el administrador abre la versión publicada con su sesión activa. La primera sincronización crea una referencia inicial y no llena la actividad con las 83 fichas existentes.
