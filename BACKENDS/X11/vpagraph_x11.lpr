{ vpagraph_x11 - plugin de backend grafico X11 de VPA-Linux
  (build/plugins/libvpagraph-x11.so). Fase 5 de WAYLAND.md, tarea T5.3.

  Envuelve el ptcgraph vendorizado (VENDOR/) detras de la ABI v1 de
  GRAPH/vpagraph_abi.inc. No aporta funcionalidad: dibuja exactamente lo que
  dibuja el ptcgraph enlazado hoy en el ejecutable, y el arnes de T5.11 lo
  comprueba pixel a pixel.

  Exporta UN solo simbolo, VPAGraph_GetInterface (T2.13). Todo lo demas vive
  en las unidades vpagraph_x11_*.pas.

  cthreads va el PRIMERO del uses: ptc levanta un hilo para su bucle de
  eventos X11 (TPTCWrapperThread) y el gestor de hilos de ESTE RTL -el de la
  biblioteca, distinto del RTL del ejecutable- tiene que estar instalado
  antes de que se inicialice cualquier otra unidad. Lo que eso implica esta
  medido y escrito en docs/threads-and-rtl.md (T5.9).

  Se construye con:  make x11-plugin   (fpc @plugins.cfg ...)
}
library vpagraph_x11;

{$MODE OBJFPC}{$H+}

uses
  cthreads,
  vpagraph_x11_impl;

exports
  VPAGraph_GetInterface name VPAGRAPH_ENTRY_POINT;

end.
