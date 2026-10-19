# Registro de cambios

Novedades de cada versión de Glide para Mac. Glide muestra las entradas nuevas una sola vez tras actualizarse, y las notas de cada versión en GitHub salen de aquí. Esta es una traducción de CHANGELOG.md, que es el original.

## 0.9.4 — 2026-10-19

### Correcciones

- **Se acabaron los huecos al cerrar una ventana.** Cuando se cerraba o salía una ventana, una app que ignoraba parte de un movimiento (como Proton Mail) podía quedarse donde estaba y dejar un hueco. Ahora Glide comprueba dónde acaban realmente las ventanas y las coloca bien.

## 0.9.3 — 2026-10-19

### Novedades

- **Disposición en mosaico.** ⌃⌥T cambia el escritorio actual entre la tira desplazable y una disposición en mosaico, donde todas las columnas comparten la pantalla y caben a la vez, sin desplazarte. Cada escritorio conserva su propia disposición, incluso después de reiniciar Glide. Cambiar el ancho de una columna (⌃⌥R) le da una parte mayor o menor, arrastrar su borde la redimensiona, y ⌃⌥F sigue poniéndola a ancho completo hasta que lo pulses de nuevo.
- **Elige la disposición con la que empiezan los escritorios nuevos** en Ajustes › General › Disposición: Desplazable, como hasta ahora, o Mosaico. Los escritorios que hayas cambiado con ⌃⌥T conservan la suya.

## 0.9.2 — 2026-10-16

### Novedades

- **Novedades también habla tu idioma.** Las notas que Glide muestra tras una actualización, y en Novedades, ahora están en el mismo idioma que el resto de Glide.

## 0.9.1 — 2026-10-16

### Novedades

- **Glide habla tu idioma.** Glide ya está disponible en francés, alemán, japonés, chino simplificado, coreano y portugués de Brasil, además de inglés y español, y sigue el idioma que prefieras en macOS.

## 0.9.0 — 2026-10-15

Glide para Mac ahora comparte los números de versión con Glide para Windows.

### Novedades

- **Todos los atajos en una sola página.** ⌃⌥/ los muestra todos; púlsalo otra vez, pulsa Esc o haz clic fuera para cerrarla. También está en el menú de la barra de menús, al principio de Atajos.
- **Informar de un problema**, en el menú de la barra de menús y en Ajustes › General. Glide guarda su registro reciente y sus ajustes en un zip, sin los títulos de las ventanas, lo muestra en el Finder y abre una incidencia nueva en GitHub para que describas lo ocurrido y adjuntes el zip. No se envía nada por sí solo.
- **Glide habla español.** Si macOS está en español, Glide también. Novedades sigue en inglés.

### Correcciones

- **La pantalla completa sigue siendo pantalla completa.** Una ventana que pones a pantalla completa, o un vídeo o un juego que ocupa toda la pantalla, ya no vuelve a su columna a la fuerza. Glide la deja en paz, oculta sobre ella el borde de foco, la atenuación y la barra de pestañas, y deja que la rueda horizontal y los gestos de tres dedos de esa pantalla le lleguen. Cuando sale de la pantalla completa, vuelve a su columna.

## 0.4.0 — 2026-10-14

### Novedades

- **Mira dónde caerá una ventana que arrastras.** Mientras arrastras una ventana, un contorno del color del borde de foco muestra la columna a la que se uniría, con su barra de pestañas incluida. Sobre otra pantalla, una barra indica dónde iría entre las columnas de esa pantalla. Si no hay nada resaltado, volverá a su sitio.

## 0.3.0 — 2026-10-14

### Novedades

- **Todas las pantallas en mosaico.** Cada pantalla tiene su propia tira y sus propios nueve escritorios. Los atajos actúan en la pantalla que tiene la ventana con el foco, o en la que está bajo el puntero. ⌃⌥⌘←/→ mueven el foco a la pantalla de ese lado, y ⌃⌥⌘⇧←/→ envían allí la columna enfocada. Las ventanas nuevas se unen a la pantalla en la que se abren.
- **Arrastra una ventana adonde quieras.** Suéltala sobre una barra de pestañas y se convierte en una pestaña de ella; suéltala sobre otra ventana y se apila en la columna de esa ventana; suéltala en otra pantalla y se une a la tira de esa pantalla. Una ventana flotante que sueltas sobre un mosaico se une a los mosaicos. En cualquier otro sitio, vuelve a su lugar como antes.
- **La rueda del ratón recorre la tira.** Inclina la rueda (o usa una rueda para el pulgar) para moverte por la tira, o mantén ⌃⌥ mientras te desplazas. Elige cuándo lo hace la inclinación en Ajustes › Rueda horizontal del ratón: Siempre, Con ⌃⌥ o Desactivada.
- **Las apps se abren donde las tienes.** Glide recuerda la pantalla, el escritorio, el ancho de columna y el lugar en la tira de cada app, y abre allí sus ventanas nuevas. Desactívalo, u olvida todos los sitios, en Ajustes.
- **Grosor del borde de foco**, de 1 a 12 puntos, en Ajustes › Apariencia.

## 0.2.1 — 2026-10-14

### Novedades

- **Novedades.** Tras una actualización, Glide te muestra qué ha cambiado. Vuelve a encontrarlo en la barra de menús, en **Novedades**.

## 0.2.0 — 2026-10-14

### Novedades

- **Glide se mantiene al día solo.** Busca una versión nueva una vez al día y te la ofrece, o la instala por ti si lo activas en Ajustes › Actualizaciones. **Buscar actualizaciones…** en el menú busca al momento. Todas las actualizaciones están firmadas y notarizadas por Apple.
- **Glide es de código abierto**, con licencia MIT: [github.com/QuackByte/glide](https://github.com/QuackByte/glide).

## 0.1.1 — 2026-10-13

### Correcciones

- Al cerrar y volver a abrir Chrome, T3 Code u otra app de Chromium o Electron, el foco se quedaba en la ventana anterior y la ventana nueva aparecía fuera de la pantalla. Ahora recibe el foco y se desplaza hasta quedar a la vista.

## 0.1.0 — 2026-10-13

La primera versión de Glide para Mac.

- **Columnas en una tira que se desplaza**: anchos de ⅓, ½, ⅔ y completo, pilas y columnas con pestañas, con un atajo para todo.
- **Nueve escritorios**, una vista general con previsualizaciones en directo, gestos de tres dedos, un borde de foco, reglas por app y un vigilante que devuelve tus ventanas a su sitio si Glide se cierra inesperadamente.
