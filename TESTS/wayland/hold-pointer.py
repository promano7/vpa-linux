#!/usr/bin/env python3
"""hold-pointer.py - mantiene vivo un puntero virtual en el compositor.

Lo usa TESTS/capture.sh con VPA_CAPTURE=wayland (T8B.10). Un sway sin pantalla
(WLR_BACKENDS=headless, WLR_LIBINPUT_NO_DEVICES=1) no tiene ningun dispositivo
de entrada, asi que su wl_seat NO anuncia la capacidad de puntero y los
clientes no tienen wl_pointer: 'swaymsg seat seat0 cursor set X Y' mueve el
cursor del compositor pero nadie recibe enter ni motion. wlrctl no sirve para
esto: crea el puntero virtual, manda el movimiento y lo destruye en la misma
invocacion, antes de que el cliente haya tenido tiempo de enlazar wl_pointer
(medido con SDL_EVENT_LOGGING=2: MOUSE_ADDED, MOUSE_REMOVED y ni un
MOUSE_MOTION).

Este guion crea un zwlr_virtual_pointer_v1 y se queda dormido con la conexion
abierta hasta que lo matan; mientras viva, el seat tiene puntero. Habla el
protocolo de cable de Wayland a mano (son cuatro mensajes) para no depender de
pywayland ni de wayland-scanner. Escribe 'ready' en stdout cuando el puntero
existe.
"""
import os, socket, struct, sys, time

def msg(obj, opcode, payload=b""):
    return struct.pack("<IHH", obj, opcode, 8 + len(payload)) + payload

def wl_string(s):
    b = s.encode() + b"\0"
    return struct.pack("<I", len(b)) + b + b"\0" * (-len(b) % 4)

def main():
    path = os.path.join(os.environ["XDG_RUNTIME_DIR"],
                        os.environ.get("WAYLAND_DISPLAY", "wayland-0"))
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(path)
    # wl_display(1).get_registry(new_id 2) y wl_display.sync(new_id 3)
    sock.sendall(msg(1, 1, struct.pack("<I", 2)) + msg(1, 0, struct.pack("<I", 3)))
    IFACE = "zwlr_virtual_pointer_manager_v1"
    name = None
    buf = b""
    done = False
    while not done:
        data = sock.recv(65536)
        if not data:
            sys.exit("hold-pointer: el compositor ha cerrado la conexion")
        buf += data
        while len(buf) >= 8:
            obj, opcode, size = struct.unpack_from("<IHH", buf)
            if len(buf) < size:
                break
            body, buf = buf[8:size], buf[size:]
            if obj == 2 and opcode == 0:            # wl_registry.global
                gname, slen = struct.unpack_from("<II", body)
                if body[8:8 + slen - 1].decode() == IFACE:
                    name = gname
            elif obj == 3 and opcode == 0:          # wl_callback.done
                done = True
    if name is None:
        sys.exit("hold-pointer: el compositor no anuncia " + IFACE)
    # wl_registry(2).bind(name, iface, version 1, new_id 4)
    sock.sendall(msg(2, 0, struct.pack("<I", name) + wl_string(IFACE) +
                     struct.pack("<II", 1, 4)))
    # manager(4).create_virtual_pointer(seat = null, new_id 5)
    sock.sendall(msg(4, 0, struct.pack("<II", 0, 5)))
    print("ready", flush=True)
    while True:
        time.sleep(3600)

if __name__ == "__main__":
    main()
