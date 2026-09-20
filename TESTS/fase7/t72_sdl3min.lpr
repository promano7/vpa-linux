{ T7.2 (WAYLAND.md) - prototipo DESECHABLE, no se integra en VPA.
  Confirma la cadena FPC -> enlaces SDL3-for-Pascal -> libSDL3 -> Wayland:
  abre una ventana con el controlador de video forzado a 'wayland', sube
  una textura de 640x480 en streaming, la presenta con vecino mas proximo
  y relee el resultado del renderizador para comprobar que llego entero.
  Sale con 0 si todo fue bien y con 1 al primer fallo. }
program t72_sdl3min;
{$mode objfpc}{$H+}
uses Math, SDL3;

const
  W = 640; H = 480; FRAMES = 120;

var
  win: PSDL_Window; ren: PSDL_Renderer; tex: PSDL_Texture;
  buf: array[0..W*H-1] of LongWord;
  ev: TSDL_Event; v: LongInt; f, x, y: Integer;
  t0, t1: QWord; shot: PSDL_Surface; p: PLongWord; bad: LongInt;

procedure Die(const what: string);
begin
  WriteLn('FAIL ', what, ': ', SDL_GetError);
  Halt(1);
end;

function Pix(ax, ay, af: Integer): LongWord;
begin
  Pix := $FF000000 or (LongWord((ax + af) and $FF) shl 16)
                   or (LongWord(ay and $FF) shl 8)
                   or LongWord((ax xor ay) and $FF);
end;

begin
  { Sin esto el programa muere con 'Runtime error 207' dentro de Mesa: la RTL
    de FPC desenmascara las excepciones de coma flotante y las bibliotecas C
    cuentan con que esten enmascaradas. El plugin Wayland tendra que hacer lo
    mismo, y como la mascara es estado del hilo, afecta tambien a VPA. }
  if ParamStr(1) <> '--sin-mascara' then
    SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
                      exOverflow, exUnderflow, exPrecision]);
  v := SDL_GetVersion;
  WriteLn('SDL enlazada en ejecucion: ', v div 1000000, '.',
          (v div 1000) mod 1000, '.', v mod 1000,
          '   enlaces compilados contra: ', SDL_MAJOR_VERSION, '.',
          SDL_MINOR_VERSION, '.', SDL_MICRO_VERSION);
  { El hint, no solo la variable de entorno (T8B.3): sin Wayland, falla. }
  if not SDL_SetHint(SDL_HINT_VIDEO_DRIVER, 'wayland') then Die('SetHint');
  if not SDL_Init(SDL_INIT_VIDEO) then Die('Init');
  WriteLn('controlador de video: ', SDL_GetCurrentVideoDriver);
  win := SDL_CreateWindow('T7.2', W, H, SDL_WINDOW_RESIZABLE);
  if win = nil then Die('CreateWindow');
  ren := SDL_CreateRenderer(win, nil);
  if ren = nil then Die('CreateRenderer');
  WriteLn('renderizador: ', SDL_GetRendererName(ren));
  tex := SDL_CreateTexture(ren, SDL_PIXELFORMAT_XRGB8888,
                           SDL_TEXTUREACCESS_STREAMING, W, H);
  if tex = nil then Die('CreateTexture');
  if not SDL_SetTextureScaleMode(tex, SDL_SCALEMODE_NEAREST) then
    Die('ScaleMode');
  t0 := SDL_GetTicksNS;
  for f := 0 to FRAMES - 1 do
  begin
    while SDL_PollEvent(@ev) do ;
    for y := 0 to H - 1 do
      for x := 0 to W - 1 do buf[y*W + x] := Pix(x, y, f);
    if not SDL_UpdateTexture(tex, nil, @buf, W*4) then Die('UpdateTexture');
    SDL_RenderClear(ren);
    if not SDL_RenderTexture(ren, tex, nil, nil) then Die('RenderTexture');
    if f = FRAMES - 1 then
    begin
      shot := SDL_RenderReadPixels(ren, nil);
      if shot = nil then Die('RenderReadPixels');
      { Cada renderizador relee en su formato nativo (OpenGL da ABGR). }
      shot := SDL_ConvertSurface(shot, SDL_PIXELFORMAT_XRGB8888);
      if shot = nil then Die('ConvertSurface');
      WriteLn('releido: ', shot^.w, 'x', shot^.h);
      bad := 0;
      if (shot^.w = W) and (shot^.h = H) then
        for y := 0 to H - 1 do
        begin
          p := PLongWord(PByte(shot^.pixels) + y*shot^.pitch);
          for x := 0 to W - 1 do
            if (p[x] and $FFFFFF) <> (Pix(x, y, f) and $FFFFFF) then Inc(bad);
        end
      else bad := -1;
      WriteLn('pixeles distintos al releer: ', bad);
    end;
    if not SDL_RenderPresent(ren) then Die('RenderPresent');
  end;
  t1 := SDL_GetTicksNS;
  WriteLn(FRAMES, ' cuadros en ', (t1 - t0) div 1000000, ' ms');
  SDL_DestroyWindow(win);
  SDL_Quit;
  if bad <> 0 then Halt(1);
  WriteLn('OK');
end.
