# Changelog

Neuigkeiten in jeder Version von Glide für Mac. Glide zeigt die neuen Einträge einmal nach einem Update an, und die Hinweise zu jedem Release auf GitHub stammen von hier. Dies ist eine Übersetzung von CHANGELOG.md, das Original ist die englische Datei.

## 0.10.2 — 2026-10-19

### Neu

- **Gekachelt: ⌃⌥↑ und ⌃⌥↓ wechseln zuerst die Tabs.** In einer Tab-Gruppe wechseln sie erst die Tabs, bevor sie zur Kachel in dieser Richtung weitergehen.

### Fehlerbehebungen

- **Gekachelt: Nachbarn schrumpfen auf die Mindestbreite einer App.** Hat eine App eine Mindestbreite, werden die Kacheln daneben verkleinert, statt sich zu überlappen, und Glide sagt, warum eine Größenänderung bei dieser Breite stoppt.

## 0.10.1 — 2026-10-19

### Fehlerbehebungen

- **Tab-Gruppen funktionieren im gekachelten Layout.** ⌃⌥[ und ⌃⌥] fügen ein Fenster einer Tab-Gruppe (einer Spalte mit Tabs) hinzu, und ein Tab kann in eine eigene Kachel verschoben werden, wie es beim Scrollen schon ging.

## 0.10.0 — 2026-10-19

### Neu

- **Gekachelt ist jetzt eine spiralförmige Anordnung.** Mit ⌃⌥T schaltest du einen Arbeitsbereich auf eine Anordnung um, in der alle Fenster auf den Bildschirm passen: Ein Fenster füllt ihn, zwei teilen ihn sich als Hälften, und ab dem dritten wird die letzte Spalte erneut geteilt, abwechselnd oben und unten mit links und rechts. Sie nutzt 2 Spalten oder 3 mit dem neuen ⌃⌥G, was Glide auch auf Ultrawide-Bildschirmen wählt. Wechselst du zurück zu Scrollend, bleiben deine Fenster in derselben Reihenfolge.
- **Bewege dich in einem gekachelten Arbeitsbereich nach Richtung.** ⌃⌥ + Pfeiltasten fokussieren die Kachel neben der fokussierten, und ⌃⌥⇧ + Pfeiltasten tauschen sie mit diesem Nachbarn. Das Wechseln der Breite (⌃⌥R) ändert, wie die fokussierte Kachel den Platz mit den folgenden Kacheln teilt, und ⌃⌥F zoomt eine Kachel auf den ganzen Bildschirm, bis du es erneut drückst.
- **Wähle, wie viele Spalten gekachelte Arbeitsbereiche nutzen,** unter Einstellungen › Allgemein › Gekachelte Spalten: Automatisch (3 auf Ultrawide-Bildschirmen, sonst 2), 2 oder 3.

### Änderungen

- **Ein Fenster in einen anderen Arbeitsbereich zu schicken, verschiebt nur dieses Fenster.** ⌃⌥⇧1…9 und ⌃⌥⇧PgUp/PgDn nahmen früher die ganze Spalte mit, jetzt geht nur das fokussierte Fenster als eigene Spalte, und du bleibst im aktuellen Arbeitsbereich.

## 0.9.4 — 2026-10-19

### Fehlerbehebungen

- **Keine Lücken mehr nach dem Schließen eines Fensters.** Wenn ein Fenster geschlossen wurde oder verschwand, konnte eine App, die einen Teil einer Verschiebung ignorierte (etwa Proton Mail), an ihrer Stelle bleiben und eine Lücke hinterlassen. Glide prüft jetzt, wo die Fenster tatsächlich landen, und rückt sie zurecht.

## 0.9.3 — 2026-10-19

### Neu

- **Gekachelte Anordnung.** Mit ⌃⌥T schaltest du den aktuellen Arbeitsbereich zwischen dem scrollenden Streifen und einer gekachelten Anordnung um, in der sich alle Spalten den Bildschirm teilen und gemeinsam Platz finden, ohne zu scrollen. Jeder Arbeitsbereich behält seine eigene Anordnung, auch nach einem Neustart von Glide. Wechselst du die Breite einer Spalte (⌃⌥R), bekommt sie einen größeren oder kleineren Anteil, Ziehen an ihrem Rand ändert die Größe, und ⌃⌥F macht sie weiterhin volle Breite, bis du es erneut drückst.
- **Wähle die Anordnung, mit der neue Arbeitsbereiche starten,** unter Einstellungen › Allgemein › Anordnung: Scrollend wie bisher oder Gekachelt. Arbeitsbereiche, die du mit ⌃⌥T umgeschaltet hast, behalten ihre eigene.

## 0.9.2 — 2026-10-16

### Neu

- **Auch Neuigkeiten sprechen deine Sprache.** Die Hinweise, die Glide nach einem Update und unter „Neuigkeiten“ zeigt, erscheinen jetzt in derselben Sprache wie der Rest von Glide.

## 0.9.1 — 2026-10-16

### Neu

- **Glide spricht deine Sprache.** Glide gibt es jetzt außer auf Englisch und Spanisch auch auf Französisch, Deutsch, Japanisch, Chinesisch (vereinfacht), Koreanisch und Portugiesisch (Brasilien) und richtet sich nach der bevorzugten Sprache von macOS.

## 0.9.0 — 2026-10-15

Glide für Mac verwendet jetzt dieselben Versionsnummern wie Glide für Windows.

### Neu

- **Alle Tastenkürzel auf einer Seite.** ⌃⌥/ zeigt sie alle an; drücke es noch einmal, drücke Esc oder klicke außerhalb, um die Ansicht zu schließen. Du findest sie auch im Menü in der Menüleiste, ganz oben unter „Tastenkürzel“.
- **Problem melden** im Menü in der Menüleiste und unter Einstellungen › Allgemein. Glide packt sein aktuelles Protokoll und seine Einstellungen ohne Fenstertitel in eine ZIP-Datei, zeigt sie im Finder an und öffnet auf GitHub ein neues Issue, in dem du beschreibst, was passiert ist, und die ZIP-Datei anhängst. Von selbst wird nichts gesendet.
- **Glide spricht Spanisch.** Ist macOS auf Spanisch eingestellt, ist es Glide auch. „Neuigkeiten“ bleibt auf Englisch.

### Fehlerbehebungen

- **Vollbild bleibt Vollbild.** Ein Fenster im Vollbildmodus oder ein Video oder Spiel, das den Bildschirm ausfüllt, wird nicht mehr in seine Spalte zurückgeholt. Glide lässt es in Ruhe, blendet Fokusrahmen, Abdunkeln und Tableiste darüber aus und lässt das horizontale Mausrad und Dreifingergesten auf diesem Bildschirm zu ihm durch. Verlässt es den Vollbildmodus, kehrt es in seine Spalte zurück.

## 0.4.0 — 2026-10-14

### Neu

- **Sieh, wo ein gezogenes Fenster landet.** Beim Ziehen eines Fensters zeigt ein Umriss in der Farbe des Fokusrahmens die Spalte, der es beitreten würde, samt Tableiste. Über einem anderen Bildschirm zeigt ein Balken, wo es zwischen den Spalten dieses Bildschirms eingefügt würde. Ohne Hervorhebung springt es zurück.

## 0.3.0 — 2026-10-14

### Neu

- **Jeder Bildschirm wird gekachelt.** Jeder Bildschirm hat sein eigenes Band und seine eigenen neun Arbeitsbereiche. Tastenkürzel wirken auf den Bildschirm mit dem fokussierten Fenster oder auf den unter dem Zeiger. Mit ⌃⌥⌘←/→ springt der Fokus auf den Bildschirm auf dieser Seite, mit ⌃⌥⌘⇧←/→ schickst du die fokussierte Spalte dorthin. Neue Fenster gehören zu dem Bildschirm, auf dem sie sich öffnen.
- **Zieh ein Fenster dorthin, wo du es haben willst.** Legst du es auf einer Tableiste ab, wird es dort ein Tab; legst du es auf einem anderen Fenster ab, wird es in dessen Spalte gestapelt; legst du es auf einem anderen Bildschirm ab, kommt es in dessen Band. Ein schwebendes Fenster, das du auf einer Kachel ablegst, wird zu den Kacheln hinzugefügt. Überall sonst springt es zurück wie bisher.
- **Das Mausrad bewegt das Band.** Kippe das Rad (oder nutze ein Daumenrad), um dich am Band entlangzubewegen, oder halte beim Scrollen ⌃⌥ gedrückt. Wann das Kippen das tut, legst du unter Einstellungen › Horizontales Mausrad fest: Immer, Mit ⌃⌥ oder Aus.
- **Apps öffnen sich dort, wo du sie haben willst.** Glide merkt sich für jede App Bildschirm, Arbeitsbereich, Spaltenbreite und Position auf dem Band und öffnet ihre neuen Fenster dort. In den Einstellungen kannst du das ausschalten oder alle gemerkten Orte vergessen.
- **Stärke des Fokusrahmens** von 1 bis 12 Punkt, unter Einstellungen › Erscheinungsbild.

## 0.2.1 — 2026-10-14

### Neu

- **Neuigkeiten.** Nach einem Update zeigt Glide, was sich geändert hat. Du findest die Hinweise jederzeit in der Menüleiste unter **Neuigkeiten**.

## 0.2.0 — 2026-10-14

### Neu

- **Glide hält sich selbst aktuell.** Es sucht einmal am Tag nach einer neuen Version und bietet sie an – oder installiert sie für dich, wenn du das unter Einstellungen › Updates einschaltest. Mit **Nach Updates suchen …** im Menü suchst du sofort. Jedes Update ist von Apple signiert und notarisiert.
- **Glide ist Open Source** unter der MIT-Lizenz: [github.com/QuackByte/glide](https://github.com/QuackByte/glide).

## 0.1.1 — 2026-10-13

### Fehlerbehebungen

- Wenn du Chrome, T3 Code oder eine andere Chromium- oder Electron-App beendet und wieder geöffnet hast, blieb der Fokus auf dem vorherigen Fenster, und das neue Fenster lag außerhalb des Bildschirms. Jetzt ist es fokussiert und wird ins Bild gescrollt.

## 0.1.0 — 2026-10-13

Das erste Release von Glide für Mac.

- **Spalten auf einem scrollbaren Band**: Breiten von ⅓, ½, ⅔ und voll, Stapel und Spalten mit Tabs, mit einem Tastenkürzel für alles.
- **Neun Arbeitsbereiche**, eine Übersicht mit Live-Vorschauen, Dreifingergesten, ein Fokusrahmen, App-Regeln und ein Wächter, der deine Fenster zurückholt, falls Glide abstürzt.
