import Foundation

/// Rotating quip pool (DE/EN/ES). Iron rule: humor about the situation,
/// never about the user. No guilt-tripping, no shame vocabulary (RSD-safe).
@MainActor
final class PersonalityEngine {

    enum Context: Hashable {
        case preWarn, final, missed, snoozeReturn, confirm
    }

    private var decks: [String: [String]] = [:]

    func message(for context: Context, intensity: Intensity, minutes: Int = 0) -> String {
        let pool = Self.pool(for: context, intensity: intensity, lang: L.code)
        let key = "\(L.code)-\(context)-\(intensity.rawValue)"
        if decks[key, default: []].isEmpty {
            decks[key] = pool.shuffled()
        }
        let raw = decks[key]!.removeFirst()
        return raw.replacingOccurrences(of: "{m}", with: "\(minutes)")
    }

    // MARK: - Pools

    private static func pool(for context: Context, intensity: Intensity, lang: String) -> [String] {
        switch lang {
        case "de": return poolDE(context, intensity)
        case "es": return poolES(context, intensity)
        default: return poolEN(context, intensity)
        }
    }

    // ─────────────────────────── GERMAN ───────────────────────────
    private static func poolDE(_ context: Context, _ intensity: Intensity) -> [String] {
        switch (context, intensity) {
        case (.final, .sachlich):
            return [
                "Dein Termin beginnt gleich.",
                "Zeit für deinen nächsten Termin.",
                "Gleich geht es los.",
                "Dieser Termin beginnt in Kürze.",
            ]
        case (.final, .freundlich):
            return [
                "Dein Termin ruft. Er klingt ein bisschen einsam.",
                "Zeit, den Hyperfokus auf Pause zu stellen. Er wartet auf dich.",
                "Kleiner Ortswechsel gefällig? Dein Kalender hätte da was.",
                "Speichern, aufstehen, glänzen. In genau dieser Reihenfolge.",
                "Dein zukünftiges Ich sagt schon mal Danke fürs Pünktlichsein.",
                "Die Kaffeemaschine liegt auf dem Weg. Nur so als Info. ☕",
                "Alles kann warten. Außer das hier. Das kann nicht warten.",
                "Der Kalender hat gesprochen. Wir sind nur der Bote.",
                "Gleich geht's los — und du bist der Hauptact.",
                "Ein Termin, frisch aus dem Ofen. Wird heiß serviert.",
            ]
        case (.final, .frech):
            return [
                "Ja, GENAU JETZT. Deshalb der ganze Bildschirm.",
                "Dein Meeting fängt gleich an. Dein Platz dort ist noch leer. Verdächtig leer.",
                "Wir unterbrechen dein Programm für eine wichtige Durchsage: LOS.",
                "Der Hyperfokus war schön. Jetzt kommt der Teil mit dem Aufstehen.",
                "Spoiler: Das Meeting findet statt. Mit oder ohne dich. Besser mit.",
                "Noch eine Minute. Das reicht für exakt null weitere ‚nur noch kurz'.",
                "Dieser Bildschirm gehört jetzt deinem Termin. Widerstand ist zwecklos.",
                "Beweg dich, Legende. Der Kalender wartet nicht.",
                "Tabs kannst du später horten. Termin ist jetzt.",
                "Wenn du das liest, ist es Zeit. Es ist immer Zeit, wenn du das liest.",
            ]
        case (.preWarn, .sachlich):
            return [
                "In {m} Minuten beginnt dein nächster Termin.",
                "Noch {m} Minuten bis zum Termin.",
            ]
        case (.preWarn, .freundlich):
            return [
                "In {m} Minuten geht's los — guter Moment zum Speichern.",
                "Sanfte Vorwarnung: {m} Minuten bis zum Termin.",
                "Noch {m} Minuten Hyperfokus, dann Ortswechsel.",
                "Kurzer Realitätscheck: In {m} Minuten bist du gebucht.",
                "In {m} Minuten will der Kalender dich sehen. Nur dass du's weißt.",
                "Landeanflug: {m} Minuten bis zum Termin.",
            ]
        case (.preWarn, .frech):
            return [
                "In {m} Minuten reißen wir dich hier raus. Das ist die nette Vorwarnung.",
                "{m} Minuten. Genug für Wasser, Klo, ein letztes Häppchen Arbeit. Wähle weise.",
                "Countdown läuft: {m} Minuten. Wir sagen's dann nochmal. Deutlich größer.",
                "Nur ein Drive-by: {m} Minuten noch. Mach was draus.",
                "In {m} Minuten wird dieser Bildschirm sehr, sehr voll. Du wurdest gewarnt.",
            ]
        case (.missed, .sachlich):
            return ["Der Termin hat bereits begonnen."]
        case (.missed, .freundlich):
            return [
                "Läuft schon — und ein guter Auftritt braucht vor allem eins: einen Auftritt.",
                "Das Meeting hat ohne dich angefangen. Es wird gerade erst gut. Rein da!",
                "Noch ist nichts verloren. Tür auf, Lächeln an, reinhuschen.",
                "Der beste Zeitpunkt war vor ein paar Minuten. Der zweitbeste ist jetzt.",
                "Fashionably late ist auch ein Stil. Jetzt aber los.",
            ]
        case (.missed, .frech):
            return [
                "Es läuft. Ohne dich. Das können wir ändern — JETZT.",
                "Plot-Twist: Du bist der Cliffhanger. Auflösung: Du gehst jetzt rein.",
                "Die anderen sind schon da. Jemand hat bestimmt deinen Namen gesagt.",
                "Drin in 30 Sekunden und niemand stellt Fragen. Deal?",
            ]
        case (.snoozeReturn, .sachlich):
            return ["Deine Snooze-Zeit ist abgelaufen."]
        case (.snoozeReturn, .freundlich):
            return [
                "Hallo wieder! Die Pause ist rum. Versprochen ist versprochen.",
                "Wir wieder. Der Termin übrigens auch noch. Jetzt aber, oder?",
                "Zurück wie angekündigt. Diesmal mit etwas mehr Nachdruck. 💚",
                "Snooze abgelaufen. Der Kalender guckt schon ganz erwartungsvoll.",
            ]
        case (.snoozeReturn, .frech):
            return [
                "Rate mal, wer wieder da ist. Genau. Und wir haben den Termin mitgebracht.",
                "Die ‚noch 2 Minuten' sind vorbei. Das hier ist die Rechnung.",
                "Wir haben's geahnt. Deshalb sind wir wieder da. LOS jetzt.",
                "Snooze war gestern. Beziehungsweise vor 2 Minuten. Auf geht's.",
            ]
        case (.confirm, _):
            return [
                "Sauber! Viel Erfolg. 🚀",
                "Pünktlich wie ein Uhrwerk. Respekt.",
                "Und los! Dein zukünftiges Ich feiert dich.",
                "Zack, unterwegs. Stark.",
                "Der Kalender ist stolz auf dich. Wir auch.",
                "On time, on point. 💚",
                "Nice. Wir passen solange auf den Rest auf.",
                "Läuft bei dir. Bis zum nächsten Termin!",
            ]
        }
    }

    // ─────────────────────────── ENGLISH ───────────────────────────
    private static func poolEN(_ context: Context, _ intensity: Intensity) -> [String] {
        switch (context, intensity) {
        case (.final, .sachlich):
            return [
                "Your event is about to start.",
                "Time for your next event.",
                "Starting shortly.",
            ]
        case (.final, .freundlich):
            return [
                "Your meeting is calling. It sounds a little lonely.",
                "Time to pause the hyperfocus — it'll keep, promise.",
                "Save, stand up, shine. In exactly that order.",
                "Future you says thanks in advance for being on time.",
                "The coffee machine is on the way. Just saying. ☕",
                "Everything can wait. Except this. This one can't.",
                "The calendar has spoken. We're just the messenger.",
                "Showtime in a minute — and you're the headliner.",
            ]
        case (.final, .frech):
            return [
                "Yes, RIGHT NOW. That's why we took the whole screen.",
                "Your meeting starts soon. Your seat is still empty. Suspiciously empty.",
                "We interrupt this hyperfocus for an important announcement: GO.",
                "Spoiler: the meeting happens. With or without you. Better with.",
                "One minute left. That's exactly zero more 'just one more things'.",
                "This screen belongs to your calendar now. Resistance is futile.",
                "Move it, legend. Calendars don't wait.",
                "You can hoard tabs later. Meeting is now.",
            ]
        case (.preWarn, .sachlich):
            return ["Your next event starts in {m} minutes."]
        case (.preWarn, .freundlich):
            return [
                "{m} minutes to go — great moment to hit save.",
                "Gentle heads-up: {m} minutes until your event.",
                "{m} more minutes of hyperfocus, then scene change.",
                "Reality check: you're booked in {m} minutes.",
                "Final approach: {m} minutes to landing.",
            ]
        case (.preWarn, .frech):
            return [
                "In {m} minutes we're pulling you out of here. This is the polite version.",
                "{m} minutes. Enough for water, bathroom, one last bite of work. Choose wisely.",
                "Countdown running: {m} minutes. Next time we'll say it much bigger.",
                "In {m} minutes this screen gets very, very full. You've been warned.",
            ]
        case (.missed, .sachlich):
            return ["The event has already started."]
        case (.missed, .freundlich):
            return [
                "It's already running — and a great entrance needs one thing: an entrance.",
                "The meeting started without you. It's just getting good. Slip in!",
                "Nothing's lost yet. Door open, smile on, glide in.",
                "The best moment was a few minutes ago. The second best is now.",
            ]
        case (.missed, .frech):
            return [
                "It's happening. Without you. We can fix that — NOW.",
                "Plot twist: you're the cliffhanger. Resolution: you walk in now.",
                "Everyone's there. Someone has definitely said your name already.",
                "In within 30 seconds and nobody asks questions. Deal?",
            ]
        case (.snoozeReturn, .sachlich):
            return ["Your snooze has ended."]
        case (.snoozeReturn, .freundlich):
            return [
                "Hello again! Break's over. A promise is a promise.",
                "It's us again. The meeting is also still a thing. Now, though — right?",
                "Back as announced. This time with a bit more emphasis. 💚",
            ]
        case (.snoozeReturn, .frech):
            return [
                "Guess who's back. Exactly. And we brought the meeting.",
                "The 'two more minutes' are up. This is the invoice.",
                "We had a feeling. That's why we're back. GO time.",
            ]
        case (.confirm, _):
            return [
                "Nailed it! Go get 'em. 🚀",
                "Punctual as clockwork. Respect.",
                "And off you go! Future you is cheering.",
                "The calendar is proud of you. So are we.",
                "On time, on point. 💚",
                "Nice. We'll keep an eye on the rest meanwhile.",
            ]
        }
    }

    // ─────────────────────────── SPANISH ───────────────────────────
    private static func poolES(_ context: Context, _ intensity: Intensity) -> [String] {
        switch (context, intensity) {
        case (.final, .sachlich):
            return [
                "Tu evento está a punto de empezar.",
                "Es hora de tu próximo evento.",
                "Empieza en breve.",
            ]
        case (.final, .freundlich):
            return [
                "Tu reunión te llama. Suena un poquito sola.",
                "Hora de pausar el hiperfoco — te esperará, prometido.",
                "Guardar, levantarse, brillar. Exactamente en ese orden.",
                "Tu yo del futuro ya te da las gracias por llegar a tiempo.",
                "La cafetera está de camino. Solo lo comento. ☕",
                "Todo puede esperar. Menos esto. Esto no.",
                "El calendario ha hablado. Nosotros solo somos el mensajero.",
                "En un minuto empieza el show — y tú eres la estrella.",
            ]
        case (.final, .frech):
            return [
                "Sí, AHORA MISMO. Por eso ocupamos toda la pantalla.",
                "Tu reunión empieza ya. Tu sitio sigue vacío. Sospechosamente vacío.",
                "Interrumpimos este hiperfoco para un anuncio importante: VAMOS.",
                "Spoiler: la reunión ocurre. Contigo o sin ti. Mejor contigo.",
                "Queda un minuto. Da para exactamente cero 'solo un momentito' más.",
                "Esta pantalla ahora es de tu calendario. Resistirse es inútil.",
                "Muévete, leyenda. Los calendarios no esperan.",
            ]
        case (.preWarn, .sachlich):
            return ["Tu próximo evento empieza en {m} minutos."]
        case (.preWarn, .freundlich):
            return [
                "Quedan {m} minutos — buen momento para guardar.",
                "Aviso suave: {m} minutos para tu evento.",
                "{m} minutos más de hiperfoco y cambio de escena.",
                "Chequeo de realidad: en {m} minutos estás ocupado.",
                "Aproximación final: {m} minutos para aterrizar.",
            ]
        case (.preWarn, .frech):
            return [
                "En {m} minutos te sacamos de aquí. Esta es la versión amable.",
                "{m} minutos. Da para agua, baño y un último mordisco de trabajo. Elige bien.",
                "Cuenta atrás: {m} minutos. La próxima vez lo diremos mucho más grande.",
                "En {m} minutos esta pantalla se llenará mucho. Quedas avisado.",
            ]
        case (.missed, .sachlich):
            return ["El evento ya ha empezado."]
        case (.missed, .freundlich):
            return [
                "Ya está en marcha — y una gran entrada necesita una cosa: una entrada.",
                "La reunión empezó sin ti. Justo se pone interesante. ¡Entra!",
                "Aún no se ha perdido nada. Puerta, sonrisa, adentro.",
                "El mejor momento fue hace unos minutos. El segundo mejor es ahora.",
            ]
        case (.missed, .frech):
            return [
                "Está pasando. Sin ti. Podemos arreglarlo — YA.",
                "Giro de guion: tú eres el cliffhanger. Resolución: entras ahora.",
                "Ya están todos. Seguro que alguien ya ha dicho tu nombre.",
            ]
        case (.snoozeReturn, .sachlich):
            return ["Tu pausa ha terminado."]
        case (.snoozeReturn, .freundlich):
            return [
                "¡Hola otra vez! Se acabó la pausa. Lo prometido es deuda.",
                "Somos nosotros de nuevo. La reunión también sigue ahí. ¿Ahora sí?",
                "De vuelta, como anunciamos. Esta vez con más énfasis. 💚",
            ]
        case (.snoozeReturn, .frech):
            return [
                "Adivina quién ha vuelto. Exacto. Y trajimos la reunión.",
                "Los 'dos minutos más' se acabaron. Esta es la factura.",
                "Lo veíamos venir. Por eso volvimos. VAMOS ya.",
            ]
        case (.confirm, _):
            return [
                "¡Perfecto! A por ello. 🚀",
                "Puntual como un reloj. Respeto.",
                "¡Y en marcha! Tu yo del futuro te aplaude.",
                "El calendario está orgulloso de ti. Nosotros también.",
                "A tiempo y con estilo. 💚",
                "Genial. Nosotros vigilamos el resto mientras tanto.",
            ]
        }
    }
}
