// Texts of the task in Spanish and the screens
// that only show text: consent, calibration (VMAC_selective), instructions and
// reminders. Search-task texts are those of the original program, with typos
// fixed; the new screens are drafts, to be reviewed

// ---- Consent and demographics ----
const pre_consent = {
    type: jsPsychHtmlButtonResponse,
    stimulus: wrapper(`<p>¡Gracias por tu interés en participar en el estudio!</p>
    <p>Antes de comenzar, te vamos a mostrar la hoja de información del estudio y sobre el tratamiento de tus datos, así como el consentimiento informado sobre tu participación.</p>
    <p>Al terminar deberás contestar algunas breves cuestiones sociodemográficas.</p>
    <p>Cuando quieras comenzar pulsa <b>continuar</b>.</p>`, true, 80),
    choices: ['Continuar'],
}

// TO DO: information sheet and consent approved by the ethics committee
const consentInf = {
    type: jsPsychHtmlButtonResponse,
    stimulus: wrapper(`<h3>Hoja de información</h3>
    <p>[Pendiente: hoja de información del estudio y del tratamiento de los datos.]</p>`, true, 80),
    choices: ['Continuar'],
    button_html: '<button class="jspsych-btn" style = "margin-bottom:50px;">%choice%</button>'
};

const consentConf = {
    type: jsPsychHtmlButtonResponse,
    stimulus: wrapper(`<h3>Consentimiento informado</h3>
    <p>[Pendiente: texto del consentimiento informado.]</p>`, true, 80),
    choices: ['<b>Doy mi consentimiento</b>', '<b>No doy mi consentimiento</b>'],
    button_html: '<button class="jspsych-btn" style = "margin-bottom:50px;">%choice%</button>',
    on_finish: (data) => {
        not_consent = data.response == 1;
        data.phase = "consent";
        data.consent = (not_consent) ? 0 : 1;
    }
};

const out_consent = {
    type: jsPsychHtmlKeyboardResponse,
    stimulus: wrapper(`<p>Si estás leyendo esto, es que no has dado el consentimiento necesario para participar en el estudio.</p>
    <p>Si has decidido no participar, puedes cerrar esta pestaña cuando quieras.</p>`, true, 100),
    choices: "NO_KEYS",
};

const if_out_cons = {
    timeline: [out_consent],
    conditional_function: () => {
        return not_consent;
    }
}

// Age, gender and dominant hand, with the codes of the original data (gender
// m/h/n, handedness d/i)
const demo_quests = {
    type: jsPsychSurveyHtmlForm,
    preamble: `<h3 style="margin-bottom: 30px">Datos sociodemográficos</h3>`,
    html: `<div class="inst" style="text-align: left;">
    <p><label for="age">Edad:</label> <input type="number" id="age" name="age" min="18" max="100" required></p>
    <p>Género:
    <label><input type="radio" name="gender" value="m" required> Mujer</label>
    <label><input type="radio" name="gender" value="h"> Hombre</label>
    <label><input type="radio" name="gender" value="n"> Prefiero no contestar</label></p>
    <p>Mano dominante:
    <label><input type="radio" name="handedness" value="d" required> Derecha</label>
    <label><input type="radio" name="handedness" value="i"> Izquierda</label></p>
    </div>`,
    button_label: "Continuar",
    on_finish: (data) => {
        jsPsych.data.addProperties({
            age: Number(data.response.age),
            gender: data.response.gender,
            handedness: data.response.handedness,
        });
    }
};

const consent_proc = {
    timeline: [pre_consent, consentInf, consentConf, if_out_cons, demo_quests],
    repetitions: 1,
    randomize_order: false,
}

// ---- Welcome and browser ----
const welcome = {
    type: jsPsychHtmlButtonResponse,
    stimulus: wrapper(`
    <p style="margin-bottom: 2rem;">¡Bienvenida/o al experimento!</p>
    <p>Antes de empezar, es necesario que realices este experimento en una <b>habitación tranquila</b>, con el menor número de distracciones posible: <b>apaga el teléfono (o ponlo en silencio)</b>, <b>que no haya nadie más en la habitación</b> y <b>asegúrate de evitar cualquier tipo de ruido que pueda distraerte</b>.</p>
    <p>Para asegurarnos de que puedes realizar el experimento de forma correcta, por favor, cierra cualquier programa que tengas abierto y todas las pestañas del navegador que no sean el experimento.</p>
    <p style="margin-bottom: 2rem;"><b>No cierres ni recargues esta página hasta que se te indique que el experimento ha finalizado</b>.</p>
    <p style="margin-bottom: 3rem;">Una vez te asegures de cumplir con lo expresado arriba, pulsa <b>continuar</b> para empezar.</p>`),
    choices: ['Continuar'],
};

const check = {
    type: jsPsychBrowserCheck,
    minimum_width: 1000,
    minimum_height: 500,
    window_resize_message: `
    <p>La ventana de tu navegador es demasiado pequeña para completar este experimento. En caso de que estés haciendo el experimento en una tablet o teléfono móvil, cierra la ventana y sal del experimento.</p>
    <p>En caso de que estés haciendo el experimento en un ordenador, maximiza el tamaño de la ventana de tu navegador <b>pulsando la tecla F11</b>. Si la ventana de tu navegador ya tiene su tamaño máximo, no podrás acceder al experimento.</p>
    <p>La anchura mínima de la ventana es de <span id="browser-check-min-width"></span> px.</p>
    <p>La anchura de tu ventana es de <span id="browser-check-actual-width"></span> px.</p>
    <p>La altura mínima de la ventana es de <span id="browser-check-min-height"></span> px.</p>
    <p>La altura de tu ventana es de <span id="browser-check-actual-height"></span> px.</p>`,
    resize_fail_button_text: `No puedo ajustar la pantalla`,
    inclusion_function: (data) => {
        return data.mobile == false;
    },
    exclusion_message: (data) => {
        if (data.mobile) {
            return '<p>Debes hacer el experimento en un ordenador o un portátil.</p> <p>Puedes cerrar esta página cuando quieras.</p>';
        }
        return `<p>No cumples con los requisitos para participar en este experimento.</p> <p>Puedes cerrar esta página cuando quieras.</p>`
    },
    on_finish: (data) => {
        jsPsych.data.addProperties({
            browser: data.browser,
            browser_version: data.browser_version,
            os: data.os,
            window_width: data.width,
            window_height: data.height,
            vsync_rate: data.vsync_rate,
        });
    }
};

// ---- Calibration (VMAC_selective) ----
const instructions_cal = {
    type: jsPsychInstructions,
    pages: [
        wrapper(`<p>Antes de comenzar con el experimento vas a realizar una breve fase de calibración, que va a consistir en dos pequeñas pruebas.
        Con la calibración vamos a ajustar el tamaño de los estímulos que te vamos a presentar a la distancia a la que te encuentras de la pantalla. Ahora vamos a explicarte cómo vamos a realizar este procedimiento antes de llevarlo a cabo.</p>
        <p>Antes de empezar con la calibración, <b>asegúrate de adoptar una posición que te permita extender las manos al teclado con comodidad</b>. Además, <b>debes intentar centrarte lo máximo que
        puedas en la pantalla de tu ordenador</b>. Intenta mantenerte en esa postura durante todo el experimento.</p>`),
        wrapper(`<p>La primera prueba va a consistir en ajustar un objeto presentado por pantalla a una tarjeta con un tamaño estandarizado. Servirán tarjetas de crédito/débito, carné de conducir o DNI.
        Deberás utilizar una de dichas tarjetas para hacer que la tarjeta que aparezca por pantalla tenga el mismo tamaño. Para ello, puedes <b>arrastrar la esquina inferior derecha de la tarjeta para cambiar su tamaño</b>.</p>
        <p>Puedes probar a ajustar el tamaño de la tarjeta para practicar antes de proceder con la calibración:</p>
        <div id="item" style="border: none; height: 200px; width: ${aspect_ratio * 200}px; background-color: #ddd; position: relative; background-image: url('src/img/dni.jpg'); background-size: 100% auto; background-repeat: no-repeat;">
            <div id="jspsych-resize-handle" style="cursor: nwse-resize; background-color: none; width: 25px; height: 25px; border: 5px solid red; border-left: 0; border-top: 0; position: absolute; bottom: 0; right: 0;">
            </div>
        </div>
        <p>En caso de que no tengas ninguna tarjeta, también es posible utilizar una regla. Si optas por una regla, deberás ajustar la tarjeta para que tenga una anchura de 85.6 milímetros.</p>`),
        wrapper(`<p>En la segunda prueba vamos a estimar dónde se encuentra tu punto ciego visual, cuya posición va a depender de la distancia a la que te encuentres de la pantalla. Por tanto, esta prueba es fundamental para poder ajustar el tamaño de los estímulos de la tarea en pantalla.</p>
        <p>Para que puedas familiarizarte con la tarea antes de la calibración, aquí te presentamos el procedimiento que vas a tener que llevar a cabo para que puedas practicar. Asegúrate de estar en una posición correcta (espalda erguida y la cabeza centrada en la pantalla).</p>
        <p>Intenta encontrar tu punto ciego antes de empezar la calibración:</p>
        <ol style="max-width:100%;">
        <li>Pon la mano izquierda en la <b>barra espaciadora</b>.</li>
        <li>Mira al centro de la pantalla.</li>
        <li>Tápate el ojo derecho con la mano derecha.</li>
        <li>Atiende al cuadrado negro con el ojo izquierdo mientras mantienes tu cabeza orientada al centro de la pantalla. No dejes de mirarlo.</li>
        <li>Cuando pulses la barra espaciadora el <b style = "color:red;">círculo rojo</b> comenzará a moverse. Atiende al círculo de reojo.</li>
        <li>Pulsa la barra espaciadora cuando percibas que el círculo desaparece con seguridad (<b>al menos durante 1 segundo</b>), no en cuanto desaparezca.</li>
        </ol>
        <div id="virtual-chinrest-circle" style="position: absolute;background-color: #f00; width: 30px; height: 30px; border-radius:50px;"></div>
        <div id="virtual-chinrest-square" style="position: absolute;background-color: #000; width:30px; height:30px"></div>
        `, false, 100, true),
        wrapper(`<p>Si quieres repasar las instrucciones, pulsa <b>retroceder</b> para volver a leerlas.</p>
        <p>Si no, pulsa <b>seguir</b> para empezar con la calibración.</p>`, true)
    ],
    allow_keys: false,
    button_label_previous: "Retroceder",
    button_label_next: "Seguir",
    show_clickable_nav: true,
    on_load: () => {
        // Animate ball instructions
        document.addEventListener("click", setBall);
        document.addEventListener("keydown", cal_c);
        document.addEventListener("click", ResizePhase);
    },
    on_finish: () => {
        document.removeEventListener("click", setBall);
        document.removeEventListener("keydown", cal_c);
        document.removeEventListener("click", ResizePhase);
        state = false;
    }
}

const full_on = {
    type: jsPsychFullscreen,
    fullscreen_mode: true,
    message: `<p>Antes de empezar con la calibración, vamos a pasar a modo pantalla completa.</p>
    <p>En caso de que accidentalmente salgas del modo pantalla completa, puedes volver a activarlo pulsando la tecla <b>F11</b>.</p>
    <p>Pulsa el botón <b>pantalla completa</b> para empezar con la calibración.</p>`,
    button_label: "Pantalla completa",
};

const full_off = {
    type: jsPsychFullscreen,
    fullscreen_mode: false,
};

// Virtual chin-rest
const resize = {
    type: jsPsychVirtualChinrest,
    blindspot_reps: 5,
    resize_units: "none",
    post_trial_gap: 500,
    ball_speed: .5,
    viewing_distance_report: "none",
    item_path: 'src/img/dni.jpg',
    adjustment_prompt: `
    <div style="text-align: left;">
    <p>Haz clic y arrastra la esquina inferior derecha de la imagen hasta que tenga el mismo tamaño que una tarjeta de tamaño estandarizado sostenida contra la pantalla.</p>
    <p>Si no tienes acceso a una tarjeta real, puedes utilizar una regla para medir la anchura de la imagen. Debes asegurarte de que la anchura es de 85.6 mm (8.56 cm).</p>
    </div>`,
    adjustment_button_prompt: `Haz clic aquí cuando la imagen tenga el tamaño correcto`,
    blindspot_prompt: `<p>Ahora vamos a medir a qué distancia te encuentras de la pantalla:</p>
    <div>
    <ol style="max-width:90%; text-align: left;">
    <li>Pon la mano izquierda en la <b>barra espaciadora</b>.</li>
    <li>Mira al centro de la pantalla.</li>
    <li>Tápate el ojo derecho con la mano derecha.</li>
    <li>Atiende al cuadrado negro con el ojo izquierdo mientras mantienes tu cabeza orientada al centro de la pantalla. No dejes de mirarlo.</li>
    <li>Cuando pulses la barra espaciadora el <b style = "color:red;">círculo rojo</b> comenzará a moverse. Atiéndelo de reojo.</li>
    <li>Pulsa la barra espaciadora cuando percibas que el círculo desaparece con seguridad (<b>al menos durante 1 segundo</b>), no en cuanto desaparezca.</li>
    </ol>
    </div>
    <p style = "margin-bottom: 30px;">Pulsa la barra espaciadora para empezar.</p>`,
    blindspot_measurements_prompt: `repeticiones pendientes: `,
    on_finish: (data) => {
        viewDist = data.view_dist_mm;
        console.log(`Participant viewing distance: ${viewDist}.`)
        console.log(`Participant px2deg: ${data.px2deg}.`)
        fail_cal = (data.view_dist_mm < view_dist_range[0] || data.view_dist_mm > view_dist_range[1]);
        if (!fail_cal) {
            px2deg = data.px2deg;
            jsPsych.data.addProperties({
                px2deg: data.px2deg,
                viewing_distance: data.view_dist_mm,
            });
        } else {
            console.log(`Redo calibration.`)
        }
    }
};

const repeat_cal = {
    type: jsPsychHtmlButtonResponse,
    stimulus: () => {
        const distance = viewDist;
        return `<p>Hemos estimado que te encuentras a la siguiente distancia de la pantalla: ${parseInt(distance / 10)} cm.</p>
        <p>Esto significa que te encuentras muy cerca o muy lejos de la pantalla, o que no hemos conseguido estimar correctamente la distancia real a la que te encuentras.</p>
        <p>Dado que esta calibración es crítica para hacer correctamente el experimento, te vamos a pedir que la vuelvas a realizar.</p>
        <p>En caso de que realmente te encontrases a ${parseInt(distance / 10)} cm de la pantalla, por favor, colócate a una distancia de entre <b>${view_dist_range[0] / 10} y ${view_dist_range[1] / 10} cm</b> para poder realizar la tarea con comodidad, y mantén una postura similar durante el experimento.</p>`
    },
    choices: ["Volver a realizar la calibración"],
}

const if_repeat_cal = {
    timeline: [repeat_cal],
    conditional_function: () => {
        return fail_cal;
    }
}

// ---- Instructions of the search task (original texts) ----
const TITLE_INSTRUCTIONS = `<h2>INSTRUCCIONES</h2>`;

const INSTRUCTIONS_1 = `
<p>Este experimento pretende estudiar tu capacidad para encontrar objetos rápidamente en la pantalla.</p>
<p>En cada ensayo, te mostraremos ocho figuras (un círculo y siete rombos o viceversa). Tu tarea será encontrar la figura que es distinta a las demás.</p>
<p>A lo largo de la tarea verás que los estímulos pueden aparecer en diferentes colores. Estos colores son irrelevantes para ti. Tu objetivo es buscar la figura que es diferente de las demás, independientemente del color.</p>
<p>En las siguientes pantallas podrás ver algunos ejemplos en los que la figura diferente estará rodeada con un círculo azul para que puedas identificarla.</p>`;

// Load group: the response window, added after the first paragraph (draft)
const instructions_2 = (window_ms) => `
<p>Cada ensayo comenzará con un punto de fijación en el centro de la pantalla. Intenta mirar fijamente al punto antes de que aparezcan las figuras. Cuando aparezcan, por favor, busca la figura única tan rápidamente como te sea posible. Cuando la encuentres, responde con precisión a la orientación de la línea que contiene.</p>
${(window_ms != null) ? `<p>En cada ensayo tendrás un máximo de ${window_ms / 1000} segundos para responder.</p>` : ""}
<p>Si cometes un error, aparecerá un mensaje en la pantalla durante unos segundos. Por favor, evita cometer errores a lo largo de la tarea ya que harán que su duración sea mayor.</p>
<p>A continuación, podrás realizar unos cuantos ensayos de práctica.</p>
<p>El experimento completo lleva aproximadamente cuarenta y cinco minutos.</p>`;

const EXAMPLE_OF = (i, n) => `<p class="hint">Ejemplo ${i} de ${n}</p>`;

// Response keys (text of Diapositiva5.JPG), with the lines of the task and the
// two arrow keys, plus the finger placement
const keys_page = () => wrapper(`
<p>Cuando encuentres esa figura diferente, observarás que en su interior hay una línea recta. Tu tarea es fijarte en la orientación de esa línea recta y dar una de estas dos respuestas.</p>
<div class="keys">
    <div><p>Si la línea es vertical…</p>${bar_html("vertical")}<p>… pulsa la tecla <span class="keycap">&#8593;</span></p></div>
    <div><p>Si la línea es horizontal…</p>${bar_html("horizontal")}<p>… pulsa la tecla <span class="keycap">&#8592;</span></p></div>
</div>
<p>que encontrarás en la parte inferior derecha de tu teclado.</p>
<p><b>Coloca el dedo índice de tu mano derecha sobre la flecha hacia la izquierda y el dedo corazón sobre la flecha hacia arriba, y mantenlos ahí durante la tarea.</b></p>`);

const QUIZ_INTRO = `<p>Antes de continuar, responde a unas breves preguntas para comprobar que has comprendido las instrucciones.</p>`;
const QUIZ_PASSED = `<p>Has respondido correctamente a todas las preguntas.</p>`;
const QUIZ_FAILED = `<p>Alguna de tus respuestas no es correcta.</p>
<p>Vuelve a leer las instrucciones con atención; después, responderás de nuevo a las preguntas.</p>`;

// ---- Counting task (load group; drafts) ----
const COUNT_INSTRUCTIONS = [
    `<p>Además de buscar la figura diferente, tendrás que llevar una cuenta mientras haces la tarea.</p>
    <p>La tarea se dividirá en periodos de unos pocos ensayos. Al principio de cada periodo, te indicaremos una orientación: vertical u horizontal. Durante ese periodo, responde como siempre a la línea de la figura diferente y, además, cuenta cuántas veces esa línea tiene la orientación indicada.</p>`,
    `<p>Al final de cada periodo aparecerá un número. Pulsa S si ese número coincide con tu cuenta, o N si no coincide. Después, vuelve a colocar los dedos sobre las flechas.</p>
    <p>Luego empezará un nuevo periodo, y tendrás que empezar a contar desde cero.</p>
    <p>A continuación, podrás practicar con un periodo. Antes, responde a unas breves preguntas para comprobar que has comprendido la tarea.</p>`];
const ORIENTATION_WORD = {vertical: "VERTICAL", horizontal: "HORIZONTAL"};

// ---- Comprehension checks (as in VMAC_selective): if any answer is wrong, the
// instructions are shown again. The first option is the correct one; questions
// and options are shuffled ----
const SEARCH_QUIZ = [
    {name: "key", prompt: "¿Qué tecla debes pulsar si la línea de la figura diferente es vertical?",
     options: ["La flecha hacia arriba", "La flecha hacia la izquierda", "La barra espaciadora"]},
    {name: "target", prompt: "¿Qué figura debes buscar en cada ensayo?",
     options: ["La figura con una forma diferente a las demás", "La figura con un color diferente a las demás",
               "Cualquier figura con una línea vertical"]}];
const COUNT_QUIZ = [
    {name: "what", prompt: "¿Qué tienes que contar en cada periodo?",
     options: ["Las figuras diferentes cuya línea tiene la orientación indicada al principio del periodo",
               "Todas las figuras con una línea vertical", "Las figuras de un color diferente al resto"]},
    {name: "verify", prompt: "¿Qué tecla debes pulsar si el número que aparece al final del periodo coincide con tu cuenta?",
     options: ["S", "N", "La flecha hacia arriba"]},
    {name: "reset", prompt: "¿Cuándo vuelves a empezar a contar desde cero?",
     options: ["Al empezar cada periodo", "Al empezar cada bloque", "Nunca: la cuenta sigue durante todo el experimento"]}];

// ---- Reminders (as in VMAC_selective) ----
const REMINDER_KEYS = `<p><b>Si la línea de la figura diferente es vertical, pulsa la flecha hacia arriba.</b></p>
<p><b>Si la línea es horizontal, pulsa la flecha hacia la izquierda.</b></p>`;
const REMINDER_COUNT = `<p>Al principio de cada periodo te indicaremos qué orientación contar. Al final del periodo, pulsa S si el número coincide con tu cuenta o N si no coincide.</p>`;
const REMEMBER = `<p>Recuerda:</p>`;
const REMINDER_PRACTICE = "Estás a punto de empezar la práctica.";
const REMINDER_PERIOD = "Estás a punto de practicar un periodo.";
const REMINDER_EXPERIMENT = "Estás a punto de empezar el experimento.";
const PRACTICE_END = `<p>La fase de prácticas ha llegado a su fin. Recuerda:</p>`;
const STRUCTURE = (n) => `<p>El experimento tiene ${n} bloques. Entre bloques podrás descansar si lo necesitas.</p>`;
const START_PRACTICE = "Pulsa la barra espaciadora para empezar la práctica.";
const START_EXPERIMENT = "Pulsa la barra espaciadora para empezar el experimento.";

// ---- Search trials, counting task and breaks ----
const FEEDBACK = {practice: ":(", experimental: "Error! :("}; // error feedback of the original
const NEW_PERIOD = "Nuevo periodo";
const COUNT_THIS = (word) => `Cuenta las figuras diferentes con línea ${word}.`;
const START_PERIOD = "Pulsa la barra espaciadora para empezar.";
const VERIFY_LABEL = (word) => `Figuras diferentes con línea ${word}:`;
const VERIFY_QUESTION = "¿Coincide con tu cuenta?";
const VERIFY_HINT = "Pulsa S (sí) o N (no).";
const VERIFY_CORRECT = "¡Correcto!";
const VERIFY_INCORRECT = (n, orientation) => `Incorrecto: había ${n} figuras diferentes con línea ${orientation}.`;
const BREAK = (block, n) => `<h2>Descanso</h2><p>Has terminado el bloque ${block} de ${n}.</p><p>En este punto, puedes realizar un pequeño descanso.</p>`;
const LAST_BLOCK = `<p>Ánimo, ¡lo has hecho muy bien! Solo queda la última fase del experimento.</p>
<p>En esta última fase, solo tienes que responder un par de preguntas sencillas.</p>`;
const CONTINUE = `<p class="hint">Pulsa la barra espaciadora para continuar.</p>`;

// ---- Awareness test (AwarenessTest.m, Experiment 1) ----
const AWARENESS_Q1 = `<p>Habrás observado que, en muchos ensayos, aparecía una figura de un color diferente al resto.</p>
<p>¿Te ha parecido que esa figura tendía a aparecer con más frecuencia en algún lugar concreto de la pantalla?</p>
<p>Por favor, teclea el número que corresponde a tu respuesta según la escala mostrada abajo y pulsa Enter.</p>`;
const AWARENESS_SCALE = ["Seguro que no", "Probablemente no", "Creo que no", "Creo que sí", "Probablemente sí", "Seguro que sí"];
const AWARENESS_INTRO = `<p>A continuación, se te pedirá que elijas la localización en la que crees que la figura de diferente color ha aparecido con más frecuencia.</p>
<p>Tu tarea será escribir el número asociado a la localización que has elegido. Estos números se encontrarán dentro del círculo asociado a cada localización.</p>
<p>Podrás ver la localización que has elegido marcada en azul para que puedas identificarla con claridad. Cuando termines, podrás repetir el test si no estás satisfecho con tu respuesta.</p>`;
const AWARENESS_Q2 = `<p>En este punto, si tuvieras que elegir una localización como la que ha albergado más veces la figura que aparecía en diferente color, ¿cuál elegirías?</p>`;
const AWARENESS_Q2_PROMPT = `<p>Por favor, escribe el número de la localización que se corresponde con tu respuesta y pulsa Enter.</p>`;
const AWARENESS_CONFIRM = `<p>Esta es la localización que has elegido.</p>`;
const AWARENESS_CONFIRM_OPTIONS = ["Es correcta: terminar", "Repetir el test"];
const SELECT_HINT = `<p class="hint">Pulsa Enter para confirmar. Para cambiar tu respuesta, pulsa otro número o la tecla de retroceso.</p>`;

// ---- Post-experiment questions (VMAC_selective) ----
const questions = {
    type: jsPsychSurveyHtmlForm,
    preamble: `<h3 style="margin-bottom: 40px">Preguntas post-experimento:</h3>`,
    html: `<div id="form">
    <label class="statement">¿Con qué frecuencia crees que te has distraído durante la tarea (p. ej., por una notificación del móvil o ruido ambiental)?</label>
    <ul class='likert'>
      <li><input type="radio" name="likert" value="1" required><label>Nunca</label></li>
      <li><input type="radio" name="likert" value="2"><label></label></li>
      <li><input type="radio" name="likert" value="3"><label></label></li>
      <li><input type="radio" name="likert" value="4"><label></label></li>
      <li><input type="radio" name="likert" value="5"><label>Con mucha frecuencia</label></li>
    </ul>
    <label class="statement">¿Tienes algún comentario respecto al experimento? Puedes expresar tu opinión debajo:</label>
    <textarea id="text" name="opinion" rows="5" cols="80" style = "display: block" placeholder="Creo que el experimento..."></textarea> </br>
    </div>
    <p style="display: block; margin-bottom: 50px">Una vez que hayas respondido a las preguntas, pulsa <b>continuar</b>.</p>`,
    button_label: "Continuar",
    on_start: () => task_screen(false),
    on_finish: (data) => {
        data.phase = "questions";
        data.distraction_rating = data.response["likert"] || "";
        data.opinion_text = data.response["opinion"] || "";
        data.response = "";
    }
}

const GOODBYE = `<p>El experimento ha llegado a su fin. Gracias por tu participación.</p>`;
const PARTICIPANT_CODE = (id) => `<p>Antes de salir del experimento, apunta tu código de participante: <b>${id}</b></p>`;
const EXIT = "Salir del experimento";
