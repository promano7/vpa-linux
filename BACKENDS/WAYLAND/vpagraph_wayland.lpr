{ vpagraph_wayland - plugin de backend grafico Wayland de VPA-Linux
  (build/plugins/libvpagraph-wayland.so). Fase 8 de WAYLAND.md, tarea T8B.9.

  Es el MISMO adaptador de ABI que el plugin X11 (BACKENDS/X11/
  vpagraph_x11_impl.pas y vpagraph_x11_input.pas), compilado otra vez con
  -dVPAG_WAYLAND y enlazado contra un ptc compilado con -dPTC_SDL3, cuya
  consola es VENDOR/ptc/sdl (ADR-001, via B). Lo unico propio de este
  directorio es vpagraph_wayland_window.pas (D-22). No enlaza libX11.

  cthreads va el PRIMERO por lo mismo que en vpagraph_x11.lpr
  (docs/threads-and-rtl.md).

  Se construye con:  make wayland-plugin
}
library vpagraph_wayland;

{$MODE OBJFPC}{$H+}

uses
  cthreads,
  vpagraph_x11_impl;

exports
  VPAGraph_GetInterface name VPAGRAPH_ENTRY_POINT;

end.
