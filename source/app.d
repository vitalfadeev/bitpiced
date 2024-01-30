import std.conv;
import std.format;
import std.stdio;
import std.file;
import bindbc.sdl;
import bitmap_font;
import xy;
import std.stdio : writeln;
import std.algorithm : countUntil;
import std.algorithm : remove;

Uint32 USER_EVENT;
const Uint32 USER_EVENT_BIT_UPDATED = 1;


int 
main () {
    // Init
    init_sdl ();

    // Register User Events
    init_user_events ();

    // Window, Surface
    SDL_Window*  window;
    new_window (window);

    // Renderer
    SDL_Renderer* renderer;
    new_renderer (window, renderer);

    // Load file
    Frame frame;
    string fname = "./name.bf";
    if (exists(fname))
		load_file (fname,frame.bitfont);

    // Event Loop
    event_loop (window, renderer, frame);

	// Save file
	save_file (frame.bitfont,fname);

    return 0;
}


//
void 
init_sdl () {
    SDLSupport ret = loadSDL();

    if (ret != sdlSupport) {
        if (ret == SDLSupport.noLibrary) 
            throw new Exception ("The SDL shared library failed to load");
        else 
        if (ret == SDLSupport.badLibrary) 
            throw new Exception ("One or more symbols failed to load. The likely cause is that the shared library is for a lower version than bindbc-sdl was configured to load (via SDL_204, GLFW_2010 etc.)");
    }

    loadSDL ("sdl2.dll");
}


void
init_user_events () {
    USER_EVENT = SDL_RegisterEvents (1);
}


//
void 
new_window (ref SDL_Window* window) {
    // Window
    window = 
        SDL_CreateWindow (
            "SDL2 Window",
            SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED,
            640, 480,
            0
        );

    if (!window)
        throw new SDLException ("Failed to create window");

    // Update
    SDL_UpdateWindowSurface (window);
}


//
void 
new_renderer (SDL_Window* window, ref SDL_Renderer* renderer) {
    renderer = SDL_CreateRenderer (window, -1, SDL_RENDERER_SOFTWARE);
}


//
void 
event_loop (ref SDL_Window* window, SDL_Renderer* renderer, ref Frame frame) {
    bool _go = true;

    short xoffset = 100;
    auto base = Base(xoffset,0);
    auto size = Size(40,40);
    frame.setup (base,size);

    while (_go) {
        SDL_Event e;

        while (SDL_PollEvent (&e) > 0) {
            // Process Event
            switch (e.type) {
            	case SDL_QUIT:
            		_go = false;
            		break;
            	case SDL_MOUSEBUTTONDOWN:
            		frame.event (&e);
            		break;
            	default:
            		if (e.type == USER_EVENT) {
            			process_user_event (&e);
            		}
            }

            // Render
            frame.draw (renderer);

            // Rasterize
            SDL_RenderPresent (renderer);
        }

        // Delay
        SDL_Delay (100);
    }        
}


void
process_user_event (SDL_Event* e) {
    switch (e.user.code) {
        case USER_EVENT_BIT_UPDATED:
        	size_t b = cast(size_t)e.user.data1;
        	break;
        default:
    }
}


//
class 
SDLException : Exception {
    this (string msg) {
        super (format!"%s: %s" (SDL_GetError().to!string, msg));
    }
}


struct
Frame {
    VBox vbox;
    //Grid grid;
    alias
    DT = _Datas!(bool,size_t);
    _GridView!DT grid;

    MonoBitPics bitfont;

    void
    setup (ref Base base, ref Size size) {
	    vbox.setup (base,size);
	    grid.setup (base,size);
    }

	void
	draw (SDL_Renderer* renderer) {
	    draw_left (renderer);
	    draw_right (renderer);
	}

	void
	draw_left (SDL_Renderer* renderer) {
	    vbox.draw (renderer);
	}

	void
	draw_right (SDL_Renderer* renderer) {
	    grid.draw (renderer);
	}

	void
	event (SDL_Event* e) {
	    vbox.event (e);
		grid.event (e);
	}
}


struct
VBox {
    Grid _super = {[],[],[],1,12,true};
    alias _super this;

    void
	setup (ref Base base, ref Size size) {
		auto _base = Base (0,0);
		auto _size = Size (80,40);
		_super.setup (_base,_size);
	}

	void
	draw (SDL_Renderer* renderer) {
	    SDL_SetRenderDrawColor (renderer, 0xFF, 0xFF, 0xFF, 0xFF);
		foreach (i,ref sen;sensors) {
	    	draw_bg (renderer,sen,bits[i]);
	    	draw_text (renderer,sen,bits[i]);
	    	draw_borders (renderer,sen,bits[i]);
		}
	}

	void
	draw_text (SDL_Renderer* renderer, ref BaseSize bs, ref bool b) {
	    SDL_SetRenderDrawColor (renderer, 0xFF, 0xFF, 0xFF, 0xFF);
	    // \
	    SDL_RenderDrawLine (
	    	renderer,
	    	bs.base.x,
	    	bs.base.y,
	    	bs.base.x+bs.size.x,
	    	bs.base.y+bs.size.y);
	    // /
	    SDL_RenderDrawLine (
	    	renderer,
	    	bs.base.x,
	    	bs.base.y+bs.size.y,
	    	bs.base.x+bs.size.x,
	    	bs.base.y);
	}
}


struct
Grid {
	BaseSize[] sensors;
	bool[]     bits;      // selected bitmap
	size_t[]   bits_ids;  // selected ids

    auto x_cells = 12;
    auto y_cells = 12;

    bool one_bit_mode;

    Datas datas;


	void
	setup (ref Base base, ref Size size) {
	    auto c_base = base;

	    sensors.length = bits.length = x_cells * y_cells;
	    auto sensors_ptr = sensors.ptr;

	    for (auto iy=0; iy<y_cells; iy++) {
		    for (auto ix=0; ix<x_cells; ix++) {
		    	*sensors_ptr = BaseSize (c_base,size);

		    	//
		    	c_base.x += size.x;
		    	sensors_ptr++;
		    }

		    //
	    	c_base.x  = base.x;
	    	c_base.y += size.y;
	    }
	}

	void
	draw (SDL_Renderer* renderer) {
	    SDL_SetRenderDrawColor (renderer, 0xFF, 0xFF, 0xFF, 0xFF);
		foreach (i,ref sen;sensors) {
	    	draw_bg (renderer,sen,bits[i]);
	    	draw_borders (renderer,sen,bits[i]);
		}
	}

	void
	draw_bg (SDL_Renderer* renderer, ref BaseSize bs, ref bool b) {
		if (b)
		    SDL_SetRenderDrawColor (renderer, 0xFF, 0xFF, 0xFF, 0xFF);
		else
		    SDL_SetRenderDrawColor (renderer, 0x00, 0x00, 0x00, 0xFF);

		auto rect = 
			SDL_Rect (
				bs.base.x,
				bs.base.y,
				bs.size.x+1,
				bs.size.y+1);

		SDL_RenderFillRect (renderer,&rect);
	}

	void
	draw_borders (SDL_Renderer* renderer, ref BaseSize bs, ref bool b) {
		if (b)
		    SDL_SetRenderDrawColor (renderer, 0xFF, 0xFF, 0xFF, 0xFF);
		else
		    SDL_SetRenderDrawColor (renderer, 0xFF, 0xFF, 0xFF, 0xFF);

		auto rect = 
			SDL_Rect (
				bs.base.x,
				bs.base.y,
				bs.size.x+1,
				bs.size.y+1);

		SDL_RenderDrawRect (renderer,&rect);
	}

	void
	event (SDL_Event* e) {
        switch (e.type) {
        	case SDL_MOUSEBUTTONDOWN:
        		auto xy = 
        			XY (
        				cast(short)e.button.x,
        				cast(short)e.button.y
    				);

        		foreach (i,ref sen;sensors)
        			if (sen.has (xy)) {
// view.click
//   request --> event queue
//               event queue --> DataSource.request
//                                 callback --> event queue
//                                              event queue --> UI.event
//                                                                update view
        				if (datas.request (Datas.REQUEST_INVERT,i)) {
        					// update ui
	        				if (one_bit_mode)
	        					clear_bits ();
	        				update_bit (i);
	        				//send_event (USER_EVENT_BIT_UPDATED,cast(void*)i);
        				}
        				break;
        			}

        		break;

        	default:
        }
	}


	void
	update_bit (size_t i) {
		if (bits[i]) {
			auto _bi = bits_ids.countUntil (i);
			if (_bi != -1)
				bits_ids.remove (_bi);
			bits[i] = false;
		}
		else {
			bits_ids ~= i;
			bits[i] = true;
		}	    
	}


	void
	clear_bits () {
	    foreach (bi;bits_ids)
	    	bits[bi] = false;
	    bits_ids.length = 0;
	}


	void
	send_event (int event_id, void* data1) {
	    SDL_Event event;
	    event.type = cast(SDL_EventType)USER_EVENT;
	    event.user.code = event_id;
	    event.user.data1 = data1;
	    //event.user.data2 = void*;
	    SDL_PushEvent(&event);
    }
}

alias
Size = XY;

alias
Sizes = Size[];

alias
Base = XY;

alias
Bases = Base[];

struct
BaseSize {
    Base base;
    Size size;

    bool
    has (ref XY xy) {
		if (base.x<=xy.x && base.y<=xy.y) {
			auto limit = base + size;
			if (xy.x<limit.x && xy.y<limit.y)
				return true;
		}

		return false;
    }
}


struct
Datas {
	enum
	REQUEST_INVERT = 1;

    bool
    request (Uint32 req_id, size_t i) {
        switch (req_id) {
            case REQUEST_INVERT:
            	// ...
            	break;
            default:
        }
        return false;
    }
}

// pics  image
// ----  ---------
// A     .........
//*B     .####....
// ...   .#...#...
// Z     .####....
//
// F2 Save  F4 Load

// Datas
//   ...
// Selected
//   Id[] ids...
//   bool[] bits...
// View
//   foreach (i;0..table_rows)
//     data = datas[i]
//     ...data...
//   
//   foreach (id;ids)
//     data = datas[id]
//     ...data...
//   
//   foreach (data;datas)
//     ...data...
//   
//   foreach (data;datas[i..limit])
//     ...data...

struct
_Datas (T,ID=size_t) {
	size_t a;
	size_t b;
	T[] _datas;

	alias
	THIS = typeof(this);

	alias
	TID = ID;

	alias
	TT = T;


	// datas.set ()
	// datas.set_async ()
	// datas.clr ()
	// foreach (d;datas)
	// datas[i]
	// datas[id]
	// datas[a..b]

	ref T
	opIndex (size_t i) {
	    return _datas[i];
	}

	static if (!is(ID==size_t)) 
	ref T
	opIndex (ID id) {
	    return _datas[id];
	}

    THIS
    opSlice (size_t dim: 0) (size_t a, size_t b) {
        return THIS (a,b);
    }

    THIS
    opIndex () (THIS slice) { 
    	return slice; 
    }

    int 
    opApply (int delegate(ref size_t, ref T) dg) const {
        int result = 0;

        auto _a = a;
        auto _b = b;

        for (size_t i = _a; i < _b; i++) {
            result = dg (i,*cast(T*)_datas.ptr[i]);

            if (result) {
                break;
            }
        }

        return result;
    }

    void
    request (T1,T2)(T1 t1, T2 t2) {
        //
    }
}

struct
_Selected (TID=size_t) {
	TID[] _ids;
	//bool[] bits;

	void
	set (TID id) {
		auto i = _ids.countUntil (id);
		
		if (i == -1)
	    	_ids ~= id;
	}

	void
	clr (TID id) {
		auto i = _ids.countUntil (id);
		
		if (i != -1)
	    	_ids = _ids.remove (i);
	}

	bool
	opIndex (TID id) {
		auto i = _ids.countUntil (id);

		if (i == -1)
	    	return false;
	    else
	    	return true;
	}

	// Ids
	//   Id[] ids...
	// Bitmap
	//   bool[] bits...
}

struct
_View (DT) {
	DT datas;


	void
	setup (ref Base base, ref Size size) {
	    //sensors.length = bits.length = x_cells * y_cells;
	    //auto sensors_ptr = sensors.ptr;
	}

	void
	draw (SDL_Renderer* renderer) {
	    //SDL_SetRenderDrawColor (renderer, 0xFF, 0xFF, 0xFF, 0xFF);
	}

	void
	redraw () {
	    //
	}

	void
	event (SDL_Event* e) {
        //switch (e.type) {
        //	case SDL_MOUSEBUTTONDOWN:
        //		if (e.button.button == SDL_BUTTON_LEFT)
        //			op.set_data ();
        //		break;
        //	case SDL_KEYDOWN:
        //		if (e.key.keysym.sym == SDLK_DELETE)
        //			op.clr_data ();
        //		break;
        //	default:
        //}

		// event
		//   case KEY:
		//     set_data ()
		//   case KEY:
		//     clr_data ()
		//   case KEY:
		//     set_select ()
		//   case KEY:
		//     clr_select ()
    }

	template
	_Op () {
		void
		set_data (DT.TT new_data) {
			//auto set = 1;
			//datas.request (set, new_data);
			//redraw ();
		}

		void
		clr_data () {
		    //
		}

		void
		set_select () {
		    //
		}

		void
		clr_select () {
		    //
		}
	}

	alias 
	op = _Op!();

	// setup
	// draw
	// event
	//   case KEY:
	//     set_data ()
	//   case KEY:
	//     clr_data ()
	//   case KEY:
	//     set_select ()
	//   case KEY:
	//     clr_select ()
	//
	// op
	//   set_data ()
	//     datas.request set new_data
	//     redraw
	//   clr_data ()
	//     datas.request clr old_data
	//     redraw
	//   set_select ()
	//     selected.set (id)
	//     redraw
	//   clr_select ()
	//     selected.clr (id)
	//     redraw
}

struct
_GridView (DT) {
    _View!DT _super;
    alias _super this;

	BaseSize[] sensors;
	//bool[]     bits;      // selected bitmap
	//size_t[]   bits_ids;  // selected ids

    auto x_cells = 12;
    auto y_cells = 12;

    bool one_bit_mode;

    _Selected!(DT.TID) _selected;


	void
	setup (ref Base base, ref Size size) {
	    auto c_base = base;

	    sensors.length = x_cells * y_cells;
	    auto sensors_ptr = sensors.ptr;

	    for (auto iy=0; iy<y_cells; iy++) {
		    for (auto ix=0; ix<x_cells; ix++) {
		    	*sensors_ptr = BaseSize (c_base,size);

		    	//
		    	c_base.x += size.x;
		    	sensors_ptr++;
		    }

		    //
	    	c_base.x  = base.x;
	    	c_base.y += size.y;
	    }
	}

	void
	draw (SDL_Renderer* renderer) {
	    SDL_SetRenderDrawColor (renderer, 0xFF, 0xFF, 0xFF, 0xFF);
		foreach (i,ref sen;sensors) {
	    	draw_bg (renderer,sen,_selected[i]);
	    	draw_borders (renderer,sen,_selected[i]);
		}
	}

	void
	draw_bg (SDL_Renderer* renderer, ref BaseSize bs, bool b) {
		if (b)
		    SDL_SetRenderDrawColor (renderer, 0xFF, 0xFF, 0xFF, 0xFF);
		else
		    SDL_SetRenderDrawColor (renderer, 0x00, 0x00, 0x00, 0xFF);

		auto rect = 
			SDL_Rect (
				bs.base.x,
				bs.base.y,
				bs.size.x+1,
				bs.size.y+1);

		SDL_RenderFillRect (renderer,&rect);
	}

	void
	draw_borders (SDL_Renderer* renderer, ref BaseSize bs, bool b) {
		if (b)
		    SDL_SetRenderDrawColor (renderer, 0xFF, 0xFF, 0xFF, 0xFF);
		else
		    SDL_SetRenderDrawColor (renderer, 0xFF, 0xFF, 0xFF, 0xFF);

		auto rect = 
			SDL_Rect (
				bs.base.x,
				bs.base.y,
				bs.size.x+1,
				bs.size.y+1);

		SDL_RenderDrawRect (renderer,&rect);
	}

	void
	event (SDL_Event* e) {
        switch (e.type) {
        	case SDL_MOUSEBUTTONDOWN:
        		if (e.button.button == SDL_BUTTON_LEFT) {
	        		auto xy = 
	        			XY (
	        				cast(short)e.button.x,
	        				cast(short)e.button.y
	    				);

	        		foreach (i,ref sen;sensors)
	        			if (sen.has (xy)) {
	        				if (_selected[i]) {  // clr
		        				op.set_data (false);
		        				_selected.clr (i);
	        				}
	        				else {               // set
		        				op.set_data (true);
		        				_selected.set (i);
	        				}

	        				if (0) {
	        					// update ui
	        					// Update Selection
		        				//if (one_bit_mode)
		        				//	clear_bits ();
		        				//_selected.set (i);
		        				//send_event (USER_EVENT_BIT_UPDATED,cast(void*)i);
	        				}
	        				break;
	        			}
        		}
        		break;
        	case SDL_KEYDOWN:
        		if (e.key.keysym.sym == SDLK_DELETE)
        			op.clr_data ();
        		break;
        	default:
        }
// ASYNC
// view.click
//   request --> event queue
//               event queue --> DataSource.request
//                                 callback --> event queue
//                                              event queue --> UI.event
//                                                                update view
	}
}
