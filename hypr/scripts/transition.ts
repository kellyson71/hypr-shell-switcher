// Overlay de transição entre shells Quickshell (ags v3 / Astal GTK4).
// Congela o frame na camada overlay (acima de tudo), faz o crossfade da logo
// do shell antigo para o novo num canto e some com fade-out ao receber "reveal".
import app from "ags/gtk4/app"
import { Astal, Gtk } from "ags/gtk4"
import GLib from "gi://GLib"

const env = (k: string, d = "") => GLib.getenv(k) ?? d
const FREEZE = env("ST_FREEZE")
const FROM = env("ST_FROM")
const TO = env("ST_TO")
const LABEL = env("ST_LABEL")
const MAX_MS = parseInt(env("ST_TIMEOUT", "8000"), 10)
const SIGNAL = env("ST_SIGNAL", "/tmp/shell-transition.signal")

const exists = (p: string) => !!p && GLib.file_test(p, GLib.FileTest.EXISTS)
const windows: any[] = []
let revealing = false

function fadeOut() {
  if (revealing) return
  revealing = true
  const dur = 380
  for (const w of windows) {
    const start = GLib.get_monotonic_time()
    w.add_tick_callback((_w: any) => {
      const t = Math.min(1, (GLib.get_monotonic_time() - start) / (dur * 1000))
      _w.set_opacity(1 - (1 - Math.pow(1 - t, 3)))
      return t < 1 ? GLib.SOURCE_CONTINUE : GLib.SOURCE_REMOVE
    })
  }
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, dur + 40, () => {
    app.quit()
    return GLib.SOURCE_REMOVE
  })
}

function pic(file: string) {
  const p = new Gtk.Picture({ contentFit: Gtk.ContentFit.CONTAIN })
  p.set_size_request(84, 84)
  if (exists(file)) p.set_filename(file)
  return p
}

function makeCard() {
  const stack = new Gtk.Stack({
    transitionType: Gtk.StackTransitionType.CROSSFADE,
    transitionDuration: 480,
    halign: Gtk.Align.CENTER,
    valign: Gtk.Align.CENTER,
  })
  stack.add_named(pic(FROM), "from")
  stack.add_named(pic(TO), "to")
  stack.set_visible_child_name("from")

  // puck circular claro atrás da logo: dá contraste pras partes escuras de
  // ambos os logos sem brigar com o card escuro (que segura o label branco)
  const puck = new Gtk.Box({ halign: Gtk.Align.CENTER, valign: Gtk.Align.CENTER })
  puck.add_css_class("puck")
  puck.set_size_request(112, 112)
  puck.append(stack)

  const card = new Gtk.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 12,
    halign: Gtk.Align.END,
    valign: Gtk.Align.END,
  })
  card.add_css_class("card")
  card.append(puck)
  if (LABEL) {
    const lbl = new Gtk.Label({ label: LABEL })
    lbl.add_css_class("label")
    card.append(lbl)
  }

  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 360, () => {
    stack.set_visible_child_name("to")
    return GLib.SOURCE_REMOVE
  })
  return card
}

app.start({
  instanceName: "shelltransition",
  css: `
    window { background-color: transparent; }
    .card {
      margin: 28px;
      padding: 20px 22px;
      border-radius: 28px;
      background-color: rgba(20, 20, 24, 0.82);
      border: 1px solid rgba(255, 255, 255, 0.10);
    }
    .puck {
      border-radius: 56px;
      background-color: #f4f5f7;
      border: 1px solid rgba(255, 255, 255, 0.6);
    }
    .label {
      color: rgba(255, 255, 255, 0.92);
      font-size: 14px;
      font-weight: 600;
    }
  `,
  main() {
    // gatilho de reveal: o switch-shell.sh cria o arquivo-sentinela ao ficar pronto
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
      if (exists(SIGNAL)) {
        try { GLib.unlink(SIGNAL) } catch (_) {}
        fadeOut()
        return GLib.SOURCE_REMOVE
      }
      return revealing ? GLib.SOURCE_REMOVE : GLib.SOURCE_CONTINUE
    })

    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
    for (const mon of app.get_monitors()) {
      const win = new Astal.Window({
        gdkmonitor: mon,
        layer: Astal.Layer.OVERLAY,
        exclusivity: Astal.Exclusivity.IGNORE,
        keymode: Astal.Keymode.NONE,
        anchor: TOP | BOTTOM | LEFT | RIGHT,
        namespace: "shell-transition",
        application: app,
      })

      const overlay = new Gtk.Overlay()
      const bg = new Gtk.Picture({ contentFit: Gtk.ContentFit.COVER })
      if (exists(FREEZE)) bg.set_filename(FREEZE)
      overlay.set_child(bg)
      overlay.add_overlay(makeCard())

      win.set_child(overlay)
      win.set_visible(true)
      windows.push(win)
    }

    GLib.timeout_add(GLib.PRIORITY_DEFAULT, MAX_MS, () => {
      fadeOut()
      return GLib.SOURCE_REMOVE
    })
  },
})
