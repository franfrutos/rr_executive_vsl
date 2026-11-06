"""
Texts of the task in Spanish (text.js in the jsPsych tasks): those of the
original program, with line breaks left to the layout and typos fixed, and
the drafts of the new screens (counting task, checks, reminders).
"""

CONTINUE = "Pulsa la barra espaciadora para continuar."

INSTRUCTIONS_1 = (
    "Este experimento pretende estudiar tu capacidad para encontrar objetos rápidamente en la pantalla.\n\n"
    "En cada ensayo, te mostraremos ocho figuras (un círculo y siete rombos o viceversa). Tu tarea será encontrar "
    "la figura que es distinta a las demás.\n\n"
    "A lo largo de la tarea verás que los estímulos pueden aparecer en diferentes colores. Estos colores son "
    "irrelevantes para ti. Tu objetivo es buscar la figura que es diferente de las demás, independientemente del color.\n\n"
    "En las siguientes pantallas podrás ver algunos ejemplos en los que la figura diferente estará rodeada con un "
    "círculo azul para que puedas identificarla.")

INSTRUCTIONS_2 = (
    "Cada ensayo comenzará con un punto de fijación en el centro de la pantalla. Intenta mirar fijamente al punto "
    "antes de que aparezcan las figuras. Cuando aparezcan, por favor, busca la figura única tan rápidamente como te "
    "sea posible. Cuando la encuentres, responde con precisión a la orientación de la línea que contiene.\n\n"
    "Si cometes un error, aparecerá un mensaje en la pantalla durante unos segundos. Por favor, evita cometer "
    "errores a lo largo de la tarea ya que harán que su duración sea mayor.\n\n"
    "A continuación, podrás realizar unos cuantos ensayos de práctica.\n\n"
    "El experimento completo lleva aproximadamente cuarenta y cinco minutos.")
# Load group: the response window, added after the first paragraph (draft, to be reviewed)
RESPONSE_WINDOW_TEXT = "En cada ensayo tendrás un máximo de 3 segundos para responder."

# Counting task (load group; drafts, to be reviewed)
COUNT_INSTRUCTIONS = [
    "Además de buscar la figura diferente, tendrás que llevar una cuenta mientras haces la tarea.\n\n"
    "La tarea se dividirá en periodos de unos pocos ensayos. Al principio de cada periodo, te indicaremos una "
    "orientación: vertical u horizontal. Durante ese periodo, responde como siempre a la línea de la figura "
    "diferente y, además, cuenta cuántas veces esa línea tiene la orientación indicada.",
    "Al final de cada periodo aparecerá un número. Pulsa S si ese número coincide con tu cuenta, o N si no "
    "coincide. Después, vuelve a colocar los dedos sobre las flechas.\n\n"
    "Luego empezará un nuevo periodo, y tendrás que empezar a contar desde cero.\n\n"
    "A continuación, podrás practicar con un periodo. Antes, responde a unas breves preguntas para comprobar "
    "que has comprendido la tarea."]
ORIENTATION_WORD = {"vertical": "VERTICAL", "horizontal": "HORIZONTAL"}

# Finger placement (shown with the response keys)
FINGERS = ("Coloca el dedo índice de tu mano derecha sobre la flecha hacia la izquierda y el dedo corazón sobre la "
           "flecha hacia arriba, y mantenlos ahí durante la tarea.")

# Comprehension checks (as in VMAC_selective, Garre-Frutos et al., 2026): if any
# answer is wrong, the instructions are shown again. (question, options, index
# of the correct option); questions and options are shuffled
SEARCH_QUIZ = [
    ("¿Qué tecla debes pulsar si la línea de la figura diferente es vertical?",
     ["La flecha hacia arriba", "La flecha hacia la izquierda", "La barra espaciadora"], 0),
    ("¿Qué figura debes buscar en cada ensayo?",
     ["La figura con una forma diferente a las demás", "La figura con un color diferente a las demás",
      "Cualquier figura con una línea vertical"], 0)]
COUNT_QUIZ = [
    ("¿Qué tienes que contar en cada periodo?",
     ["Las figuras diferentes cuya línea tiene la orientación indicada al principio del periodo",
      "Todas las figuras con una línea vertical", "Las figuras de un color diferente al resto"], 0),
    ("¿Qué tecla debes pulsar si el número que aparece al final del periodo coincide con tu cuenta?",
     ["S", "N", "La flecha hacia arriba"], 0),
    ("¿Cuándo vuelves a empezar a contar desde cero?",
     ["Al empezar cada periodo", "Al empezar cada bloque", "Nunca: la cuenta sigue durante todo el experimento"], 0)]
QUIZ_INTRO = "Antes de continuar, responde a unas breves preguntas para comprobar que has comprendido las instrucciones."
QUIZ_FAILED = ("Alguna de tus respuestas no es correcta.\n\n"
               "Vuelve a leer las instrucciones con atención; después, responderás de nuevo a las preguntas.")

# Reminders before the practice and before the experiment (as in VMAC_selective)
REMINDER_KEYS = ("Si la línea de la figura diferente es vertical, pulsa la flecha hacia arriba.\n\n"
                 "Si la línea es horizontal, pulsa la flecha hacia la izquierda.")
REMINDER_COUNT = ("Al principio de cada periodo te indicaremos qué orientación contar. Al final del periodo, pulsa S "
                  "si el número coincide con tu cuenta o N si no coincide.")

KEYS_TOP = ("Cuando encuentres esa figura diferente, observarás que en su interior hay una línea recta. Tu tarea es "
            "fijarte en la orientación de esa línea recta y dar una de estas dos respuestas.")

AWARENESS_Q1 = (
    "Habrás observado que, en muchos ensayos, aparecía una figura de un color diferente al resto.\n\n"
    "¿Te ha parecido que esa figura tendía a aparecer con más frecuencia en algún lugar concreto de la pantalla?\n\n"
    "Por favor, teclea el número que corresponde a tu respuesta según la escala mostrada abajo y pulsa Enter.")
AWARENESS_SCALE = ["Seguro que no", "Probablemente no", "Creo que no", "Creo que sí", "Probablemente sí", "Seguro que sí"]

AWARENESS_INTRO = (
    "A continuación, se te pedirá que elijas la localización en la que crees que la figura de diferente color ha "
    "aparecido con más frecuencia.\n\n"
    "Tu tarea será escribir el número asociado a la localización que has elegido. Estos números se encontrarán "
    "dentro del círculo asociado a cada localización.\n\n"
    "Podrás ver la localización que has elegido marcada en azul para que puedas identificarla con claridad. "
    "Cuando termines, podrás repetir el test si no estás satisfecho con tu respuesta.")

AWARENESS_Q2 = ("En este punto, si tuvieras que elegir una localización como la que ha albergado más veces la figura "
                "que aparecía en diferente color, ¿cuál elegirías?")
AWARENESS_Q2_PROMPT = "Por favor, escribe el número de la localización que se corresponde con tu respuesta y pulsa Enter."

SELECT_HINT = "Pulsa Enter para confirmar. Para cambiar tu respuesta, pulsa otro número o la tecla de retroceso."


# =============================================================================
# Screens of the session (new screens; drafts, to be reviewed)
# =============================================================================

TITLE_INSTRUCTIONS = "INSTRUCCIONES"
BACK = " o la tecla de retroceso para volver atrás."
EXAMPLE_OF = "Ejemplo {} de {}"
QUESTION_OF = "Pregunta {} de {}"
BACK_TO_INSTRUCTIONS = "Pulsa la barra espaciadora para volver a las instrucciones."

# Error feedback of the original (practice and experimental blocks)
FEEDBACK = {"practice": ":(", "experimental": "Error! :("}

# Response keys (text of Diapositiva5.JPG)
KEYS_IF = {"vertical": "Si la línea es vertical…", "horizontal": "Si la línea es horizontal…"}
KEYS_PRESS = "… pulsa la tecla"
KEYS_WHERE = "que encontrarás en la parte inferior derecha de tu teclado"

# Reminders
REMEMBER = "Recuerda:\n\n"
REMINDER_PRACTICE = "Estás a punto de empezar la práctica."
REMINDER_PERIOD = "Estás a punto de practicar un periodo."
REMINDER_EXPERIMENT = "Estás a punto de empezar el experimento."
PRACTICE_END = "La fase de prácticas ha llegado a su fin. Recuerda:\n\n"
STRUCTURE = "\n\nEl experimento tiene {} bloques. Entre bloques podrás descansar si lo necesitas."
START_PRACTICE = "Pulsa la barra espaciadora para empezar la práctica."
START_EXPERIMENT = "Pulsa la barra espaciadora para empezar el experimento."

# Counting task: start of a period, verification, feedback in the practice
NEW_PERIOD = "Nuevo periodo"
COUNT_THIS = "Cuenta las figuras diferentes con línea {}."
START_PERIOD = "Pulsa la barra espaciadora para empezar."
VERIFY_LABEL = "Figuras diferentes con línea {}:"
VERIFY_QUESTION = "¿Coincide con tu cuenta?"
VERIFY_HINT = "Pulsa S (sí) o N (no)."
VERIFY_CORRECT = "¡Correcto!"
VERIFY_INCORRECT = "Incorrecto: había {} figuras diferentes con línea {}."

# Breaks (original texts)
BREAK_TITLE = "Descanso"
BREAK = "Has terminado el bloque {} de {}.\n\nEn este punto, puedes realizar un pequeño descanso."
LAST_BLOCK = ("Ánimo, ¡lo has hecho muy bien! Solo queda la última fase del experimento.\n\n"
              "En esta última fase, solo tienes que responder un par de preguntas sencillas.")

# Awareness test: confirmation and goodbye
AWARENESS_CONFIRM = "Esta es la localización que has elegido."
AWARENESS_CONFIRM_OPTIONS = ["Es correcta: terminar", "Repetir el test"]
GOODBYE = "El experimento ha llegado a su fin. Gracias por tu participación."
EXIT = "Pulsa la barra espaciadora para salir."

# Start form (participant number and demographics; data keep the codes of the
# original: gender m/h/n, handedness d/i)
DIALOG_TITLE = "Tarea de búsqueda visual"
DIALOG_LABELS = {"participant": "Número de participante", "age": "Edad", "gender": "Género",
                 "handedness": "Mano dominante"}
GENDERS = {"Mujer": "m", "Hombre": "h", "Prefiero no contestar": "n"}
HANDS = {"Derecha": "d", "Izquierda": "i"}
