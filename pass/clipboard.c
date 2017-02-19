/*
 * sources:
 * https://www.jwz.org/doc/x-cut-and-paste.html
 * https://github.com/milki/xclip
 */
// --- https://github.com/milki/xclip/blob/master/xclip.c#L239
// --- https://github.com/milki/xclip/blob/master/xclib.h
// --- https://github.com/milki/xclip/blob/master/xclib.c

#include<errno.h>      // errno
#include<unistd.h>     // isatty()
#include<setjmp.h>     // jmp_buf, longjmp(), setjmp()
#include<stdarg.h>     // va_list, va_start()
#include<stdio.h>      // feof(), frprintf()
#include<stdlib.h>     // EXIT_{...}, exit(), malloc(), realloc()
#include<string.h>     // strerror()
#include<sys/select.h> // struct timeval, FD_{...}, fd_set(), select()
#include<X11/Xatom.h>
#include<X11/Xlib.h>

int XNextEventTimed(Display* display, XEvent* event, struct timeval* timeout)
{
	// if no timeout is given, wait for the next event (standard Xlib call)
	if( NULL==timeout )
	{
		XNextEvent(display,event);
		return 1;
	}

	// if there are pending events, handle them immediately
	if( 0<XPending(display) )
	{
                XNextEvent(display,event);
                return 1;
	}

	// monitor the Xserver connection with the given timeout
	// (standard select call for I/O multiplexing)
	int err=-1;
	int fd=ConnectionNumber(display);
	fd_set readset;
	FD_ZERO(&readset);
	FD_SET(fd,&readset);
	err=select(fd+1,&readset,NULL,NULL,timeout);

	// error check
	if( -1==err )
	{
		return -errno;
	}

	// there are pending events?
	if( 0<err )
	{
		XNextEvent(display,event);
		return 1;
	}

	// timeout reached?
	return 0;
}


static void print_stuff0(Display*, Atom);

// error handler
void eprintf(jmp_buf error, const char* format, ...)
{
	va_list arguments;

	// arguments list initialization
	va_start(arguments,format);

	// show error message
	vfprintf(stderr,format,arguments);

	// long jump to the error handling procedure
	longjmp(error,1);
}

int main(int argc, char *argv[])
{
	// input data buffer
	char* buffer=NULL;
	size_t length=16;

	// copy to clipboard timeout
	int seconds=15;

	// X11 stuff: selections atoms
	Atom clipboard=None;
	Atom primary=XA_PRIMARY;
	Atom secondary=XA_SECONDARY;

	// X11 stuff: data and meta-data atoms
	Atom encoding_ascii;
	Atom encoding_utf8;

	// X11 stuff: dummy window
	Window window;
	char* window_name="pipeboard";

	// X11 stuff: connection to the X server
	Display* display=NULL;
	char* display_name=NULL;

	// error handler
	jmp_buf error;
	if( setjmp(error) )
	{
		// free the input buffer
		if( NULL!=buffer )
		{
			free(buffer);
		}

		// disconnect from the X server
		if( NULL!=display )
		{
			XCloseDisplay(display);
		}

		// exit with error
		exit(EXIT_FAILURE);
	}

	// connect to the X server
	display=XOpenDisplay(display_name);
	if( NULL==display )
	{
		eprintf(error,"[%s-error]: cannot open display %s\n",argv[0],XDisplayName(display_name));
	}

	// get clipboard selection atom
	clipboard=XInternAtom(display,"CLIPBOARD",True);
	if( None==clipboard )
	{
		eprintf(error,"[%s-error]: cannot get 'CLIPBOARD' atom on %s\n",argv[0],XDisplayName(display_name));
	}

	// get data encoding atoms
	encoding_ascii=XInternAtom(display,"STRING",True);
	if( None==encoding_ascii )
	{
		eprintf(error,"[%s-error]: cannot get 'STRING' atom on %s\n",argv[0],XDisplayName(display_name));
	}

	encoding_utf8=XInternAtom(display,"UTF8_STRING",True);
	if( None==encoding_utf8 )
	{
		eprintf(error,"[%s-error]: cannot get 'UTF8_STRING' atom on %s\n",argv[0],XDisplayName(display_name));
	}

	// create a dummy (named) window to trap X events
	window=XCreateSimpleWindow(display,DefaultRootWindow(display),0,0,1,1,0,0,0);
	XStoreName(display,window,window_name);

	// receive only property changes events from the X server
	XSelectInput(display,window,PropertyChangeMask);

	// stdin has been redirected
	// (copy to clipboard (a.k.a. primary and clipboard X selections) all incoming data)

	if( !isatty(STDIN_FILENO) )
	{
		// allocate resources for the input buffer
		buffer=(char*)malloc(length*sizeof(char));
		if( NULL==buffer )
		{
			eprintf(error,"[%s-error]: cannot allocate the input buffer (%s)\n",argv[0],strerror(errno));
		}

		// get input data
		size_t readed=0;
		size_t accumulated=0;
		do
		{
			// read input data
			readed=read(STDIN_FILENO,buffer+accumulated,length-accumulated);

			// get number of bytes in the buffer
			accumulated+=readed;

			// buffer filled?
			if( accumulated==length )
			{
				// double length size
				length=2*length;

				// increase buffer length
				char *aux=(char*)realloc(buffer,length*sizeof(char));
				if( NULL==aux )
				{
					eprintf(error,"[%s-error]: cannot allocate the input buffer (%s)\n",argv[0],strerror(errno));
				}
			}
		}
		while( readed );

		// request selections ownership
		XSetSelectionOwner(display,clipboard,window,CurrentTime);
		XSetSelectionOwner(display,primary,window,CurrentTime);
		//XSetSelectionOwner(display,secondary,window,CurrentTime);

		// wait for a copy event or until timeout is reached
		for( int i=0; seconds>i; i++ )
		{
			int err=0;
			XEvent event;
			struct timeval timeout={1,0};

			// wait for the next event (1 second at most)
			err=XNextEventTimed(display,&event,&timeout);
			if( 0>err )
			{
				eprintf(error,"[%s-error]: unexpected error while polling X events (%s)",argv[0],strerror(-err));
			}
		}
	}

	// stdout has been redirected
	// (echo all clipboard (primary and clipboard X selections) data)
	if( !isatty(STDOUT_FILENO) )
	{
	}

	// get ownership of the primary and clipboard selections
  print_stuff0(display,primary);
  print_stuff0(display,secondary);
  print_stuff0(display,clipboard);

	// close the connection to the X server
	XCloseDisplay(display);

	// exit with no error
	exit(EXIT_SUCCESS);
}

void
print_stuff0(Display* display, Atom atom)
{
  Window win;
  char* window_name;
  char* atom_name;

  atom_name = XGetAtomName(display, atom);

  if((win = XGetSelectionOwner(display, atom)) != None)
    {

      XFetchName(display, win, &window_name);
      printf("\"%s\" (WM_NAME of %ld) owns selection of \"%s\" atom.\n", window_name, win, atom_name);
      XFree(window_name);
    }
  else
      printf("No body owns selection \"%s\"\n", atom_name);
}
