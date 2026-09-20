#!/usr/bin/env python3
"""vkbd.py - teclado virtual con una distribucion xkb DE VERDAD.

Lo usa TESTS/wayland/input_test.lpr (Fase 9, T9.2). wtype no sirve para
probar distribuciones: cada invocacion sube un keymap inventado, de un solo
nivel, con una tecla por keysym pedido, asi que nunca ejercita el segundo
nivel (Shift-= en 'us'), AltGr, ni una distribucion sin letras latinas
('ru'). Este guion crea un zwp_virtual_keyboard_v1, le sube el keymap de la
distribucion pedida (el mismo texto que compilaria el compositor:
pc+LAYOUT+inet(evdev)) y manda teclas FISICAS, por codigo evdev, con su
mascara de modificadores, que es lo que hace un teclado real.

Habla el protocolo de cable de Wayland a mano, como hold-pointer.py, para no
depender de pywayland ni de wayland-scanner.

Uso:  vkbd.py LAYOUT COMBO [COMBO...]
      COMBO = [mod+...]TECLA      mod: shift ctrl alt altgr caps num
              TECLA: nombre evdev sin 'KEY_' (A, EQUAL, RIGHTBRACE, KP1...)
                     o el numero evdev
      ej.:  vkbd.py es ctrl+RIGHTBRACE        (Ctrl-+ en un teclado espanol)
            vkbd.py us ctrl+shift+EQUAL       (Ctrl-+ en uno estadounidense)
"""
import array, os, socket, struct, sys, time

KEYS = {
    "ESC": 1, "1": 2, "2": 3, "3": 4, "4": 5, "5": 6, "6": 7, "7": 8, "8": 9,
    "9": 10, "0": 11, "MINUS": 12, "EQUAL": 13, "BACKSPACE": 14, "TAB": 15,
    "Q": 16, "W": 17, "E": 18, "R": 19, "T": 20, "Y": 21, "U": 22, "I": 23,
    "O": 24, "P": 25, "LEFTBRACE": 26, "RIGHTBRACE": 27, "ENTER": 28,
    "A": 30, "S": 31, "D": 32, "F": 33, "G": 34, "H": 35, "J": 36, "K": 37,
    "L": 38, "SEMICOLON": 39, "APOSTROPHE": 40, "GRAVE": 41, "BACKSLASH": 43,
    "Z": 44, "X": 45, "C": 46, "V": 47, "B": 48, "N": 49, "M": 50,
    "COMMA": 51, "DOT": 52, "SLASH": 53, "KPASTERISK": 55, "SPACE": 57,
    "KP7": 71, "KP8": 72, "KP9": 73, "KPMINUS": 74, "KP4": 75, "KP5": 76,
    "KP6": 77, "KPPLUS": 78, "KP1": 79, "KP2": 80, "KP3": 81, "KP0": 82,
    "KPDOT": 83, "KPENTER": 96, "KPSLASH": 98,
}
# mascaras de los modificadores reales de xkb en el keymap 'evdev':
# Shift, Lock, Control, Mod1 (Alt), Mod2 (NumLock), Mod5 (AltGr, nivel 3)
DEPRESSED = {"shift": 1, "ctrl": 4, "alt": 8, "altgr": 0x80}
LOCKED = {"caps": 2, "num": 0x10}

def msg(obj, opcode, payload=b""):
    return struct.pack("<IHH", obj, opcode, 8 + len(payload)) + payload

def wl_string(s):
    b = s.encode() + b"\0"
    return struct.pack("<I", len(b)) + b + b"\0" * (-len(b) % 4)

def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    layout, combos = sys.argv[1], sys.argv[2:]
    keymap = ('xkb_keymap {\n'
              ' xkb_keycodes { include "evdev+aliases(qwerty)" };\n'
              ' xkb_types { include "complete" };\n'
              ' xkb_compat { include "complete" };\n'
              ' xkb_symbols { include "pc+%s+inet(evdev)" };\n'
              '};\n' % layout).encode() + b"\0"

    path = os.path.join(os.environ["XDG_RUNTIME_DIR"],
                        os.environ.get("WAYLAND_DISPLAY", "wayland-0"))
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(path)
    # wl_display(1).get_registry(new_id 2) y wl_display.sync(new_id 3)
    sock.sendall(msg(1, 1, struct.pack("<I", 2)) + msg(1, 0, struct.pack("<I", 3)))
    MGR, SEAT = "zwp_virtual_keyboard_manager_v1", "wl_seat"
    names = {}
    buf = b""
    done = False
    while not done:
        data = sock.recv(65536)
        if not data:
            sys.exit("vkbd: el compositor ha cerrado la conexion")
        buf += data
        while len(buf) >= 8:
            obj, opcode, size = struct.unpack_from("<IHH", buf)
            if len(buf) < size:
                break
            body, buf = buf[8:size], buf[size:]
            if obj == 2 and opcode == 0:            # wl_registry.global
                gname, slen = struct.unpack_from("<II", body)
                names.setdefault(body[8:8 + slen - 1].decode(), gname)
            elif obj == 3 and opcode == 0:          # wl_callback.done
                done = True
    for iface in (MGR, SEAT):
        if iface not in names:
            sys.exit("vkbd: el compositor no anuncia " + iface)
    # wl_registry(2).bind: seat -> 4, manager -> 5
    sock.sendall(msg(2, 0, struct.pack("<I", names[SEAT]) + wl_string(SEAT) +
                     struct.pack("<II", 1, 4)))
    sock.sendall(msg(2, 0, struct.pack("<I", names[MGR]) + wl_string(MGR) +
                     struct.pack("<II", 1, 5)))
    # manager(5).create_virtual_keyboard(seat 4, new_id 6)
    sock.sendall(msg(5, 0, struct.pack("<II", 4, 6)))
    # keyboard(6).keymap(format 1 = xkb_v1, fd, size): el fd va por SCM_RIGHTS
    fd = os.memfd_create("vkbd-keymap")
    os.write(fd, keymap)
    sock.sendmsg([msg(6, 0, struct.pack("<II", 1, len(keymap)))],
                 [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", [fd]))])
    os.close(fd)
    time.sleep(0.4)     # que el cliente reciba el keymap y el foco (enter)

    def modifiers(depressed, locked):
        sock.sendall(msg(6, 2, struct.pack("<IIII", depressed, 0, locked, 0)))

    t = 1000
    for combo in combos:
        parts = combo.split("+")
        key = parts[-1].upper()
        code = KEYS[key] if key in KEYS else int(key)
        dep = lck = 0
        for m in parts[:-1]:
            m = m.lower()
            if m in DEPRESSED: dep |= DEPRESSED[m]
            elif m in LOCKED: lck |= LOCKED[m]
            else: sys.exit("vkbd: modificador desconocido: " + m)
        modifiers(dep, lck)
        time.sleep(0.05)
        sock.sendall(msg(6, 1, struct.pack("<III", t, code, 1)))
        time.sleep(0.05)
        sock.sendall(msg(6, 1, struct.pack("<III", t + 50, code, 0)))
        time.sleep(0.05)
        modifiers(0, 0)
        time.sleep(0.15)
        t += 300
    sock.sendall(msg(6, 3))     # destroy
    time.sleep(0.1)

if __name__ == "__main__":
    main()
