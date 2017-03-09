#include<errno.h>     // errno
#include<fcntl.h>     // FADVISE_SEQUENTIAL, posix_fadvise()
#include<stdio.h>     // _IONBF, BUFSIZ, std{in,out}, setvbuf()
#include<stdlib.h>    // EXIT_{FAILURE,SUCCESS}
#include<string.h>    // strerror()
#include<unistd.h>    // STD{IN,OUT}_FILENO
#include<sys/types.h> // ssize_t

#define ASSERT(expr) if( (expr) ){ break; }

int safe_read(char *buffer, size_t count, ssize_t *bytes)
{
	// read bytes form the standard input
	// (keep reading after errors due signal interrupts)
	do
	{
		*bytes=read(STDIN_FILENO,buffer,count);
	}while( 0>*bytes && EINTR==errno );

	// got an error?
	if( 0>*bytes )
	{
		// show the error message and return failure
		fprintf(stderr,"   (E) reading error: %s\n",strerror(errno));
		return -1;
	}

	// no more bytes available? 
	if( 0==*bytes )
	{
		// stop processing 
		return 1;
	}

	// all ok
	return 0;
}

int safe_fputs(const char *buffer)
{
	// write data to the output stream
	int err=fputs(buffer,stdout);

	// got an error?
	if( EOF==err )
	{
		// show the error message and return failure
		fprintf(stderr,"   (E) writing error: %s\n",strerror(errno));
		return -1;
	}

	// all ok
	return 0;
}

int safe_fwrite(const char *buffer, size_t bytes)
{
	// write data to the output stream
	int err=fwrite(buffer,bytes,1,stdout);

	// got an error?
	if( 0>err )
	{
		// show the error message and return failure
		fprintf(stderr,"   (E) writing error: %s\n",strerror(errno));
		return -1;
	}

	// all ok
	return 0;
}

int main (int argc, char **argv)
{
	size_t err;
	ssize_t bytesrd;
	ssize_t byteswr;
	char *newline;
	char buffer[BUFSIZ];

	#if HAVE_POSIX_FADVISE
		// advice the kernel that we will access the input file sequentially
		err=posix_fadvise(STDIN_FILENO,0,0,FADVISE_SEQUENTIAL);
		if( err )
		{
			fprintf(stderr,"   (E) cannot disable output buffering: %s\n",strerror(err));
			return EXIT_FAILURE;
		}
	#endif

	// disable output buffering
	err=setvbuf(stdout,NULL,_IONBF,0);
	if( err )
	{
		if( errno )
		{
			fprintf(stderr,"   (E) cannot disable output buffering: %s\n",strerror(errno));
		}
		else
		{
			fprintf(stderr,"   (E) cannot disable output buffering\n");
		}

		return EXIT_FAILURE;
	}

	// processing loop
	int first=1;
	int flag=0;
	while( !flag )
	{
		// read BUFSIZ bytes from the standard input
		ASSERT( flag=safe_read(buffer,sizeof(buffer),&bytesrd) );

		// update the prefix flag
		newline=memchr(buffer,'\n',bytesrd);

		// write prefix to the output stream (if necessary)
		if( first )
		{
			ASSERT( flag=safe_fputs("   (-) ") );
			first=0;
		}

		// formatted echoing of the input data to the output stream
		if( newline )
		{
			// echo with prefix
			byteswr=newline-buffer+1;
			ASSERT( flag=safe_fwrite(buffer,byteswr) );

			if( 0<(bytesrd-byteswr) )
			{
				ASSERT( flag=safe_fputs("   (-) ") );
				ASSERT( flag=safe_fwrite(newline+1,bytesrd-byteswr) );
				newline=NULL;
			}
			else
			{
				first=1;
			}
		}
		else
		{
			// echo without prefix
			ASSERT( flag=safe_fwrite(buffer,bytesrd) );
		}
    }

	return (0>flag)? EXIT_FAILURE : EXIT_SUCCESS;
}
