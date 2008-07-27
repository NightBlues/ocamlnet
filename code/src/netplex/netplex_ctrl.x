/* $Id$ -*- c -*- */

typedef string longstring<>;

typedef longstring *longstring_opt;

typedef longstring *internal_port;
/* The path of a Unix domain socket if the service is found and enabled */

struct message {
    longstring msg_name;
    longstring msg_arguments<>;
};


struct socket_id {
    longstring sock_protocol;   /* name of the protocol */
    int        sock_index;      /* array index */
};


typedef socket_id socket_id_list<>;


enum event_type {
    EVENT_NONE = 0,
    EVENT_ACCEPT = 1,
    EVENT_NOACCEPT = 2,
    EVENT_RECEIVED_MESSAGE = 3,
    EVENT_RECEIVED_ADMIN_MESSAGE = 4,
    EVENT_SHUTDOWN = 5,
    EVENT_SYSTEM_SHUTDOWN = 6
};


union event switch(event_type discr) {
 case EVENT_NONE:
     void;
 case EVENT_ACCEPT:
     void;
     /* Sets that these sockets try to accept new connections. */
 case EVENT_NOACCEPT:
     void;
 case EVENT_RECEIVED_MESSAGE:
     message msg;
 case EVENT_RECEIVED_ADMIN_MESSAGE:
     message msg;
 case EVENT_SHUTDOWN:
     void;
 case EVENT_SYSTEM_SHUTDOWN:
     void;
};


enum level {
    LOG_EMERG = 0,
    LOG_ALERT = 1,
    LOG_CRIT = 2,
    LOG_ERR = 3,
    LOG_WARNING = 4,
    LOG_NOTICE = 5,
    LOG_INFO = 6,
    LOG_DEBUG = 7
};



program Control {
    /* Internal API between controller and container */

    version V1 {

	void ping(void) = 0;

	event poll(int               /* Number of active connections */
		   ) = 1;
	/* Polls for the next controller event */

	void accepted(void) = 2;
	/* Tells the controller that a connection on this socket has just
         * been accepted. 
         *
         * This is a special procedure: The controller does not send a
         * response for performance reasons.
         */

	/* IDEA: Sometimes it is preferrable that [accepted] is called
         * in a synchronous way. This can be faster when there are a
         * lot of parallel jobs to do in the container. However, then
         * the problem arises how to ensure that the controller processes
         * the [accepted] call before the next [poll] call. 
	 */

    } = 1;

} = 1;


program System {
    /* API of the controller for all parts of the system */

    version V1 {
	void ping(void) = 0;

	internal_port lookup(longstring,        /* service name */
			     longstring         /* protocol */
			     ) = 1;

	void send_message(longstring,           /* service name */
			  message               /* message */
			  ) = 2;
	/* Service names may contain "*" as wildcard. For example,
         * send_message("*", msg) broadcasts to all processors.
         */

	void log(level,                /* log level */
		 longstring,           /* subchannel or "" */
		 longstring            /* log message */
		 ) = 3;
        /* This is a special procedure: The controller does not send a
         * response for performance reasons.
         */

	longstring call_plugin(_int64 hyper,         /* plugin ID */
			       longstring,    /* proc name */
			       longstring     /* proc argument */
			       ) = 4;
	/* Proc argument and return value are XDR-encoded according to the
           plugin program spec.
	*/
    } = 1;

} = 2;


enum result_code {
    CODE_OK = 0,
    CODE_ERROR = 1
};


union unit_result switch (result_code discr) {
 case CODE_OK:
     void;
 case CODE_ERROR:
     longstring message;
};


enum socket_domain {
    PF_UNKNOWN = 0,
    PF_UNIX = 1,
    PF_INET = 2,
    PF_INET6 = 3
};


union port switch (socket_domain discr) {
 case PF_UNKNOWN:
     void;
 case PF_UNIX:
     longstring path;
 case PF_INET:
     struct {
	 longstring inet_addr;
	 int inet_port;
     } inet;
 case PF_INET6:
     struct {
	 longstring inet6_addr;
	 int inet6_port;
     } inet6;
};


typedef port port_list<>;


struct prot {
    longstring prot_name;
    port_list  prot_ports;
};


typedef prot prot_list<>;


enum srv_state {
    STATE_ENABLED = 0,
    STATE_DISABLED = 1,
    STATE_RESTARTING = 2,
    STATE_DOWN = 3
};


enum cnt_state_enum {
    CSTATE_ACCEPTING = 0,
    CSTATE_SELECTED = 1,
    CSTATE_BUSY = 2,
    CSTATE_STARTING = 3,
    CSTATE_SHUTDOWN = 4
};

union cnt_state switch(cnt_state_enum d) {
 case CSTATE_ACCEPTING: void;
 default: void;
};


struct container_info {
    _int64 hyper cnt_id;     /* Object ID of the container in the controller */
    longstring   cnt_sys_id; /* System ID (thread/process ID) */
    cnt_state    cnt_state;
};


struct service_info {
    longstring srv_name;
    prot_list  srv_protocols;
    int        srv_nr_containers;
    container_info srv_containers<>;
    srv_state  srv_state;
};


typedef service_info service_info_list<>;


program Admin {
    /* User API, accessible from the outside */

    version V2 {

	void ping(void) = 0;

	service_info_list list(void) = 1;
	/* list of services: name, protocols, ports, state */

	unit_result enable(longstring          /* service name */
			   ) = 2;

	unit_result disable(longstring         /* service name */
			    ) = 3;

	unit_result restart(longstring         /* service name */
			    ) = 4;
	unit_result restart_all(void) = 5;

	unit_result system_shutdown(void) = 6;

	unit_result reopen_logfiles(void) = 7;
	/* reopen logfiles */

	void send_admin_message(longstring,           /* service name */
				message               /* message */
				) = 8;
	/* Service names may contain "*" as wildcard. For example,
         * send_admin_message("*", msg) broadcasts to all processors.
         */


    } = 2;

} = 3;


/* Plugins: */

program Semaphore {
    version V1 {
	void ping (void) = 0;
	
	_int64 hyper increment(longstring) = 1;     /* semaphore name */
	/* Increments the semaphore by 1, and returns the new semaphore
           value. If the semaphore does not exist, it is created with an
           initial value of 0, and 1 is returned.
	*/

	_int64 hyper protected_increment(longstring) = 2;
	/* Same as increment, but if the container finishes (or even crashes),
           the samaphore is decremented by the number pi-d, where pi is
           the number of protected increments the container has requested,
           and d the number of decrements the container has requested.
	*/

	_int64 hyper decrement(longstring) = 3;
	/* Decrements the semaphore by 1, and returns the new value.
	   A semaphore value cannot become negative. If the value is already
           0, the semaphore is not decremented. If the semaphore does not exist,
           it is created with an initial value of 0, and 0 is returned
	*/

    } = 1;
} = 4;


program Sharedvar {
    version V1 {
	void ping(void) = 0;

	bool create_var(longstring, bool, bool) = 1;
	/* create_var(var_name, own_flag, ro_flag): Creates the variable with
           an empty string
           as value. It is an error if the variable has already been created.
           Returns whether the function is successful (i.e. the variable
           did not exist before).

           own_flag: if true, the created variable is owned by the calling
           socket service.
           Only the caller can delete it, and when the last component of
           the socket service terminates, the variable is automatically 
           deleted.

           ro_flag: if true, only the owner can set the value
	*/

	bool set_value(longstring, longstring) = 2;
	/* set_value(var_name, var_value): Sets the variable var_name to
           var_value. This is only possible when the variable exists.
           Returns whether the function is successful (i.e. the variable
           exists).
	*/

	longstring_opt get_value(longstring) = 3;
	/* get_value(var_name): Returns the value of the existing variable,
           or NULL if the variable does not exist.
	*/

	bool delete_var(longstring) = 4;
	/* delete_var(var_name): Deletes the variable. This is only possible
           when the variable exists. Returns whether the function is 
           successful (i.e. the variable existed).
	*/

	longstring_opt wait_for_value(longstring) = 5;
	/* wait_for_value(var_name): If the variable exists and
           set_value has already been called, the current value is
           simply returned. If the variable exists, but set_value has
           not yet been called, the function waits until set_value is
           called, and returns the value set then. If the variable
           does not exist, the function immediately returns NULL.
	*/

    } = 1;
} = 5;

