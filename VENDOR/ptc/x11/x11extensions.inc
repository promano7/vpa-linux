{ ===========================================================================
  MODIFICADO para VPA-Linux (Pablo Romano, 2026): se DESACTIVAN las extensiones
  X11 XF86DGA1/DGA2 para que el binario NO dependa de libXxf86dga (retirada de
  los repos de Arch). VPA siempre usa la consola X11 en ventana, nunca DGA.
  Fichero parte de la run-time library de Free Pascal (LGPL modificada con
  excepcion de enlazado); se conserva su cabecera de copyright original abajo.
  =========================================================================== }
{ X11 extensions we want to enable at compile time }
{$DEFINE ENABLE_X11_EXTENSION_XRANDR}
{$DEFINE ENABLE_X11_EXTENSION_XF86VIDMODE}
{ DGA1 desactivado para VPA-Linux } {.$DEFINE ENABLE_X11_EXTENSION_XF86DGA1}
{ DGA2 desactivado para VPA-Linux } {.$DEFINE ENABLE_X11_EXTENSION_XF86DGA2}
{$DEFINE ENABLE_X11_EXTENSION_XSHM}
{$DEFINE ENABLE_X11_EXTENSION_GLX}
{$DEFINE ENABLE_X11_EXTENSION_XINPUT2}
