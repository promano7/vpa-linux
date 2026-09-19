{ VPA-Linux - consola PTC sobre SDL3 (WAYLAND.md, Fase 8, via B; nacio como
  prototipo en T7.3).
  Implementacion de la consola PTC sobre SDL3. Ver sdlconsoled.inc.

  Lo que SI hace: ventana Wayland (controlador forzado por hint), bufer
  propio XRGB de 32 bits, conversion desde la superficie indexada por la
  misma ruta TPTCCopy/Hermes que usa la consola X11, presentacion con
  vecino mas proximo y letterbox, raton en coordenadas de superficie,
  cursor en diana escalado con la ventana y ocultable, MoveMouseTo (R12),
  Save/Clear/Copy, cierre de ventana, mapa de teclas completo con el
  caracter de la distribucion activa (D-09, D-23) y el estado de entrada que
  publica PTCSDLInputState.
  Fuera de alcance: modos, relative mouse mode, opciones de ptcpas.conf. }

{ Estado de entrada vivo de la consola (modificadores y puntero dentro de la
  ventana). Lo escribe SOLO el hilo de la consola, al final de cada
  PumpEvents; lo lee cualquiera con PTCSDLInputState. Es una palabra de 32
  bits que se escribe de una vez, asi que no necesita cerrojo. Existe porque
  preguntarlo con Option cuesta una vuelta del bucle de ptcwrapper (10 ms) y
  el adaptador lo consulta en cada evento de raton (D-24). }
var
  SDLInputState: LongWord = 0;

function PTCSDLInputState: LongWord;
begin
  Result := SDLInputState;
end;

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
  { Las senales son del proceso, no de un plugin. Por omision SDL captura
    SIGINT y SIGTERM y las convierte en SDL_EVENT_QUIT, o sea en un "cerrar
    ventana" que VPA solo atiende en el mapa: un 'kill' con un menu o la
    ayuda abiertos no mataba a VPA. Con X11 la senal mata, y aqui tambien. }
  SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, '1');
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
  SDLInputState := 0;
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

{ Codigo PTC de un keycode de SDL, o PTCKEY_UNDEFINED si no tiene. Es la
  pareja de FNormalKeys/FFunctionKeys de la consola X11 (x11displayi.inc) y
  cubre las mismas teclas; el teclado numerico va aparte, por scancode. }
function SDLKeycodeToPTC(k: TSDL_Keycode): Integer;
begin
  case k of
    SDLK_BACKSPACE:    Result := PTCKEY_BACKSPACE;
    SDLK_TAB:          Result := PTCKEY_TAB;
    SDLK_CLEAR:        Result := PTCKEY_CLEAR;
    SDLK_RETURN:       Result := PTCKEY_ENTER;
    SDLK_PAUSE:        Result := PTCKEY_PAUSE;
    SDLK_SCROLLLOCK:   Result := PTCKEY_SCROLLLOCK;
    SDLK_ESCAPE:       Result := PTCKEY_ESCAPE;
    SDLK_DELETE:       Result := PTCKEY_DELETE;
    SDLK_HOME:         Result := PTCKEY_HOME;
    SDLK_LEFT:         Result := PTCKEY_LEFT;
    SDLK_UP:           Result := PTCKEY_UP;
    SDLK_RIGHT:        Result := PTCKEY_RIGHT;
    SDLK_DOWN:         Result := PTCKEY_DOWN;
    SDLK_PAGEUP:       Result := PTCKEY_PAGEUP;
    SDLK_PAGEDOWN:     Result := PTCKEY_PAGEDOWN;
    SDLK_END:          Result := PTCKEY_END;
    SDLK_PRINTSCREEN:  Result := PTCKEY_PRINTSCREEN;
    SDLK_INSERT:       Result := PTCKEY_INSERT;
    SDLK_NUMLOCKCLEAR: Result := PTCKEY_NUMLOCK;
    SDLK_F1..SDLK_F12: Result := PTCKEY_F1 + Integer(k - SDLK_F1);
    SDLK_LSHIFT, SDLK_RSHIFT: Result := PTCKEY_SHIFT;
    SDLK_LCTRL, SDLK_RCTRL:   Result := PTCKEY_CONTROL;
    SDLK_CAPSLOCK:     Result := PTCKEY_CAPSLOCK;
    SDLK_LALT, SDLK_RALT:     Result := PTCKEY_ALT;
    SDLK_SPACE:        Result := PTCKEY_SPACE;
    SDLK_COMMA:        Result := PTCKEY_COMMA;
    SDLK_MINUS:        Result := PTCKEY_MINUS;
    SDLK_PERIOD:       Result := PTCKEY_PERIOD;
    SDLK_SLASH:        Result := PTCKEY_SLASH;
    SDLK_0..SDLK_9:    Result := PTCKEY_ZERO + Integer(k - SDLK_0);
    SDLK_SEMICOLON:    Result := PTCKEY_SEMICOLON;
    SDLK_EQUALS:       Result := PTCKEY_EQUALS;
    SDLK_GRAVE:        Result := PTCKEY_BACKQUOTE;
    SDLK_APOSTROPHE:   Result := PTCKEY_QUOTE;
    SDLK_LEFTBRACKET:  Result := PTCKEY_OPENBRACKET;
    SDLK_BACKSLASH:    Result := PTCKEY_BACKSLASH;
    SDLK_RIGHTBRACKET: Result := PTCKEY_CLOSEBRACKET;
    SDLK_A..SDLK_Z:    Result := PTCKEY_A + Integer(k - SDLK_A);
  else
    Result := PTCKEY_UNDEFINED;
  end;
end;

{ Teclado numerico, por scancode (la tecla fisica) y estado de NumLock: con
  NumLock da PTCKEY_NUMPADn y el digito; sin el, la tecla de cursor, como la
  consola X11 con XK_KP_1 / XK_KP_End. False si no es del teclado numerico. }
function SDLNumPadToPTC(sc: TSDL_Scancode; NumLock: Boolean;
                        out code, uni: Integer): Boolean;
const
  { SDL_SCANCODE_KP_1..KP_9, KP_0, KP_PERIOD, en ese orden }
  Locked: array[0..10] of Integer = (PTCKEY_NUMPAD1, PTCKEY_NUMPAD2,
    PTCKEY_NUMPAD3, PTCKEY_NUMPAD4, PTCKEY_NUMPAD5, PTCKEY_NUMPAD6,
    PTCKEY_NUMPAD7, PTCKEY_NUMPAD8, PTCKEY_NUMPAD9, PTCKEY_NUMPAD0,
    PTCKEY_DECIMAL);
  LockedChar: array[0..10] of Char = '1234567890.';
  Unlocked: array[0..10] of Integer = (PTCKEY_END, PTCKEY_DOWN,
    PTCKEY_PAGEDOWN, PTCKEY_LEFT, PTCKEY_CLEAR, PTCKEY_RIGHT, PTCKEY_HOME,
    PTCKEY_UP, PTCKEY_PAGEUP, PTCKEY_INSERT, PTCKEY_DELETE);
begin
  Result := True;
  uni := 0;
  case sc of
    SDL_SCANCODE_KP_DIVIDE:   begin code := PTCKEY_DIVIDE;   uni := Ord('/'); end;
    SDL_SCANCODE_KP_MULTIPLY: begin code := PTCKEY_MULTIPLY; uni := Ord('*'); end;
    SDL_SCANCODE_KP_MINUS:    begin code := PTCKEY_SUBTRACT; uni := Ord('-'); end;
    SDL_SCANCODE_KP_PLUS:     begin code := PTCKEY_ADD;      uni := Ord('+'); end;
    SDL_SCANCODE_KP_ENTER:    begin code := PTCKEY_ENTER;    uni := 13; end;
    SDL_SCANCODE_KP_1..SDL_SCANCODE_KP_PERIOD:
      if NumLock then
      begin
        code := Locked[sc - SDL_SCANCODE_KP_1];
        uni := Ord(LockedChar[sc - SDL_SCANCODE_KP_1]);
      end
      else
        code := Unlocked[sc - SDL_SCANCODE_KP_1];
  else
    Result := False;
  end;
end;

{ Evento de tecla de SDL -> TPTCKeyEvent, con lo mismo que entrega la consola
  X11 (TX11Display.HandleKeyEvent), que es lo que espera ptccrt:
    - Unicode: el caracter de la tecla EN LA DISTRIBUCION ACTIVA y con
      Shift/AltGr/BloqMayus aplicados (D-09). Sale del mapa de teclas de SDL,
      SDL_GetKeyFromScancode(scancode, mod, False), que en Wayland se
      construye del keymap xkb del compositor. NO se usa
      SDL_EVENT_TEXT_INPUT (D-23): llega en un evento aparte y, sobre todo,
      no llega con Ctrl pulsado, que es justo el caso de Ctrl-+ / Ctrl-- de
      3.67.5. X11 hace lo mismo: el caracter sale del keysym, no del texto
      compuesto. Solo en la pulsacion; al soltar, -1, como X11.
    - Code: primero el del caracter con modificadores y, si no tiene, el de
      la tecla base: el mismo orden que el "hack" de X11 (en la distribucion
      alemana Shift-7 es '/', y el codigo es PTCKEY_SLASH).
    - Una tecla sin codigo PTC se entrega igual, con PTCKEY_UNDEFINED y su
      caracter: asi llega el '+' de las distribuciones donde es tecla propia. }
procedure TSDLConsole.TranslateKey(const AEvent: TSDL_KeyboardEvent);
var
  code, uni: Integer;
  ch: TSDL_Keycode;
  m: TPTCModifierKeys;
begin
  m := [];
  if (AEvent.mod_ and SDL_KMOD_SHIFT) <> 0 then Include(m, pmkShift);
  if (AEvent.mod_ and SDL_KMOD_CTRL) <> 0 then Include(m, pmkControl);
  if (AEvent.mod_ and SDL_KMOD_ALT) <> 0 then Include(m, pmkAlt);
  if (AEvent.mod_ and SDL_KMOD_CAPS) <> 0 then Include(m, pmkCapsLockActive);
  if (AEvent.mod_ and SDL_KMOD_NUM) <> 0 then Include(m, pmkNumLockActive);
  case AEvent.key of
    SDLK_RSHIFT, SDLK_RCTRL, SDLK_RALT: Include(m, pmkRightKey);
  end;

  if SDLNumPadToPTC(AEvent.scancode, pmkNumLockActive in m, code, uni) then
    Include(m, pmkNumPadKey)
  else
  begin
    if AEvent.key = SDLK_NUMLOCKCLEAR then
      Include(m, pmkNumPadKey);
    ch := SDL_GetKeyFromScancode(AEvent.scancode, AEvent.mod_, False);
    uni := 0;
    if (ch and (SDLK_SCANCODE_MASK or SDLK_EXTENDED_MASK)) = 0 then
      uni := Integer(ch);
    if uni = 127 then
      uni := 0;                       { Supr: X11 no le da caracter }
    code := SDLKeycodeToPTC(ch);
    if code = PTCKEY_UNDEFINED then
      code := SDLKeycodeToPTC(AEvent.key);
    { Shift-Tab: X11 lo entrega como Tab con caracter 9 }
    if code = PTCKEY_TAB then
      uni := 9;
  end;
  if not AEvent.down then
    uni := -1;
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
  PublishInputState;
end;

procedure TSDLConsole.PublishInputState;
var
  st: LongWord;
  md: TSDL_Keymod;
begin
  st := 0;
  md := SDL_GetModState;
  if (md and SDL_KMOD_SHIFT) <> 0 then st := st or PTC_SDL_INPUT_SHIFT;
  if (md and SDL_KMOD_CTRL) <> 0 then st := st or PTC_SDL_INPUT_CONTROL;
  if (md and SDL_KMOD_ALT) <> 0 then st := st or PTC_SDL_INPUT_ALT;
  if SDL_GetMouseFocus = FWindow then st := st or PTC_SDL_INPUT_POINTER_INSIDE;
  SDLInputState := st;
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
