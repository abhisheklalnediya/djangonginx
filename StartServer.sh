#!/bin/bash

PORT=5001
host=0.0.0.0
SCRIPT=$(readlink -f $0)
SCRIPTPATH=`dirname $SCRIPT`
if [ -s "$SCRIPTPATH/manage.py" ]
then
	echo "Djago App found"
	if [ -s "$SCRIPTPATH/fcgi.pid" ]
	then
# 		echo "Pids Found"
# 		cat $SCRIPTPATH/fcgi.pid
		cat $SCRIPTPATH/fcgi.pid | while read PID
		do
# 			echo x$PID
				if kill -0 $PID >> /dev/null 2>&1
				then
					echo "Killing Running instace of app : $PID" 
					kill "$PID"
					sleep 5
					rm /etc/nginx/sites-available/$PID
					rm /etc/nginx/sites-enabled/$PID
				fi
				
				if kill -0 $PID >> /dev/null 2>&1
				then
					echo "Failed to Stop Running Server!"
					exit 1
				fi
				
			
		done 
	fi
	if [ ! -z $1 ]
	then
		PORT=$1
	fi
	
	fcgiport=`expr $PORT + 1 ` 
	echo Starting server at port "$PORT" and fcgi at $fcgiport
	
	python ./manage.py runfcgi host=127.0.0.1 port=$fcgiport pidfile="$SCRIPTPATH/fcgi.pid"
	
	djpid=
# 	cat $SCRIPTPATH/fcgi.pid
	djpid=`head -n 1 $SCRIPTPATH/fcgi.pid`
# 	echo $djpid
	if [ -z $djpid ]
	then
		echo failed to start django app!, exiting...
		exit 1
	fi
	
	sitefile=/etc/nginx/sites-available/$djpid
	
	echo Generating Virtual host config for nginx : $sitefile
	
	echo "server {" > $sitefile
	echo "listen $PORT;" >> $sitefile
	
	echo "server_name localhost;" >> $sitefile
	
	echo "access_log /tmp/$fcgiport.access.log;" >> $sitefile
	echo "error_log /tmp/$fcgiport.error.log;" >> $sitefile
		
	echo "location / {" >> $sitefile
	echo 'include fastcgi_params;' >> $sitefile;
	echo "fastcgi_pass 127.0.0.1:$fcgiport;" >> $sitefile;
    echo 'fastcgi_param PATH_INFO $fastcgi_script_name;' >> $sitefile;
    echo 'fastcgi_param REQUEST_METHOD $request_method;' >> $sitefile;
    echo 'fastcgi_param QUERY_STRING $query_string;' >> $sitefile;
    echo 'fastcgi_param CONTENT_TYPE $content_type;' >> $sitefile;
    echo 'fastcgi_param CONTENT_LENGTH $content_length;' >> $sitefile;
    echo 'fastcgi_pass_header Authorization;' >> $sitefile;
    echo 'fastcgi_intercept_errors off;' >> $sitefile;
	echo 'fastcgi_split_path_info ^()(.*)$;' >> $sitefile;
	echo "}" >> $sitefile
	echo "}" >> $sitefile
	
	
	ln /etc/nginx/sites-available/$djpid /etc/nginx/sites-enabled/
	sudo /etc/init.d/nginx restart
	
else
	
	echo "Failed to find a Django App, Copy me to a django app directory"
fi
