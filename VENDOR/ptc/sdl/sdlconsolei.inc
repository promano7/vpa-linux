{ VPA-Linux - consola PTC sobre SDL3 (WAYLAND.md, Fase 8, via B; nacio como
  prototipo en T7.3).
  Implementacion de la consola PTC sobre SDL3. Ver sdlconsoled.inc.

  Lo que SI hace: ventana Wayland (controlador forzado por hint), bufer
  propio XRGB de 32 bits, conversion desde la superficie indexada por la
  misma ruta TPTCCopy/Hermes que usa la consola X11, presentacion con
  vecino mas proximo y letterbox, raton en coordenadas de superficie,
  cursor en diana escalado con la ventana y ocultable, MoveMouseTo (R12),
  Save/Clear/Copy, cierre de ventana y un mapa de teclas parcial.
  Lo que NO hace (Fase 9): mapa de teclas completo con caracter Unicode.
  Fuera de alcance: modos, relative mouse mode, opciones de ptcpas.conf. }

constructor TSDLConsole.Create;
begin
  inherited Create;
  FCopy := TPTCCopy.Create;
  FClear := TPTCClear.Create;
  FEventQueue := TEventQueue.Create;
  FPalette := TPTCPalette.Create;
  FFormat := TPTCFormat.Create(32, $FF0000, $FF00, $FF);
  FArea := TPTCArea.Create;
  FClip := TPTCArea.Create;
  FLastX := -1; FLastY := -1;
  FCursorVisible := True;
end;

destructor TSDLConsole.Destroy;
begin
  Close;
  FreeAndNil(FEventQueue);
  FreeAndNil(FCopy);
  FreeAndNil(FClear);
  inherited Destroy;
end;

procedure TSDLConsole.CheckOpen;
begin
  if not FOpen then
    raise TPTCError.Create('console is not open');
end;

procedure TSDLConsole.Open(const ATitle: string; APages: Integer = 0);
begin
  Open(ATitle, 640, 480, FFormat, APages);
end;

procedure TSDLConsole.Open(const ATitle: string; AFormat: IPTCFormat;
                           APages: Integer = 0);
begin
  Open(ATitle, 640, 480, AFormat, APages);
end;

procedure TSDLConsole.Open(const ATitle: string; AMode: IPTCMode;
                           APages: Integer = 0);
begin
  Open(ATitle, AMode.Width, AMode.Height, AMode.Format, APages);
end;

procedure TSDLConsole.Open(const ATitle: string; AWidth, AHeight: Integer;
                           AFormat: IPTCFormat; APages: Integer = 0);
var
  v: Integer;
  flags: TSDL_WindowFlags;

  procedure Fail(const AWhat: string);
  var
    msg: string;
  begin
    msg := AWhat + ': ' + SDL_GetError;
    Close;
    raise TPTCError.Create(msg);
  end;

begin
  Close;
  { R10: los enlaces declaran una SDL; la que se carga no puede ser mas
    vieja. Dentro de la serie 3.x la ABI solo crece. }
  v := SDL_GetVersion;
  if v < SDL_VERSION then
    raise TPTCError.Create('SDL3 runtime ' + IntToStr(v) +
      ' is older than the bindings (' + IntToStr(SDL_VERSION) + ')');
  { Mesa y compania cuentan con las excepciones de coma flotante
    enmascaradas; la RTL de FPC las desenmascara (runtime error 207). }
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
                    exOverflow, exUnderflow, exPrecision]);
  { Hint y no variable de entorno (T8B.3): si no hay Wayland, SDL_Init
    falla en vez de caer a X11 en silencio. }
  SDL_SetHint(SDL_HINT_VIDEO_DRIVER, 'wayland');
  if not SDL_InitSubSystem(SDL_INIT_VIDEO) then
    raise TPTCError.Create('SDL_Init(video, wayland): ' + SDL_GetError);
  FOpen := True;
  flags := SDL_WINDOW_RESIZABLE;
  if FFullscreen then
    flags := flags or SDL_WINDOW_FULLSCREEN;
  FWindow := SDL_CreateWindow(PAnsiChar(ATitle), AWidth, AHeight, flags);
  if FWindow = nil then Fail('SDL_CreateWindow');
  FRenderer := SDL_CreateRenderer(FWindow, nil);
  if FRenderer = nil then Fail('SDL_CreateRenderer');
  FTexture := SDL_CreateTexture(FRenderer, SDL_PIXELFORMAT_XRGB8888,
                                SDL_TEXTUREACCESS_STREAMING, AWidth, AHeight);
  if FTexture = nil then Fail('SDL_CreateTexture');
  SDL_SetTextureScaleMode(FTexture, SDL_SCALEMODE_NEAREST);
  { Con esto SDL escala, centra y, sobre todo, devuelve el raton ya en
    coordenadas de superficie (SDL_ConvertEventToRenderCoordinates). }
  SDL_SetRenderLogicalPresentation(FRenderer, AWidth, AHeight,
                                   SDL_LOGICAL_PRESENTATION_LETTERBOX);
  FTitle := ATitle;
  FWidth := AWidth;
  FHeight := AHeight;
  SetLength(FPixels, AWidth * AHeight);
  FArea := TPTCArea.Create(0, 0, AWidth, AHeight);
  FClip := FArea;
  FPresentedPrefix := fpgetenv('VPA_GRAPH_PRESENTED');
  FPresentedFrame := 0;
  UpdateCursor;
  if not FCursorVisible then
    SDL_HideCursor;
  Update;
end;

{ La diana blanca de VPA: el mismo dibujo 15x15 que crea la consola X11 en
  x11windowdisplayi.inc (brazos en la fila y la columna 7, hueco central de
  3 px), ampliado NxN. Alli la escala se fija al abrir (ancho div 640); aqui
  la ventana se puede redimensionar y SDL escala la imagen, asi que la escala
  sale del tamano REAL de la imagen en la ventana y se rehace al cambiar.
  El cursor va en coordenadas de ventana, como el raton; de la densidad de
  pixeles (HiDPI) se ocupa SDL. Si no se puede crear, queda el del sistema. }
procedure TSDLConsole.UpdateCursor;
const
  W = 64;                          { 15*4 redondeado a multiplo de 8 }
var
  data, mask: array [0..W * W div 8 - 1] of Uint8;
  ww, wh, cscale, csize, cw, cx, cy, ox, oy: Integer;
  f: Double;
  cur: PSDL_Cursor;
begin
  if not FOpen or (FWindow = nil) then
    exit;
  ww := 0; wh := 0;
  SDL_GetWindowSize(FWindow, @ww, @wh);
  { letterbox: manda el eje que menos amplia }
  f := ww / FWidth;
  if wh / FHeight < f then
    f := wh / FHeight;
  cscale := Trunc(FWidth * f / 640 + 0.001);
  if cscale < 1 then cscale := 1;
  if cscale > 4 then cscale := 4;
  if (cscale = FCrossScale) and (FCrossCursor <> nil) then
    exit;
  csize := 15 * cscale;
  cw := (csize + 7) and not 7;     { SDL_CreateCursor: ancho multiplo de 8 }
  FillChar(data, SizeOf(data), 0); { data=0 + mask=1 -> blanco }
  FillChar(mask, SizeOf(mask), 0); { mask=0 -> transparente }
  for cy := 0 to csize - 1 do
    for cx := 0 to csize - 1 do
    begin
      ox := cx div cscale; oy := cy div cscale;
      if ((ox = 7) and ((oy <= 5) or (oy >= 9))) or
         ((oy = 7) and ((ox <= 5) or (ox >= 9))) then
        mask[cy * (cw div 8) + (cx div 8)] :=
          mask[cy * (cw div 8) + (cx div 8)] or ($80 shr (cx and 7));
    end;
  cur := SDL_CreateCursor(@data[0], @mask[0], cw, csize,
                          7 * cscale + cscale div 2, 7 * cscale + cscale div 2);
  if cur = nil then
    exit;
  SDL_SetCursor(cur);
  if FCrossCursor <> nil then
    SDL_DestroyCursor(FCrossCursor);
  FCrossCursor := cur;
  FCrossScale := cscale;
end;

procedure TSDLConsole.Close;
begin
  if not FOpen then
    exit;
  if FCrossCursor <> nil then
  begin
    SDL_SetCursor(SDL_GetDefaultCursor);
    SDL_DestroyCursor(FCrossCursor);
    FCrossCursor := nil;
    FCrossScale := 0;
  end;
  if FTexture <> nil then SDL_DestroyTexture(FTexture);
  if FRenderer <> nil then SDL_DestroyRenderer(FRenderer);
  if FWindow <> nil then SDL_DestroyWindow(FWindow);
  FTexture := nil; FRenderer := nil; FWindow := nil;
  SDL_QuitSubSystem(SDL_INIT_VIDEO);
  SetLength(FPixels, 0);
  FOpen := False;
end;

procedure TSDLConsole.InternalResize(AWidth, AHeight: Integer);
begin
  { La superficie logica no cambia de tamano: escala SDL. }
end;

{ Copy, Save y Clear: lo mismo que TPTCSurface sobre el bufer propio. }
procedure TSDLConsole.Copy(ASurface: IPTCSurface);
begin
  CheckOpen;
  ASurface.Load(@FPixels[0], FWidth, FHeight, FWidth * 4, FFormat, FPalette);
end;

procedure TSDLConsole.Copy(ASurface: IPTCSurface; ASource, ADestination: IPTCArea);
begin
  CheckOpen;
  ASurface.Load(@FPixels[0], FWidth, FHeight, FWidth * 4, FFormat, FPalette,
                ASource, ADestination);
end;

procedure TSDLConsole.Load(const APixels: Pointer; AWidth, AHeight, APitch: Integer;
                           AFormat: IPTCFormat; APalette: IPTCPalette);
begin
  Load(APixels, AWidth, AHeight, APitch, AFormat, APalette,
       TPTCArea.Create(0, 0, AWidth, AHeight), FArea);
end;

procedure TSDLConsole.Load(const APixels: Pointer; AWidth, AHeight, APitch: Integer;
                           AFormat: IPTCFormat; APalette: IPTCPalette;
                           ASource, ADestination: IPTCArea);
var
  cs, cd: IPTCArea;
begin
  CheckOpen;
  TPTCClipper.Clip(ASource, TPTCArea.Create(0, 0, AWidth, AHeight), cs,
                   ADestination, FClip, cd);
  FCopy.Request(AFormat, FFormat);
  FCopy.Palette(APalette, FPalette);
  FCopy.Copy(APixels, cs.Left, cs.Top, cs.Width, cs.Height, APitch,
             @FPixels[0], cd.Left, cd.Top, cd.Width, cd.Height, FWidth * 4);
end;

procedure TSDLConsole.Save(APixels: Pointer; AWidth, AHeight, APitch: Integer;
                           AFormat: IPTCFormat; APalette: IPTCPalette);
begin
  Save(APixels, AWidth, AHeight, APitch, AFormat, APalette,
       FArea, TPTCArea.Create(0, 0, AWidth, AHeight));
end;

procedure TSDLConsole.Save(APixels: Pointer; AWidth, AHeight, APitch: Integer;
                           AFormat: IPTCFormat; APalette: IPTCPalette;
                           ASource, ADestination: IPTCArea);
var
  cs, cd: IPTCArea;
begin
  CheckOpen;
  TPTCClipper.Clip(ASource, FClip, cs,
                   ADestination, TPTCArea.Create(0, 0, AWidth, AHeight), cd);
  FCopy.Request(FFormat, AFormat);
  FCopy.Palette(FPalette, APalette);
  FCopy.Copy(@FPixels[0], cs.Left, cs.Top, cs.Width, cs.Height, FWidth * 4,
             APixels, cd.Left, cd.Top, cd.Width, cd.Height, APitch);
end;

function TSDLConsole.Lock: Pointer;
begin
  CheckOpen;
  Result := @FPixels[0];
end;

procedure TSDLConsole.Unlock;
begin
end;

procedure TSDLConsole.Clear;
begin
  Clear(TPTCColor.Create(0, 0, 0, 0));
end;

procedure TSDLConsole.Clear(AColor: IPTCColor);
begin
  Clear(AColor, FArea);
end;

procedure TSDLConsole.Clear(AColor: IPTCColor; AArea: IPTCArea);
var
  c: IPTCArea;
begin
  CheckOpen;
  c := TPTCClipper.Clip(AArea, FClip);
  FClear.Request(FFormat);
  FClear.Clear(@FPixels[0], c.Left, c.Top, c.Width, c.Height, FWidth * 4,
               AColor);
end;

procedure TSDLConsole.Configure(const AFileName: String);
begin
end;

function TSDLConsole.Option(const AOption: String): Boolean;
begin
  Result := True;
  if AOption = 'intercept window close' then
    FInterceptClose := True
  else if (AOption = 'fullscreen output') or (AOption = 'windowed output') then
  begin
    FFullscreen := AOption = 'fullscreen output';
    if FOpen then
      SDL_SetWindowFullscreen(FWindow, FFullscreen);
  end
  else if (AOption = 'show cursor') or (AOption = 'hide cursor') then
  begin
    { La usa ShowMouse. Antes de Open solo se anota. }
    FCursorVisible := AOption = 'show cursor';
    if FOpen then
      if FCursorVisible then SDL_ShowCursor else SDL_HideCursor;
  end
  else
    Result := FCopy.Option(AOption);
end;

procedure TSDLConsole.Palette(APalette: IPTCPalette);
begin
  FPalette.Load(APalette.Data);
end;

function TSDLConsole.Palette: IPTCPalette;
begin
  Result := FPalette;
end;

procedure TSDLConsole.Clip(AArea: IPTCArea);
begin
  FClip := TPTCClipper.Clip(AArea, FArea);
end;

function TSDLConsole.Clip: IPTCArea;
begin
  Result := FClip;
end;

function TSDLConsole.Modes: TPTCModeList;
begin
  SetLength(Result, 1);
  Result[0] := TPTCMode.Create(640, 480, FFormat);
end;

procedure TSDLConsole.Flush;
begin
end;

procedure TSDLConsole.Finish;
begin
end;

procedure TSDLConsole.Update;
var
  f: file;
  s: string;
begin
  CheckOpen;
  SDL_UpdateTexture(FTexture, nil, @FPixels[0], FWidth * 4);
  SDL_RenderClear(FRenderer);
  SDL_RenderTexture(FRenderer, FTexture, nil, nil);
  SDL_RenderPresent(FRenderer);
  { Instrumento de pruebas (nacio en la Fase 7, se queda para la 11): con
    VPA_GRAPH_PRESENTED=<prefijo>, cada bufer tal como se presento, en
    <prefijo>NNNNN.raw. El hilo del wrapper presenta por su cuenta, asi que
    es la unica forma de ver lo que de verdad llego a la ventana. }
  if FPresentedPrefix <> '' then
  begin
    Inc(FPresentedFrame);
    s := FPresentedPrefix + IntToStr(10000 + FPresentedFrame) + '.raw';
    Assign(f, s); Rewrite(f, 1);
    BlockWrite(f, FPixels[0], Length(FPixels) * 4);
    System.Close(f);
  end;
end;

procedure TSDLConsole.Update(AArea: IPTCArea);
begin
  Update;
end;

procedure TSDLConsole.TranslateKey(const AEvent: TSDL_KeyboardEvent);
var
  code, uni: Integer;
  k: TSDL_Keycode;
  m: TPTCModifierKeys;
begin
  k := AEvent.key;
  code := 0; uni := 0;
  case k of
    SDLK_RETURN: code := PTCKEY_ENTER;
    SDLK_ESCAPE, SDLK_BACKSPACE, SDLK_TAB, SDLK_SPACE, SDLK_DELETE: code := k;
    SDLK_A..SDLK_Z: code := k - 32;
    SDLK_0..SDLK_9: code := k;
    SDLK_F1..SDLK_F12: code := PTCKEY_F1 + (k - SDLK_F1);
    SDLK_LEFT: code := PTCKEY_LEFT;
    SDLK_RIGHT: code := PTCKEY_RIGHT;
    SDLK_UP: code := PTCKEY_UP;
    SDLK_DOWN: code := PTCKEY_DOWN;
    SDLK_HOME: code := PTCKEY_HOME;
    SDLK_END: code := PTCKEY_END;
    SDLK_PAGEUP: code := PTCKEY_PAGEUP;
    SDLK_PAGEDOWN: code := PTCKEY_PAGEDOWN;
    SDLK_INSERT: code := PTCKEY_INSERT;
    SDLK_LSHIFT, SDLK_RSHIFT: code := PTCKEY_SHIFT;
    SDLK_LCTRL, SDLK_RCTRL: code := PTCKEY_CONTROL;
    SDLK_LALT, SDLK_RALT: code := PTCKEY_ALT;
  end;
  if code = 0 then
    exit;
  { PROTOTIPO: el caracter sale del keycode; el de verdad tiene que salir de
    SDL_EVENT_TEXT_INPUT para respetar la distribucion (D-09). }
  if (k >= 32) and (k < 127) then
    uni := k;
  m := [];
  if (AEvent.mod_ and SDL_KMOD_SHIFT) <> 0 then Include(m, pmkShift);
  if (AEvent.mod_ and SDL_KMOD_CTRL) <> 0 then Include(m, pmkControl);
  if (AEvent.mod_ and SDL_KMOD_ALT) <> 0 then Include(m, pmkAlt);
  FEventQueue.AddEvent(TPTCKeyEvent.Create(code, uni, m, AEvent.down));
end;

procedure TSDLConsole.PumpEvents(AWait: Boolean);
var
  ev: TSDL_Event;
  got: Boolean;
  x, y: Integer;
  b: TPTCMouseButton;
begin
  CheckOpen;
  if AWait then
    got := SDL_WaitEventTimeout(@ev, 50)
  else
    got := SDL_PollEvent(@ev);
  while got do
  begin
    case ev.type_ of
      SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
        if FInterceptClose then
          FEventQueue.AddEvent(TPTCCloseEvent.Create)
        else
          Halt(0);
      SDL_EVENT_WINDOW_EXPOSED:
        Update;
      SDL_EVENT_WINDOW_RESIZED:
        UpdateCursor;
      SDL_EVENT_KEY_DOWN, SDL_EVENT_KEY_UP:
        TranslateKey(ev.key);
      SDL_EVENT_MOUSE_MOTION:
        begin
          SDL_ConvertEventToRenderCoordinates(FRenderer, @ev);
          x := Trunc(ev.motion.x); y := Trunc(ev.motion.y);
          if (x >= 0) and (y >= 0) and (x < FWidth) and (y < FHeight) then
          begin
            if FLastX < 0 then begin FLastX := x; FLastY := y; end;
            FEventQueue.AddEvent(TPTCMouseEvent.Create(x, y, x - FLastX,
                                                       y - FLastY, FButtons));
            FLastX := x; FLastY := y;
          end;
        end;
      SDL_EVENT_MOUSE_BUTTON_DOWN, SDL_EVENT_MOUSE_BUTTON_UP:
        begin
          SDL_ConvertEventToRenderCoordinates(FRenderer, @ev);
          x := Trunc(ev.button.x); y := Trunc(ev.button.y);
          case ev.button.button of
            1: b := PTCMouseButton1;   { SDL: 1 izq, 2 centro, 3 dcho }
            2: b := PTCMouseButton3;
            3: b := PTCMouseButton2;
          else
            b := PTCMouseButton10;
          end;
          if b <> PTCMouseButton10 then
          begin
            if ev.button.down then Include(FButtons, b)
                              else Exclude(FButtons, b);
            FEventQueue.AddEvent(TPTCMouseButtonEvent.Create(x, y, 0, 0,
                                   FButtons, ev.button.down, b));
          end;
        end;
    end;
    got := SDL_PollEvent(@ev);
  end;
end;

function TSDLConsole.NextEvent(out AEvent: IPTCEvent; AWait: Boolean;
                               const AEventMask: TPTCEventMask): Boolean;
begin
  repeat
    PumpEvents(AWait);
    AEvent := FEventQueue.NextEvent(AEventMask);
  until (not AWait) or (AEvent <> nil);
  Result := AEvent <> nil;
end;

function TSDLConsole.PeekEvent(AWait: Boolean;
                               const AEventMask: TPTCEventMask): IPTCEvent;
begin
  repeat
    PumpEvents(AWait);
    Result := FEventQueue.PeekEvent(AEventMask);
  until (not AWait) or (Result <> nil);
end;

function TSDLConsole.MoveMouseTo(X, Y: Integer): Boolean;
var
  wx, wy: cfloat;
begin
  { R12. X,Y vienen en coordenadas de consola; SDL_WarpMouseInWindow las
    quiere de ventana: camino inverso al de los eventos, letterbox incluido.
    En Wayland SDL usa wp_pointer_warp_v1 si el compositor lo anuncia y, si
    no, el truco de zwp_pointer_constraints_v1 (bloquear, dar la pista de
    posicion, soltar). Sin ninguno de los dos no mueve nada y solo deja el
    motivo en SDL_GetError (el procedimiento no devuelve resultado): de ahi
    el SDL_ClearError previo. Tras mover, la propia SDL encola el evento de
    movimiento, asi que ptcmouse se entera por el camino normal. }
  Result := False;
  if not FOpen or (X < 0) or (Y < 0) or (X >= FWidth) or (Y >= FHeight) then
    exit;
  if not SDL_RenderCoordinatesToWindow(FRenderer, X, Y, @wx, @wy) then
    exit;
  SDL_ClearError;
  SDL_WarpMouseInWindow(FWindow, wx, wy);
  Result := SDL_GetError^ = #0;
end;

function TSDLConsole.GetWidth: Integer;  begin Result := FWidth; end;
function TSDLConsole.GetHeight: Integer; begin Result := FHeight; end;
function TSDLConsole.GetPitch: Integer;  begin Result := FWidth * 4; end;
function TSDLConsole.GetArea: IPTCArea;  begin Result := FArea; end;
function TSDLConsole.GetFormat: IPTCFormat; begin Result := FFormat; end;
function TSDLConsole.GetPages: Integer;  begin Result := 1; end;
function TSDLConsole.GetName: string;    begin Result := 'SDL3'; end;
function TSDLConsole.GetTitle: string;   begin Result := FTitle; end;

function TSDLConsole.GetInformation: string;
begin
  if FOpen then
    Result := 'SDL3 console, video driver ' + SDL_GetCurrentVideoDriver +
              ', renderer ' + SDL_GetRendererName(FRenderer)
  else
    Result := 'SDL3 console (closed)';
end;

function TSDLConsole.GetOpenGL_Enabled: Boolean; begin Result := False; end;

procedure TSDLConsole.SetOpenGL_Enabled(AValue: Boolean);
begin
  if AValue then
    raise TPTCError.Create('OpenGL is not supported by the SDL3 console');
end;

procedure TSDLConsole.OpenGL_SwapBuffers; begin end;
procedure TSDLConsole.OpenGL_SetSwapInterval(AInterval: Integer); begin end;
function TSDLConsole.OpenGL_GetSwapInterval: Integer; begin Result := 0; end;
