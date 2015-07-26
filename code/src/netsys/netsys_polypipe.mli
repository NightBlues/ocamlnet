(* $Id$ *)

(** Polymorphic message pipes *)

(** These pipes are restricted to a single process, and can be used
    to send messages of any types between threads.
 *)

exception Closed

type 'a polypipe

val create : int -> 'a polypipe * 'a polypipe
  (** Create a new polypipe with an internal buffer of n messages. The left
      descriptor is open for reading, and the right is open for writing.
   *)

val length : 'a polypipe -> int
  (** return the number of messages in the buffer *)

val eof : 'a polypipe -> bool
  (** whether the eof marker was sent. Note that there may still be messages
      in the buffer
   *)

val read : nonblock:bool -> 'a polypipe -> 'a option
  (** read a message. [None] means EOF. Possible [Unix.unix_error] codes:
       - [EAGAIN]: the pipe is non-blocking, and there is no message in the
         buffer
       - [EINTR]: a signal arrived

      Raises [Closed] if the polypipe has been closed.
   *)

val write : nonblock:bool -> 'a polypipe -> 'a option -> unit
  (** write a message, or mark the end of the stream ([None]).
      Possible [Unix.unix_error] codes:
       - [EAGAIN]: the pipe is non-blocking, and there is no message in the
         buffer
       - [EINTR]: a signal arrived
       - [EPIPE]: it was tried to send a message after sending [None].

      Unlike OS pipes, polypipes become writable after signaling EOF.

      Raises [Closed] if the polypipe has been closed.
   *)

val close : 'a polypipe -> unit
  (** Close the pipe. Reading and writing will be immediately impossible *)

val read_descr : 'a polypipe -> Unix.file_descr
  (** Returns a descriptor that can be used for polling. When the descriptor
      is readable there is a message in the buffer. If called several times,
      always the same descriptor is returned.

      The caller has to close the descriptor after use.

      Raises [Closed] if the polypipe has been closed.
   *)

val write_descr : 'a polypipe -> Unix.file_descr
  (** Returns a descriptor that can be used for polling. When the descriptor
      is readable (sic) there is space in the buffer for another message.
      If called several times, always the same descriptor is returned.

      The caller has to close the descriptor after use.

      Raises [Closed] if the polypipe has been closed.
   *)

val set_exception : _ polypipe -> exn -> unit
  (** Sets an exception that is returned by all further calls of
      [read], [write], [read_descr], or [write_descr]. If an exception
      already exists, it is not overwritten.
   *)
