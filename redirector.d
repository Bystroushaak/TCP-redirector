/**
 * Simple TCP redirector in D.
 * 
 * Author: 
 *    Bystroushaak
 * Date:
 *    21.08.2011
 * Version:
 *    1.0.0
 * Copyright:
 *    This work is licensed under a CC BY (http://creativecommons.org/licenses/by/3.0/)
*/ 

import std.stdio;
import std.string;

import std.socket;
import std.socketstream;



///
const uint BUFF_SIZE = 1024;




/// No comment..
void printHelp(string pname){
	stderr.writeln(
		"Usage:\n" ~
		pname ~ " L_PORT RHOST:RPORT\n"
	);
}


/// Container for couple localsocket:remotesocket
struct Sockpair{
	Socket local;
	Socket remote;
}


/**
 * Remove item at selected index from array. 
 * 
 * Personaly, I think that this is most usefull piece of code in this program :D 
*/ 
T[] remove(T)(T array[], int index){
	T[] oarray;
	
	if (array.length == 0)
		return array;
	
	// if array contain olny one item, return blank array
	if (array.length == 1)
		return oarray;
	
	// last index
	if (index == array.length - 1 && array.length > 1)
		return array[0 .. $ - 1];
	
	// first indext
	if (index == 0 && array.length > 1)
		return array[1 .. $];
	
	oarray ~= array[0 .. index];
	oarray ~= array[index + 1 .. $];
	
	return oarray;
}


/**
 * Redirects local port into port at remote server.
*/ 
void tcp_redirector(ushort lport, string rhost, ushort rport){
	// bind local server
	Socket listener = new TcpSocket();
	try{
		listener.blocking = false;
		listener.bind(new InternetAddress(lport));
		listener.listen(10);
		writeln("Listening on port ", lport, ".");
	}catch(Exception e){
		stderr.writeln("Can't bind local socket on port '", lport, "'!");
		throw e;
	}
	
	// redirect
	Sockpair[] connections;
	Sockpair connection, c;
	
	// Container for sockets
	SocketSet check_this_baby = new SocketSet();
	
	// buffers
	int lreaded, rreaded, chk;
	ubyte[BUFF_SIZE] lbuff, rbuff;
	
	for(;; check_this_baby.reset()){
		// food for Socket.select (it have to be reset and filled after every select() call)
		check_this_baby.add(listener);
		foreach(tmp; connections){
			check_this_baby.add(tmp.local);
			check_this_baby.add(tmp.remote);
		}
		
		// breaker - this function wait until some socket changes
		chk = Socket.select(check_this_baby, check_this_baby, check_this_baby); 
		
		// try accept incoming connection (in nonblock mode accept() throws exception when there is none)
		try{
			// create new socket pair
			connection.local = listener.accept(); // connect to localhost
			
			connection.remote = new TcpSocket(AddressFamily.INET);
			connection.remote.connect(new InternetAddress(rhost, rport)); // connect to server
			
			// we want nonblocking socket
			connection.local.blocking  = false;
			connection.remote.blocking = false;
			
			//~ core.thread.Thread.sleep( dur!("msecs")( 5 ) );
			
			if (!check_this_baby.isSet(connection.local))
				check_this_baby.add(connection.local);
			if (!check_this_baby.isSet(connection.remote))
				check_this_baby.add(connection.remote);
			
			connections ~= connection;
		}catch(SocketAcceptException e){
		}
		
		// redirect data between all channels
		for (int i = connections.length - 1; i >= 0; i--){
			c = connections[i];
			
			// read data
			lreaded = c.local.receive(lbuff);
			rreaded = c.remote.receive(rbuff);
			
			// send data
			if (lreaded != 0 && lreaded != Socket.ERROR){
				c.remote.send(lbuff);
				lbuff.clear();
			}
			if (rreaded != 0 && rreaded != Socket.ERROR){
				c.local.send(rbuff);
				rbuff.clear();
			}
			
			// if one of connections closed, close both
			if (lreaded == 0 || rreaded == 0){
				check_this_baby.remove(c.remote);
				check_this_baby.remove(c.local);
				
				c.remote.close();
				c.local.close();
				
				connections = connections.remove(i);
			}
		}
	}
}


int main(string[] args){
	ushort lport, rport;
	string host;
	
	if (args.length != 3){
		stderr.writeln("Bad number of arguments!\n");
		printHelp(args[0]);
		return 1;
	}
	
	// parse LPORT
	try{
		lport = std.conv.to!(ushort)(args[1]);
	}catch(Exception e){
		stderr.writeln("LPORT must be port number (1 .. 65535), not '" ~ args[1] ~ "'!\n");
		printHelp(args[0]);
		return 1;
	}
	
	// parse RPORT
	try{
		if (args[2].indexOf(":") < 0){
			stderr.writeln("Remote port must be separated from host with ':'!");
			printHelp(args[0]);
			return 1;
		}
		rport = std.conv.to!(ushort)(args[2].split(":")[1]);
	}catch(Exception e){
		stderr.writeln("RPORT must be port number (1 .. 65535), not '" ~ args[2].split(":")[1] ~ "'!\n");
		printHelp(args[0]);
		return 1;
	}
	host = args[2].split(":")[0];
	
	// test if remote address is valid:
	Socket test = new TcpSocket(AddressFamily.INET);
	try
		test.connect(new InternetAddress(host, rport)); // connect to server
	catch(Exception e){
		stderr.writeln("Can't connect to '", host, ":", rport, "'!");
		return 1;
	}finally{
		test.close();
	}
	
	// do redirection
	try{
		tcp_redirector(lport, host, rport);
	}catch(SocketException e){
		return 1;
	}
	
	return 0;
}
