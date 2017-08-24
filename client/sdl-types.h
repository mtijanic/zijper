/**
 * @file
 * @brief   SDL-1.2 types, copied from /usr/include/SDL/
 * @author  slouken@libsdl.org
 * @license LGPL-2.1+
 */


/** @name SDL_INIT Flags
 *  These are the flags which may be passed to SDL_Init() -- you should
 *  specify the subsystems which you will be using in your application.
 */
/*@{*/
#define SDL_INIT_TIMER      0x00000001
#define SDL_INIT_AUDIO      0x00000010
#define SDL_INIT_VIDEO      0x00000020
#define SDL_INIT_CDROM      0x00000100
#define SDL_INIT_JOYSTICK   0x00000200
#define SDL_INIT_NOPARACHUTE    0x00100000  /**< Don't catch fatal signals */
#define SDL_INIT_EVENTTHREAD    0x01000000  /**< Not supported on all OS's */
#define SDL_INIT_EVERYTHING 0x0000FFFF

/*@{*/
typedef enum {
    SDL_FALSE = 0,
    SDL_TRUE  = 1
} SDL_bool;

/** @name Useful data types */
/*@{*/
typedef struct SDL_Rect {
    int16_t x, y;
    uint16_t w, h;
} SDL_Rect;


/** What we really want is a mapping of every raw key on the keyboard.
 *  To support international keyboards, we use the range 0xA1 - 0xFF
 *  as international virtual keycodes.  We'll follow in the footsteps of X11...
 *  @brief The names of the keys
 */
typedef enum {
        /** @name ASCII mapped keysyms
         *  The keyboard syms have been cleverly chosen to map to ASCII
         */
        /*@{*/
    SDLK_UNKNOWN        = 0,
    SDLK_FIRST      = 0,
    SDLK_BACKSPACE      = 8,
    SDLK_TAB        = 9,
    SDLK_CLEAR      = 12,
    SDLK_RETURN     = 13,
    SDLK_PAUSE      = 19,
    SDLK_ESCAPE     = 27,
    SDLK_SPACE      = 32,
    SDLK_EXCLAIM        = 33,
    SDLK_QUOTEDBL       = 34,
    SDLK_HASH       = 35,
    SDLK_DOLLAR     = 36,
    SDLK_AMPERSAND      = 38,
    SDLK_QUOTE      = 39,
    SDLK_LEFTPAREN      = 40,
    SDLK_RIGHTPAREN     = 41,
    SDLK_ASTERISK       = 42,
    SDLK_PLUS       = 43,
    SDLK_COMMA      = 44,
    SDLK_MINUS      = 45,
    SDLK_PERIOD     = 46,
    SDLK_SLASH      = 47,
    SDLK_0          = 48,
    SDLK_1          = 49,
    SDLK_2          = 50,
    SDLK_3          = 51,
    SDLK_4          = 52,
    SDLK_5          = 53,
    SDLK_6          = 54,
    SDLK_7          = 55,
    SDLK_8          = 56,
    SDLK_9          = 57,
    SDLK_COLON      = 58,
    SDLK_SEMICOLON      = 59,
    SDLK_LESS       = 60,
    SDLK_EQUALS     = 61,
    SDLK_GREATER        = 62,
    SDLK_QUESTION       = 63,
    SDLK_AT         = 64,
    /*
       Skip uppercase letters
     */
    SDLK_LEFTBRACKET    = 91,
    SDLK_BACKSLASH      = 92,
    SDLK_RIGHTBRACKET   = 93,
    SDLK_CARET      = 94,
    SDLK_UNDERSCORE     = 95,
    SDLK_BACKQUOTE      = 96,
    SDLK_a          = 97,
    SDLK_b          = 98,
    SDLK_c          = 99,
    SDLK_d          = 100,
    SDLK_e          = 101,
    SDLK_f          = 102,
    SDLK_g          = 103,
    SDLK_h          = 104,
    SDLK_i          = 105,
    SDLK_j          = 106,
    SDLK_k          = 107,
    SDLK_l          = 108,
    SDLK_m          = 109,
    SDLK_n          = 110,
    SDLK_o          = 111,
    SDLK_p          = 112,
    SDLK_q          = 113,
    SDLK_r          = 114,
    SDLK_s          = 115,
    SDLK_t          = 116,
    SDLK_u          = 117,
    SDLK_v          = 118,
    SDLK_w          = 119,
    SDLK_x          = 120,
    SDLK_y          = 121,
    SDLK_z          = 122,
    SDLK_DELETE     = 127,
    /* End of ASCII mapped keysyms */
        /*@}*/

    /** @name International keyboard syms */
        /*@{*/
    SDLK_WORLD_0        = 160,      /* 0xA0 */
    SDLK_WORLD_1        = 161,
    SDLK_WORLD_2        = 162,
    SDLK_WORLD_3        = 163,
    SDLK_WORLD_4        = 164,
    SDLK_WORLD_5        = 165,
    SDLK_WORLD_6        = 166,
    SDLK_WORLD_7        = 167,
    SDLK_WORLD_8        = 168,
    SDLK_WORLD_9        = 169,
    SDLK_WORLD_10       = 170,
    SDLK_WORLD_11       = 171,
    SDLK_WORLD_12       = 172,
    SDLK_WORLD_13       = 173,
    SDLK_WORLD_14       = 174,
    SDLK_WORLD_15       = 175,
    SDLK_WORLD_16       = 176,
    SDLK_WORLD_17       = 177,
    SDLK_WORLD_18       = 178,
    SDLK_WORLD_19       = 179,
    SDLK_WORLD_20       = 180,
    SDLK_WORLD_21       = 181,
    SDLK_WORLD_22       = 182,
    SDLK_WORLD_23       = 183,
    SDLK_WORLD_24       = 184,
    SDLK_WORLD_25       = 185,
    SDLK_WORLD_26       = 186,
    SDLK_WORLD_27       = 187,
    SDLK_WORLD_28       = 188,
    SDLK_WORLD_29       = 189,
    SDLK_WORLD_30       = 190,
    SDLK_WORLD_31       = 191,
    SDLK_WORLD_32       = 192,
    SDLK_WORLD_33       = 193,
    SDLK_WORLD_34       = 194,
    SDLK_WORLD_35       = 195,
    SDLK_WORLD_36       = 196,
    SDLK_WORLD_37       = 197,
    SDLK_WORLD_38       = 198,
    SDLK_WORLD_39       = 199,
    SDLK_WORLD_40       = 200,
    SDLK_WORLD_41       = 201,
    SDLK_WORLD_42       = 202,
    SDLK_WORLD_43       = 203,
    SDLK_WORLD_44       = 204,
    SDLK_WORLD_45       = 205,
    SDLK_WORLD_46       = 206,
    SDLK_WORLD_47       = 207,
    SDLK_WORLD_48       = 208,
    SDLK_WORLD_49       = 209,
    SDLK_WORLD_50       = 210,
    SDLK_WORLD_51       = 211,
    SDLK_WORLD_52       = 212,
    SDLK_WORLD_53       = 213,
    SDLK_WORLD_54       = 214,
    SDLK_WORLD_55       = 215,
    SDLK_WORLD_56       = 216,
    SDLK_WORLD_57       = 217,
    SDLK_WORLD_58       = 218,
    SDLK_WORLD_59       = 219,
    SDLK_WORLD_60       = 220,
    SDLK_WORLD_61       = 221,
    SDLK_WORLD_62       = 222,
    SDLK_WORLD_63       = 223,
    SDLK_WORLD_64       = 224,
    SDLK_WORLD_65       = 225,
    SDLK_WORLD_66       = 226,
    SDLK_WORLD_67       = 227,
    SDLK_WORLD_68       = 228,
    SDLK_WORLD_69       = 229,
    SDLK_WORLD_70       = 230,
    SDLK_WORLD_71       = 231,
    SDLK_WORLD_72       = 232,
    SDLK_WORLD_73       = 233,
    SDLK_WORLD_74       = 234,
    SDLK_WORLD_75       = 235,
    SDLK_WORLD_76       = 236,
    SDLK_WORLD_77       = 237,
    SDLK_WORLD_78       = 238,
    SDLK_WORLD_79       = 239,
    SDLK_WORLD_80       = 240,
    SDLK_WORLD_81       = 241,
    SDLK_WORLD_82       = 242,
    SDLK_WORLD_83       = 243,
    SDLK_WORLD_84       = 244,
    SDLK_WORLD_85       = 245,
    SDLK_WORLD_86       = 246,
    SDLK_WORLD_87       = 247,
    SDLK_WORLD_88       = 248,
    SDLK_WORLD_89       = 249,
    SDLK_WORLD_90       = 250,
    SDLK_WORLD_91       = 251,
    SDLK_WORLD_92       = 252,
    SDLK_WORLD_93       = 253,
    SDLK_WORLD_94       = 254,
    SDLK_WORLD_95       = 255,      /* 0xFF */
        /*@}*/

    /** @name Numeric keypad */
        /*@{*/
    SDLK_KP0        = 256,
    SDLK_KP1        = 257,
    SDLK_KP2        = 258,
    SDLK_KP3        = 259,
    SDLK_KP4        = 260,
    SDLK_KP5        = 261,
    SDLK_KP6        = 262,
    SDLK_KP7        = 263,
    SDLK_KP8        = 264,
    SDLK_KP9        = 265,
    SDLK_KP_PERIOD      = 266,
    SDLK_KP_DIVIDE      = 267,
    SDLK_KP_MULTIPLY    = 268,
    SDLK_KP_MINUS       = 269,
    SDLK_KP_PLUS        = 270,
    SDLK_KP_ENTER       = 271,
    SDLK_KP_EQUALS      = 272,
        /*@}*/

    /** @name Arrows + Home/End pad */
        /*@{*/
    SDLK_UP         = 273,
    SDLK_DOWN       = 274,
    SDLK_RIGHT      = 275,
    SDLK_LEFT       = 276,
    SDLK_INSERT     = 277,
    SDLK_HOME       = 278,
    SDLK_END        = 279,
    SDLK_PAGEUP     = 280,
    SDLK_PAGEDOWN       = 281,
        /*@}*/

    /** @name Function keys */
        /*@{*/
    SDLK_F1         = 282,
    SDLK_F2         = 283,
    SDLK_F3         = 284,
    SDLK_F4         = 285,
    SDLK_F5         = 286,
    SDLK_F6         = 287,
    SDLK_F7         = 288,
    SDLK_F8         = 289,
    SDLK_F9         = 290,
    SDLK_F10        = 291,
    SDLK_F11        = 292,
    SDLK_F12        = 293,
    SDLK_F13        = 294,
    SDLK_F14        = 295,
    SDLK_F15        = 296,
        /*@}*/

    /** @name Key state modifier keys */
        /*@{*/
    SDLK_NUMLOCK        = 300,
    SDLK_CAPSLOCK       = 301,
    SDLK_SCROLLOCK      = 302,
    SDLK_RSHIFT     = 303,
    SDLK_LSHIFT     = 304,
    SDLK_RCTRL      = 305,
    SDLK_LCTRL      = 306,
    SDLK_RALT       = 307,
    SDLK_LALT       = 308,
    SDLK_RMETA      = 309,
    SDLK_LMETA      = 310,
    SDLK_LSUPER     = 311,      /**< Left "Windows" key */
    SDLK_RSUPER     = 312,      /**< Right "Windows" key */
    SDLK_MODE       = 313,      /**< "Alt Gr" key */
    SDLK_COMPOSE        = 314,      /**< Multi-key compose key */
        /*@}*/

    /** @name Miscellaneous function keys */
        /*@{*/
    SDLK_HELP       = 315,
    SDLK_PRINT      = 316,
    SDLK_SYSREQ     = 317,
    SDLK_BREAK      = 318,
    SDLK_MENU       = 319,
    SDLK_POWER      = 320,      /**< Power Macintosh power key */
    SDLK_EURO       = 321,      /**< Some european keyboards */
    SDLK_UNDO       = 322,      /**< Atari keyboard has Undo */
        /*@}*/

    /* Add any other keys here */

    SDLK_LAST
} SDLKey;

/** Enumeration of valid key mods (possibly OR'd together) */
typedef enum {
    KMOD_NONE  = 0x0000,
    KMOD_LSHIFT= 0x0001,
    KMOD_RSHIFT= 0x0002,
    KMOD_LCTRL = 0x0040,
    KMOD_RCTRL = 0x0080,
    KMOD_LALT  = 0x0100,
    KMOD_RALT  = 0x0200,
    KMOD_LMETA = 0x0400,
    KMOD_RMETA = 0x0800,
    KMOD_NUM   = 0x1000,
    KMOD_CAPS  = 0x2000,
    KMOD_MODE  = 0x4000,
    KMOD_RESERVED = 0x8000
} SDLMod;

#define KMOD_CTRL   (KMOD_LCTRL|KMOD_RCTRL)
#define KMOD_SHIFT  (KMOD_LSHIFT|KMOD_RSHIFT)
#define KMOD_ALT    (KMOD_LALT|KMOD_RALT)
#define KMOD_META   (KMOD_LMETA|KMOD_RMETA)

/** Keysym structure
 *
 *  - The scancode is hardware dependent, and should not be used by general
 *    applications.  If no hardware scancode is available, it will be 0.
 *
 *  - The 'unicode' translated character is only available when character
 *    translation is enabled by the SDL_EnableUNICODE() API.  If non-zero,
 *    this is a UNICODE character corresponding to the keypress.  If the
 *    high 9 bits of the character are 0, then this maps to the equivalent
 *    ASCII character:
 *      @code
 *  char ch;
 *  if ( (keysym.unicode & 0xFF80) == 0 ) {
 *      ch = keysym.unicode & 0x7F;
 *  } else {
 *      An international character..
 *  }
 *      @endcode
 */
typedef struct SDL_keysym {
    uint8_t scancode;         /**< hardware specific scancode */
    SDLKey sym;         /**< SDL virtual keysym */
    SDLMod mod;         /**< current key modifiers */
    uint16_t unicode;         /**< translated character */
} SDL_keysym;

/** This is the mask which refers to all hotkey bindings */
#define SDL_ALL_HOTKEYS     0xFFFFFFFF

typedef struct WMcursor WMcursor;   /**< Implementation dependent */
typedef struct SDL_Cursor {
    SDL_Rect area;          /**< The area of the mouse cursor */
    int16_t hot_x, hot_y;        /**< The "tip" of the cursor */
    uint8_t *data;            /**< B/W cursor data */
    uint8_t *mask;            /**< B/W cursor mask */
    uint8_t *save[2];         /**< Place to save cursor area */
    WMcursor *wm_cursor;        /**< Window-manager cursor */
} SDL_Cursor;


/*@{*/
/** Used as a mask when testing buttons in buttonstate
 *  Button 1:   Left mouse button
 *  Button 2:   Middle mouse button
 *  Button 3:   Right mouse button
 *  Button 4:   Mouse wheel up   (may also be a real button)
 *  Button 5:   Mouse wheel down (may also be a real button)
 */
#define SDL_BUTTON(X)       (1 << ((X)-1))
#define SDL_BUTTON_LEFT     1
#define SDL_BUTTON_MIDDLE   2
#define SDL_BUTTON_RIGHT    3
#define SDL_BUTTON_WHEELUP  4
#define SDL_BUTTON_WHEELDOWN    5
#define SDL_BUTTON_X1       6
#define SDL_BUTTON_X2       7
#define SDL_BUTTON_LMASK    SDL_BUTTON(SDL_BUTTON_LEFT)
#define SDL_BUTTON_MMASK    SDL_BUTTON(SDL_BUTTON_MIDDLE)
#define SDL_BUTTON_RMASK    SDL_BUTTON(SDL_BUTTON_RIGHT)
#define SDL_BUTTON_X1MASK   SDL_BUTTON(SDL_BUTTON_X1)
#define SDL_BUTTON_X2MASK   SDL_BUTTON(SDL_BUTTON_X2)
/*@}*/





/** Event enumerations */
typedef enum {
       SDL_NOEVENT = 0,         /**< Unused (do not remove) */
       SDL_ACTIVEEVENT,         /**< Application loses/gains visibility */
       SDL_KEYDOWN,         /**< Keys pressed */
       SDL_KEYUP,           /**< Keys released */
       SDL_MOUSEMOTION,         /**< Mouse moved */
       SDL_MOUSEBUTTONDOWN,     /**< Mouse button pressed */
       SDL_MOUSEBUTTONUP,       /**< Mouse button released */
       SDL_JOYAXISMOTION,       /**< Joystick axis motion */
       SDL_JOYBALLMOTION,       /**< Joystick trackball motion */
       SDL_JOYHATMOTION,        /**< Joystick hat position change */
       SDL_JOYBUTTONDOWN,       /**< Joystick button pressed */
       SDL_JOYBUTTONUP,         /**< Joystick button released */
       SDL_QUIT,            /**< User-requested quit */
       SDL_SYSWMEVENT,          /**< System specific event */
       SDL_EVENT_RESERVEDA,     /**< Reserved for future use.. */
       SDL_EVENT_RESERVEDB,     /**< Reserved for future use.. */
       SDL_VIDEORESIZE,         /**< User resized video mode */
       SDL_VIDEOEXPOSE,         /**< Screen needs to be redrawn */
       SDL_EVENT_RESERVED2,     /**< Reserved for future use.. */
       SDL_EVENT_RESERVED3,     /**< Reserved for future use.. */
       SDL_EVENT_RESERVED4,     /**< Reserved for future use.. */
       SDL_EVENT_RESERVED5,     /**< Reserved for future use.. */
       SDL_EVENT_RESERVED6,     /**< Reserved for future use.. */
       SDL_EVENT_RESERVED7,     /**< Reserved for future use.. */
       /** Events SDL_USEREVENT through SDL_MAXEVENTS-1 are for your use */
       SDL_USEREVENT = 24,
       /** This last event is only for bounding internal arrays
    *  It is the number of bits in the event mask datatype -- Uint32
        */
       SDL_NUMEVENTS = 32
} SDL_EventType;



/** Application visibility event structure */
typedef struct SDL_ActiveEvent {
    uint8_t type; /**< SDL_ACTIVEEVENT */
    uint8_t gain; /**< Whether given states were gained or lost (1/0) */
    uint8_t state;    /**< A mask of the focus states */
} SDL_ActiveEvent;

/** Keyboard event structure */
typedef struct SDL_KeyboardEvent {
    uint8_t type; /**< SDL_KEYDOWN or SDL_KEYUP */
    uint8_t which;    /**< The keyboard device index */
    uint8_t state;    /**< SDL_PRESSED or SDL_RELEASED */
    SDL_keysym keysym;
} SDL_KeyboardEvent;

/** Mouse motion event structure */
typedef struct SDL_MouseMotionEvent {
    uint8_t type; /**< SDL_MOUSEMOTION */
    uint8_t which;    /**< The mouse device index */
    uint8_t state;    /**< The current button state */
    uint16_t x, y;    /**< The X/Y coordinates of the mouse */
    int16_t xrel;    /**< The relative motion in the X direction */
    int16_t yrel;    /**< The relative motion in the Y direction */
} SDL_MouseMotionEvent;

/** Mouse button event structure */
typedef struct SDL_MouseButtonEvent {
    uint8_t type; /**< SDL_MOUSEBUTTONDOWN or SDL_MOUSEBUTTONUP */
    uint8_t which;    /**< The mouse device index */
    uint8_t button;   /**< The mouse button index */
    uint8_t state;    /**< SDL_PRESSED or SDL_RELEASED */
    uint16_t x, y;    /**< The X/Y coordinates of the mouse at press time */
} SDL_MouseButtonEvent;

/** Joystick axis motion event structure */
typedef struct SDL_JoyAxisEvent {
    uint8_t type; /**< SDL_JOYAXISMOTION */
    uint8_t which;    /**< The joystick device index */
    uint8_t axis; /**< The joystick axis index */
    int16_t value;   /**< The axis value (range: -32768 to 32767) */
} SDL_JoyAxisEvent;

/** Joystick trackball motion event structure */
typedef struct SDL_JoyBallEvent {
    uint8_t type; /**< SDL_JOYBALLMOTION */
    uint8_t which;    /**< The joystick device index */
    uint8_t ball; /**< The joystick trackball index */
    int16_t xrel;    /**< The relative motion in the X direction */
    int16_t yrel;    /**< The relative motion in the Y direction */
} SDL_JoyBallEvent;

/** Joystick hat position change event structure */
typedef struct SDL_JoyHatEvent {
    uint8_t type; /**< SDL_JOYHATMOTION */
    uint8_t which;    /**< The joystick device index */
    uint8_t hat;  /**< The joystick hat index */
    uint8_t value;    /**< The hat position value:
             *   SDL_HAT_LEFTUP   SDL_HAT_UP       SDL_HAT_RIGHTUP
             *   SDL_HAT_LEFT     SDL_HAT_CENTERED SDL_HAT_RIGHT
             *   SDL_HAT_LEFTDOWN SDL_HAT_DOWN     SDL_HAT_RIGHTDOWN
             *  Note that zero means the POV is centered.
             */
} SDL_JoyHatEvent;

/** Joystick button event structure */
typedef struct SDL_JoyButtonEvent {
    uint8_t type; /**< SDL_JOYBUTTONDOWN or SDL_JOYBUTTONUP */
    uint8_t which;    /**< The joystick device index */
    uint8_t button;   /**< The joystick button index */
    uint8_t state;    /**< SDL_PRESSED or SDL_RELEASED */
} SDL_JoyButtonEvent;

/** The "window resized" event
 *  When you get this event, you are responsible for setting a new video
 *  mode with the new width and height.
 */
typedef struct SDL_ResizeEvent {
    uint8_t type; /**< SDL_VIDEORESIZE */
    int w;      /**< New width */
    int h;      /**< New height */
} SDL_ResizeEvent;

/** The "screen redraw" event */
typedef struct SDL_ExposeEvent {
    uint8_t type; /**< SDL_VIDEOEXPOSE */
} SDL_ExposeEvent;

/** The "quit requested" event */
typedef struct SDL_QuitEvent {
    uint8_t type; /**< SDL_QUIT */
} SDL_QuitEvent;

/** A user-defined event type */
typedef struct SDL_UserEvent {
    uint8_t type; /**< SDL_USEREVENT through SDL_NUMEVENTS-1 */
    int code;   /**< User defined event code */
    void *data1;    /**< User defined data pointer */
    void *data2;    /**< User defined data pointer */
} SDL_UserEvent;

/** If you want to use this event, you should include SDL_syswm.h */
struct SDL_SysWMmsg;
typedef struct SDL_SysWMmsg SDL_SysWMmsg;
typedef struct SDL_SysWMEvent {
    uint8_t type;
    SDL_SysWMmsg *msg;
} SDL_SysWMEvent;

/** General event structure */
typedef union SDL_Event {
    uint8_t type;
    SDL_ActiveEvent active;
    SDL_KeyboardEvent key;
    SDL_MouseMotionEvent motion;
    SDL_MouseButtonEvent button;
    SDL_JoyAxisEvent jaxis;
    SDL_JoyBallEvent jball;
    SDL_JoyHatEvent jhat;
    SDL_JoyButtonEvent jbutton;
    SDL_ResizeEvent resize;
    SDL_ExposeEvent expose;
    SDL_QuitEvent quit;
    SDL_UserEvent user;
    SDL_SysWMEvent syswm;
} SDL_Event;


typedef enum {
    SDL_ADDEVENT,
    SDL_PEEKEVENT,
    SDL_GETEVENT
} SDL_eventaction;



typedef struct SDL_Color {
    uint8_t r;
    uint8_t g;
    uint8_t b;
    uint8_t unused;
} SDL_Color;
#define SDL_Colour SDL_Color

typedef struct SDL_Palette {
    int       ncolors;
    SDL_Color *colors;
} SDL_Palette;
/*@}*/

/** Everything in the pixel format structure is read-only */
typedef struct SDL_PixelFormat {
    SDL_Palette *palette;
    uint8_t  BitsPerPixel;
    uint8_t  BytesPerPixel;
    uint8_t  Rloss;
    uint8_t  Gloss;
    uint8_t  Bloss;
    uint8_t  Aloss;
    uint8_t  Rshift;
    uint8_t  Gshift;
    uint8_t  Bshift;
    uint8_t  Ashift;
    uint32_t Rmask;
    uint32_t Gmask;
    uint32_t Bmask;
    uint32_t Amask;

    /** RGB color key information */
    uint32_t colorkey;
    /** Alpha value information (per-surface alpha) */
    uint8_t  alpha;
} SDL_PixelFormat;
