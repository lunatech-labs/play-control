#!/bin/sh

set -e
### BEGIN INIT INFO
# Provides:		play-control
# Required-Start:	$local_fs $remote_fs $network $time
# Required-Stop:	$local_fs $remote_fs $network $time
# Should-Start:		$syslog
# Should-Stop:		$syslog
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	Play framework application controller
### END INIT INFO

#
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=java
NAME=play-control
DESC=play-app

#LOGDIR=/var/log/play-control
DODTIME=10                   # Time to wait for the server to die, in seconds
                            # If this value is set too low you might not
                            # let some servers to die gracefully and
                            # 'restart' will not work

ACTION="$1"

# Include play-control defaults if available
if [ -f /etc/default/play-control ] ; then
    . /etc/default/play-control
fi

if [ ! -d "$PLAY_APPS_DIR" ]; then
 mkdir -p $PLAY_APPS_DIR;
 chown -R playapps:playapps $PLAY_APPS_DIR;
fi 
 

APPS="`cd $PLAY_APPS_DIR && /bin/ls`"

# Override the configured apps with the ones specified on the command line
if [ "$#" -gt 1 ]
then
	shift
	APPS="$@"
fi

running_pid()
{
    # Check if a given process pid's cmdline matches a given name
    pid=$1
    name=$2
    [ -z "$pid" ] && return 1
    [ ! -d /proc/$pid ] &&  return 1
    cmd=`cat /proc/$pid/cmdline | tr "\000" "\n"|head -n 1 |cut -d : -f 1`
    # Is this the expected child?
    [ "$cmd" != "$name" ] &&  return 1
    return 0
}

running()
{
# Check if the process is running looking at /proc
# (works for all users)

    # No pidfile, probably no daemon present
    [ ! -f "$PIDFILE" ] && return 1
    # Obtain the pid and check it against the binary name
    pid=`cat $PIDFILE`
    running_pid $pid $DAEMON || return 1
    return 0
}

force_stop() {
# Forcefully kill the process
    [ ! -f "$PIDFILE" ] && return
    if running ; then
        kill -15 $pid
        # Is it really dead?
        [ -n "$DODTIME" ] && sleep "$DODTIME"s
        if running ; then
            kill -9 $pid
            [ -n "$DODTIME" ] && sleep "$DODTIME"s
            if running ; then
                echo "Cannot kill $LABEL (pid=$pid)!"
                exit 1
            fi
        fi
    fi
    rm -f $PIDFILE
    return 0
}

start_playapp() {
	set +e
	[ -d "$PLAY_APPS_DIR/$1" ] && /bin/su - $USER -c "cd $PLAY_APPS_DIR/$1; $PLAY dependencies; $PLAY start" > /dev/null 2>&1
        set -e
	return 0
}

stop_playapp() {
	set +e
	[ -d "$PLAY_APPS_DIR/$1" ] && /bin/su - $USER -c "cd $PLAY_APPS_DIR; $PLAY stop $1" > /dev/null 2>&1
	set -e
	return 0
}

case "$ACTION" in
  start)
	for APP in $APPS
	do
        	echo -n "Starting $DESC: $APP: "
		PIDFILE="$PLAY_APPS_DIR/$APP/server.pid"

		if running
		then
			#log_action_msg "$APP already started"
			echo "$DESC: $APP already started"
		else
			start_playapp $APP

			if running
			then
				echo "$DESC: $APP started."
			else
				echo "$DESC: $APP gives error."
			fi
		fi
	done
	;;
  stop)
	for APP in $APPS
	do
        	echo -n "Stopping $DESC: "
		PIDFILE="$PLAY_APPS_DIR/$APP/server.pid"

		if running
		then
			stop_playapp $APP

			if running
			then
				echo "Stopping $DESC: $APP ERROR."
			else
				echo "Stopping $DESC: $APP."
			fi
		fi
	done
	;;
  force-stop)
	for APP in $APPS
	do
        	echo -n "Forcefully stopping $DESC: "
		PIDFILE="$PLAY_APPS_DIR/$APP/server.pid"
		force_stop
		if ! running ; then
		    echo "$APP."
		else
		    echo "$APP ERROR."
		fi
	done
	;;
  #reload)
        #
        # If the daemon can reload its config files on the fly
        # for example by sending it SIGHUP, do it here.
        #
        # If the daemon responds to changes in its config file
        # directly anyway, make this a do-nothing entry.
        #
        # echo "Reloading $DESC configuration files."
        # start-stop-daemon --stop --signal 1 --quiet --pidfile \
        #       /var/run/$NAME.pid --exec $DAEMON
  #;;
  force-reload)
        #
        # If the "reload" option is implemented, move the "force-reload"
        # option to the "reload" entry above. If not, "force-reload" is
        # just the same as "restart" except that it does nothing if the
        # daemon isn't already running.
        # check wether $DAEMON is running. If so, restart
	$0 restart $APPS
        ;;
  restart)
	$0 stop $APPS
	$0 start $APPS
        ;;
  status)
    echo -n "$LABEL is "
    if running ;  then
        echo "running"
    else
        echo " not running."
        exit 1
    fi
    ;;
  *)
    N=$0
    # echo "Usage: $N {start|stop|restart|reload|force-reload} <app>" >&2
    echo "Usage: $N {start|stop|restart|force-reload|status|force-stop} <app>" >&2
    exit 1
    ;;
esac

exit 0
