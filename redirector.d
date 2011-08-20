/**
 * Simple TCP redirector in D.
 * 
 * Author: 
 *    Bystroushaak
 * Date:
 *    21.08.2011
 * Version:
 *    1.0.0
*/ 

import std.stdio;
import std.string;

import std.socket;
import std.socketstream;

const uint BUFF_SIZE = 1024;

///
void printHelp(string pname){
	stderr.writeln(
		"Usage:\n" ~
		pname ~ " L_PORT RHOST:RPORT\n"
	);
}

/// 
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
	
	if (array.length == 1)
		return oarray;
	
	if (index == array.length - 1 && array.length > 1)
		return array[0 .. $ - 1];
	
	if (index == 0 && array.length > 1)
		return array[1 .. $];
	
	oarray ~= array[0 .. index];
	oarray ~= array[index + 1 .. $];
	
	return oarray;
}

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
	Socket tmp;
	
	int lreaded, rreaded;
	ubyte[BUFF_SIZE] lbuff, rbuff;
	
	while(true){
		// try accept incoming connection (in nonblock mode accept() throws exception when there is none)
		try{
			tmp = listener.accept();

			// create new socket pair
			connection.local = tmp;
			
			connection.remote = new TcpSocket(AddressFamily.INET);
			connection.remote.connect(new InternetAddress(rhost, rport)); // connect to server
			
			connection.local.blocking = false;
			connection.remote.blocking = false;
			
			connections ~= connection;
		}catch(SocketAcceptException e){
		}
		
		// redirect data between all channels
		for (int i = connections.length - 1; i >= 0; i--){
			c = connections[i];
			
			lreaded = c.local.receive(lbuff);
			rreaded = c.remote.receive(rbuff);
			
			if (lreaded > 0){
				c.remote.send(lbuff);
				lbuff.clear();
			}
			if (rreaded > 0){
				c.local.send(rbuff);
				rbuff.clear();
			}
			
			if (lreaded == 0 || rreaded == 0){
				c.remote.close();
				c.local.close();
				connections = connections.remove(i);
			}
		}
		
		core.thread.Thread.sleep(dur!("msecs")(20));
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
	}
	
	tcp_redirector(lport, host, rport);
	
	return 0;
}