{ vpagraph_installdir.inc - Directorio de instalacion de los plugins de
  backend grafico (candidato 3 de la resolucion de ruta, T3.2).

  Esta en un include aparte para que el empaquetador lo ajuste sin tocar
  vpagraph_loader.pas: en Slackware sera /usr/lib64/vpa-linux, en Arch
  /usr/lib/vpa-linux, en una Raspberry /usr/lib/vpa-linux... El Makefile
  lo sobreescribira con PLUGIN_INSTALL_DIR cuando llegue la Fase 12.

  Ruta ABSOLUTA, sin barra final. }
const
  VPAGRAPH_INSTALL_DIR = '/usr/lib/vpa-linux';
